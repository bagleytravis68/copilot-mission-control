param(
    [switch]$Clean
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\\..")).Path
$mappingPath = Join-Path $PSScriptRoot "mapping.json"
$mapping = Get-Content -LiteralPath $mappingPath -Raw | ConvertFrom-Json
$targetDir = Join-Path $repoRoot $mapping.plugin.agentsDirectory
$skillsSourceDir = Join-Path $repoRoot "skills"
$skillsTargetDir = Join-Path $repoRoot $mapping.plugin.skillsDirectory

New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
New-Item -ItemType Directory -Path $skillsTargetDir -Force | Out-Null

if ($Clean) {
    Get-ChildItem -LiteralPath $targetDir -Filter "*.agent.md" -ErrorAction SilentlyContinue | Remove-Item -Force
    Get-ChildItem -LiteralPath $skillsTargetDir -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
    New-Item -ItemType Directory -Path $skillsTargetDir -Force | Out-Null
}

$copied = @()
$copiedSkills = @()

foreach ($agent in $mapping.agents) {
    $sourcePath = Join-Path $repoRoot $agent.source
    if (-not (Test-Path -LiteralPath $sourcePath)) {
        throw "Missing source agent file: $sourcePath"
    }

    $targetPath = Join-Path $targetDir $agent.targetFile
    Copy-Item -LiteralPath $sourcePath -Destination $targetPath -Force
    $copied += $agent.targetFile
}

Write-Host "Synced $($copied.Count) Copilot plugin agent files into $targetDir"
$copied | ForEach-Object { Write-Host " - $_" }

if (Test-Path -LiteralPath $skillsSourceDir) {
    Get-ChildItem -LiteralPath $skillsSourceDir -Directory | ForEach-Object {
        if ($_.Name -eq ".git") {
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

Write-Host "Synced $($copiedSkills.Count) Copilot plugin skill directories into $skillsTargetDir"
$copiedSkills | ForEach-Object { Write-Host " - $_" }
