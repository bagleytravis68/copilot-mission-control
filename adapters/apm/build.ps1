param(
    [switch]$Clean
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
$mappingPath = Join-Path $repoRoot "adapters\copilot\mapping.json"
$mapping = Get-Content -LiteralPath $mappingPath -Raw | ConvertFrom-Json

$packageRoot = Join-Path $repoRoot "packages\mission-control-agent-team"
$apmRoot = Join-Path $packageRoot ".apm"
$agentsTargetDir = Join-Path $apmRoot "agents"
$skillsSourceDir = Join-Path $repoRoot "skills"
$skillsTargetDir = Join-Path $apmRoot "skills"
$hooksSourceDir = Join-Path $repoRoot "hooks\session-trace"
$hooksTargetDir = Join-Path $apmRoot "hooks"
$hooksTargetFile = Join-Path $hooksTargetDir "copilot-hooks.json"
$hookAssetsTargetDir = Join-Path $packageRoot "extensions\mission-control\hook-assets"
$communicationSchema = Join-Path $repoRoot "team\communication.schema.json"
$communicationSchemaTarget = Join-Path $hookAssetsTargetDir "communication.schema.json"
$extensionSourceDir = Join-Path $repoRoot ".github\extensions\mission-control"
$extensionTargetDir = Join-Path $apmRoot "extensions\mission-control"

if ($Clean) {
    foreach ($path in @($apmRoot, $hookAssetsTargetDir)) {
        if (Test-Path -LiteralPath $path) {
            Remove-Item -LiteralPath $path -Recurse -Force
        }
    }
    foreach ($relativePath in @(".github", ".claude", ".codex", ".agents", "apm_modules", "build", "apm.lock.yaml", ".gitignore", "extensions", "hook-assets")) {
        $generatedPath = Join-Path $packageRoot $relativePath
        if (Test-Path -LiteralPath $generatedPath) {
            Remove-Item -LiteralPath $generatedPath -Recurse -Force
        }
    }
}

New-Item -ItemType Directory -Path $packageRoot -Force | Out-Null
New-Item -ItemType Directory -Path $agentsTargetDir -Force | Out-Null
New-Item -ItemType Directory -Path $skillsTargetDir -Force | Out-Null
New-Item -ItemType Directory -Path $hooksTargetDir -Force | Out-Null
New-Item -ItemType Directory -Path $hookAssetsTargetDir -Force | Out-Null

$copiedAgents = @()
foreach ($agent in $mapping.agents) {
    $sourcePath = Join-Path $repoRoot $agent.source
    if (-not (Test-Path -LiteralPath $sourcePath)) {
        throw "Missing source agent file: $sourcePath"
    }

    $targetPath = Join-Path $agentsTargetDir $agent.targetFile
    Copy-Item -LiteralPath $sourcePath -Destination $targetPath -Force
    $copiedAgents += $agent.targetFile
}

$copiedSkills = @()
if (Test-Path -LiteralPath $skillsSourceDir) {
    Get-ChildItem -LiteralPath $skillsSourceDir -Directory | ForEach-Object {
        $skillSource = Join-Path $_.FullName "SKILL.md"
        if (-not (Test-Path -LiteralPath $skillSource)) {
            return
        }

        $targetSkillDir = Join-Path $skillsTargetDir $_.Name
        if (Test-Path -LiteralPath $targetSkillDir) {
            Remove-Item -LiteralPath $targetSkillDir -Recurse -Force
        }

        Copy-Item -LiteralPath $_.FullName -Destination $targetSkillDir -Recurse -Force
        $copiedSkills += $_.Name
    }
}

if (-not (Test-Path -LiteralPath $communicationSchema)) {
    throw "Missing communication schema: $communicationSchema"
}

$traceBash = '${PLUGIN_ROOT}/extensions/mission-control/hook-assets/session-trace.sh'
$tracePowerShell = '${PLUGIN_ROOT}/extensions/mission-control/hook-assets/session-trace.ps1'
$guardBash = '${PLUGIN_ROOT}/extensions/mission-control/hook-assets/communication-guard.sh'
$guardPowerShell = '${PLUGIN_ROOT}/extensions/mission-control/hook-assets/communication-guard.ps1'
$apmHooks = [ordered]@{
    version = 1
    hooks = [ordered]@{
        preToolUse = @(
            [ordered]@{
                type = "command"
                matcher = "agent|task"
                bash = "bash $guardBash preToolUse"
                powershell = "& '$guardPowerShell' -Event preToolUse"
                timeoutSec = 10
            }
        )
        sessionStart = @(
            [ordered]@{
                type = "command"
                bash = "bash $traceBash sessionStart"
                powershell = "& '$tracePowerShell' -Event sessionStart"
                timeoutSec = 10
            }
        )
        sessionEnd = @(
            [ordered]@{
                type = "command"
                bash = "bash $traceBash sessionEnd"
                powershell = "& '$tracePowerShell' -Event sessionEnd"
                timeoutSec = 10
            }
        )
        subagentStart = @(
            [ordered]@{
                type = "command"
                bash = "bash $traceBash subagentStart"
                powershell = "& '$tracePowerShell' -Event subagentStart"
                timeoutSec = 10
            },
            [ordered]@{
                type = "command"
                bash = "bash $guardBash subagentStart"
                powershell = "& '$guardPowerShell' -Event subagentStart"
                timeoutSec = 10
            }
        )
        subagentStop = @(
            [ordered]@{
                type = "command"
                bash = "bash $traceBash subagentStop"
                powershell = "& '$tracePowerShell' -Event subagentStop"
                timeoutSec = 10
            },
            [ordered]@{
                type = "command"
                bash = "bash $guardBash subagentStop"
                powershell = "& '$guardPowerShell' -Event subagentStop"
                timeoutSec = 10
            }
        )
    }
}
$apmHooks | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $hooksTargetFile -Encoding utf8

Get-ChildItem -LiteralPath $hooksSourceDir -File | Where-Object { $_.Name -ne "copilot-hooks.json" } | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $hookAssetsTargetDir $_.Name) -Force
}
Copy-Item -LiteralPath $communicationSchema -Destination $communicationSchemaTarget -Force

if (Test-Path -LiteralPath (Join-Path $extensionSourceDir "extension.mjs")) {
    if (Test-Path -LiteralPath $extensionTargetDir) {
        Remove-Item -LiteralPath $extensionTargetDir -Recurse -Force
    }
    Copy-Item -LiteralPath $extensionSourceDir -Destination $extensionTargetDir -Recurse -Force
}

Write-Host "Synced $($copiedAgents.Count) APM agent files into $agentsTargetDir"
$copiedAgents | ForEach-Object { Write-Host " - $_" }
Write-Host "Synced $($copiedSkills.Count) APM skill directories into $skillsTargetDir"
$copiedSkills | ForEach-Object { Write-Host " - $_" }
Write-Host "Synced APM hook config into $hooksTargetDir"
Write-Host "Synced APM hook assets into $hookAssetsTargetDir"
Write-Host "Synced APM extension assets into $extensionTargetDir"
