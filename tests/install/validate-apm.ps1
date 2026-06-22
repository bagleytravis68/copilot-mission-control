param(
    [string]$ScratchRoot,
    [switch]$IncludeBundleDiagnostic
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$mappingPath = Join-Path $repoRoot "adapters\copilot\mapping.json"
$mapping = Get-Content -LiteralPath $mappingPath -Raw | ConvertFrom-Json
$expectedAgents = @($mapping.agents)

if (-not $ScratchRoot) {
    $ScratchRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("mission-control-apm-validation-" + [System.Guid]::NewGuid().ToString("N"))
}

function Invoke-CheckedCommand {
    param(
        [string]$Command,
        [string[]]$Arguments
    )

    Write-Host "Running: $Command $($Arguments -join ' ')"
    $global:LASTEXITCODE = 0
    & $Command @Arguments
    $commandSucceeded = $?
    if (-not $commandSucceeded) {
        throw "Command failed: $Command $($Arguments -join ' ')"
    }

    if (([System.IO.Path]::GetExtension($Command) -ne ".ps1") -and $LASTEXITCODE -ne 0) {
        throw "Command failed with exit code ${LASTEXITCODE}: $Command $($Arguments -join ' ')"
    }
}

function Assert-PathExists {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Expected path to exist: $Path"
    }
}

function Assert-PathMissing {
    param([string]$Path)

    if (Test-Path -LiteralPath $Path) {
        throw "Expected path to be absent: $Path"
    }
}

function Convert-InstalledPath {
    param(
        [string]$Root,
        [string]$RelativePath
    )

    $normalized = $RelativePath -replace "[/\\]", [System.IO.Path]::DirectorySeparatorChar
    return Join-Path $Root $normalized
}

function Assert-AgentFiles {
    param(
        [string]$Root,
        [string]$Target,
        [scriptblock]$NameFromCopilotFile
    )

    foreach ($agent in $expectedAgents) {
        $fileName = & $NameFromCopilotFile $agent.targetFile
        $path = Join-Path $Root $fileName
        Assert-PathExists -Path $path
    }
}

function Assert-CopilotHookInstall {
    param([string]$Root)

    $hookConfigPath = Join-Path $Root ".github\hooks\mission-control-agent-team-copilot-hooks.json"
    Assert-PathExists -Path $hookConfigPath

    $hookConfigText = Get-Content -LiteralPath $hookConfigPath -Raw
    if ($hookConfigText -match "\$\{PLUGIN_ROOT\}") {
        throw "Installed Copilot hook config still contains unresolved `${PLUGIN_ROOT}: $hookConfigPath"
    }

    $hookConfig = $hookConfigText | ConvertFrom-Json
    foreach ($requiredEvent in @("preToolUse", "sessionStart", "sessionEnd", "subagentStart", "subagentStop")) {
        if (-not $hookConfig.hooks.PSObject.Properties.Name.Contains($requiredEvent)) {
            throw "Installed Copilot hook config is missing event: $requiredEvent"
        }
    }

    foreach ($expectedSnippet in @("communication-guard", "session-trace")) {
        if ($hookConfigText -notmatch [regex]::Escape($expectedSnippet)) {
            throw "Installed Copilot hook config does not reference $expectedSnippet"
        }
    }

    $referencedScripts = [regex]::Matches($hookConfigText, "\.github/hooks/scripts/[^'`" ]+\.(?:ps1|sh)") |
        ForEach-Object { $_.Value } |
        Sort-Object -Unique

    $expectedScriptNames = @(
        "communication-guard.ps1",
        "communication-guard.sh",
        "session-trace.ps1",
        "session-trace.sh"
    )

    foreach ($scriptName in $expectedScriptNames) {
        $match = $referencedScripts | Where-Object { $_.EndsWith("/$scriptName") }
        if (-not $match) {
            throw "Installed Copilot hook config does not reference expected script: $scriptName"
        }
    }

    foreach ($relativeScript in $referencedScripts) {
        Assert-PathExists -Path (Convert-InstalledPath -Root $Root -RelativePath $relativeScript)
    }
}

function Assert-PackageSourceClean {
    $packageRoot = Join-Path $repoRoot "packages\mission-control-agent-team"
    foreach ($relativePath in @(".github", ".claude", ".codex", ".agents", "apm_modules", "build", "apm.lock.yaml", ".gitignore", "hook-assets")) {
        Assert-PathMissing -Path (Join-Path $packageRoot $relativePath)
    }
}

function Remove-PackageInstallOutputs {
    $packageRoot = Join-Path $repoRoot "packages\mission-control-agent-team"
    foreach ($relativePath in @(".github", ".claude", ".codex", ".agents", "apm_modules", "build", "apm.lock.yaml", ".gitignore", "hook-assets")) {
        Remove-Item -LiteralPath (Join-Path $packageRoot $relativePath) -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function New-CleanDirectory {
    param([string]$Path)

    Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

function Test-CopilotInstall {
    param([string]$Root)

    Invoke-CheckedCommand -Command "apm" -Arguments @("install", "--root", $Root, "--target", "copilot", "--verbose")

    Assert-AgentFiles -Root $Root -Target "copilot" -NameFromCopilotFile {
        param([string]$TargetFile)
        return Join-Path ".github\agents" $TargetFile
    }
    Assert-CopilotHookInstall -Root $Root
}

function Test-CoreTargetInstall {
    param([string]$Root)

    Invoke-CheckedCommand -Command "apm" -Arguments @("install", "--root", $Root, "--target", "copilot,claude,codex,agent-skills", "--verbose")

    Assert-AgentFiles -Root $Root -Target "copilot" -NameFromCopilotFile {
        param([string]$TargetFile)
        return Join-Path ".github\agents" $TargetFile
    }
    Assert-AgentFiles -Root $Root -Target "claude" -NameFromCopilotFile {
        param([string]$TargetFile)
        return Join-Path ".claude\agents" ($TargetFile -replace "\.agent\.md$", ".md")
    }
    Assert-AgentFiles -Root $Root -Target "codex" -NameFromCopilotFile {
        param([string]$TargetFile)
        return Join-Path ".codex\agents" ($TargetFile -replace "\.agent\.md$", ".toml")
    }
    Assert-PathExists -Path (Join-Path $Root ".agents")
    Assert-CopilotHookInstall -Root $Root
}

function Test-BundleDiagnostic {
    $packageRoot = Join-Path $repoRoot "packages\mission-control-agent-team"
    $packageManifest = Get-Content -LiteralPath (Join-Path $packageRoot "apm.yml") -Raw
    $packageVersion = ($packageManifest -split "`n" | Where-Object { $_ -match '^version:\s*(.+)\s*$' } | ForEach-Object { $matches[1] } | Select-Object -First 1)
    if ([string]::IsNullOrWhiteSpace($packageVersion)) {
        throw "Unable to determine package version from $packageRoot\apm.yml"
    }

    $bundleRoot = Join-Path $packageRoot ("build\\mission-control-agent-team-{0}" -f $packageVersion)
    $bundleScratch = Join-Path $ScratchRoot "bundle-diagnostic"

    Push-Location $packageRoot
    try {
        Invoke-CheckedCommand -Command "apm" -Arguments @("pack", "--verbose")
    }
    finally {
        Pop-Location
    }

    New-CleanDirectory -Path $bundleScratch
    Invoke-CheckedCommand -Command "apm" -Arguments @("install", $bundleRoot, "--root", $bundleScratch, "--target", "copilot", "--verbose")

    Assert-AgentFiles -Root $bundleScratch -Target "copilot" -NameFromCopilotFile {
        param([string]$TargetFile)
        return Join-Path ".github\agents" $TargetFile
    }

    $hookScriptRoot = Join-Path $bundleScratch ".github\hooks\scripts"
    if (Test-Path -LiteralPath $hookScriptRoot) {
        Write-Warning "APM bundle install now deploys hook script assets. Revisit source-install-only documentation and make this diagnostic blocking."
    }
    else {
        Write-Host "Observed expected APM 0.21 bundle limitation: bundle install did not deploy Copilot hook script assets."
    }
}

if (-not (Get-Command apm -ErrorAction SilentlyContinue)) {
    throw "APM CLI is required. Install it before running this validation."
}

Write-Host "APM version:"
Invoke-CheckedCommand -Command "apm" -Arguments @("--version")

Push-Location $repoRoot
try {
    Invoke-CheckedCommand -Command (Join-Path $repoRoot "adapters\apm\build.ps1") -Arguments @("-Clean")

    $copilotRoot = Join-Path $ScratchRoot "copilot"
    $coreRoot = Join-Path $ScratchRoot "core"
    New-CleanDirectory -Path $copilotRoot
    New-CleanDirectory -Path $coreRoot

    Test-CopilotInstall -Root $copilotRoot
    Test-CoreTargetInstall -Root $coreRoot

    if ($IncludeBundleDiagnostic) {
        Test-BundleDiagnostic
    }
}
finally {
    Invoke-CheckedCommand -Command (Join-Path $repoRoot "adapters\apm\build.ps1") -Arguments @("-Clean")
    Remove-PackageInstallOutputs
    Assert-PackageSourceClean
    Pop-Location
}

Write-Host "APM installation validation passed."
