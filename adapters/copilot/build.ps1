param(
    [switch]$Clean
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
$mappingPath = Join-Path $PSScriptRoot "mapping.json"
$mapping = Get-Content -LiteralPath $mappingPath -Raw | ConvertFrom-Json
$targetDir = Join-Path $repoRoot $mapping.plugin.agentsDirectory
$skillsSourceDir = Join-Path $repoRoot "skills"
$skillsTargetDir = Join-Path $repoRoot $mapping.plugin.skillsDirectory
$hooksSourceDir = Join-Path $repoRoot $mapping.plugin.hooksSourceDirectory
$hooksTargetDir = Join-Path $repoRoot $mapping.plugin.hooksDirectory
$hooksSourceFile = Join-Path $repoRoot $mapping.plugin.hooksSourceFile
$hooksTargetFile = Join-Path $repoRoot $mapping.plugin.hooksFile
$communicationSchema = Join-Path $repoRoot $mapping.plugin.communicationSchema
$communicationSchemaTarget = Join-Path $repoRoot $mapping.plugin.communicationSchemaFile

New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
New-Item -ItemType Directory -Path $skillsTargetDir -Force | Out-Null
New-Item -ItemType Directory -Path $hooksTargetDir -Force | Out-Null

if ($Clean) {
    Get-ChildItem -LiteralPath $targetDir -Filter "*.agent.md" -ErrorAction SilentlyContinue | Remove-Item -Force
    Get-ChildItem -LiteralPath $skillsTargetDir -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
    Get-ChildItem -LiteralPath $hooksTargetDir -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
    Remove-Item -LiteralPath $hooksTargetFile -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $skillsTargetDir -Force | Out-Null
    New-Item -ItemType Directory -Path $hooksTargetDir -Force | Out-Null
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

if (-not (Test-Path -LiteralPath $hooksSourceFile)) {
    throw "Missing source hook config: $hooksSourceFile"
}

if (-not (Test-Path -LiteralPath $communicationSchema)) {
    throw "Missing communication schema: $communicationSchema"
}

Copy-Item -LiteralPath $hooksSourceFile -Destination $hooksTargetFile -Force
Get-ChildItem -LiteralPath $hooksSourceDir -File | Where-Object { $_.Name -ne (Split-Path $hooksSourceFile -Leaf) } | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $hooksTargetDir $_.Name) -Force
}
Copy-Item -LiteralPath $communicationSchema -Destination $communicationSchemaTarget -Force

Write-Host "Synced Copilot plugin hook config into $hooksTargetFile"
Write-Host "Synced Copilot plugin hook assets into $hooksTargetDir"
