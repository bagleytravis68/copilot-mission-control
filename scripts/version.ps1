param(
    [ValidateSet("show", "check", "sync", "set", "bump-patch", "bump-minor", "bump-major")]
    [string]$Command = "show",

    [string]$Version,

    [ValidateSet("unreleased", "released")]
    [string]$ReleaseStatus = "unreleased"
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$versionFile = Join-Path $repoRoot "VERSION"
$teamPath = Join-Path $repoRoot "team\team.json"
$pluginPath = Join-Path $repoRoot "plugins\mission-control\plugin.json"
$marketplacePath = Join-Path $repoRoot ".github\plugin\marketplace.json"

function Get-CanonicalVersion {
    return (Get-Content -LiteralPath $versionFile -Raw).Trim()
}

function Get-StageFromVersion {
    param([string]$InputVersion)

    if ($InputVersion -match '^(?<major>[0-9]+)\.(?<minor>[0-9]+)\.(?<patch>[0-9]+)$') {
        if ([int]$matches.major -eq 0) {
            return "alpha"
        }

        return "stable"
    }

    if ($InputVersion -match '^[0-9]+\.[0-9]+\.[0-9]+-(alpha|beta|rc)(?:\.[0-9]+)?$') {
        return $matches[1]
    }

    return "stable"
}

function Get-BumpedVersion {
    param(
        [string]$CurrentVersion,
        [ValidateSet("patch", "minor", "major")]
        [string]$BumpType
    )

    if ($CurrentVersion -notmatch '^(?<major>[0-9]+)\.(?<minor>[0-9]+)\.(?<patch>[0-9]+)$') {
        throw "Automatic bump commands require the current version to match <major>.<minor>.<patch> without a prerelease suffix."
    }

    $major = [int]$matches.major
    $minor = [int]$matches.minor
    $patch = [int]$matches.patch

    switch ($BumpType) {
        "patch" { return "{0}.{1}.{2}" -f $major, $minor, ($patch + 1) }
        "minor" { return "{0}.{1}.0" -f $major, ($minor + 1) }
        "major" { return "{0}.0.0" -f ($major + 1) }
    }
}

function Read-JsonFile {
    param([string]$Path)
    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Write-JsonFile {
    param(
        [string]$Path,
        [object]$InputObject
    )

    $json = $InputObject | ConvertTo-Json -Depth 100
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $json + [Environment]::NewLine, $utf8NoBom)
}

function Set-CanonicalVersion {
    param([string]$NewVersion)

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($versionFile, $NewVersion + [Environment]::NewLine, $utf8NoBom)
}

function Sync-VersionTargets {
    param(
        [string]$TargetVersion,
        [string]$TargetReleaseStatus
    )

    $stage = Get-StageFromVersion -InputVersion $TargetVersion

    $team = Read-JsonFile -Path $teamPath
    $team.team.version = $TargetVersion
    $team.team.stage = $stage
    $team.team.releaseStatus = $TargetReleaseStatus
    Write-JsonFile -Path $teamPath -InputObject $team

    $plugin = Read-JsonFile -Path $pluginPath
    $plugin.version = $TargetVersion
    Write-JsonFile -Path $pluginPath -InputObject $plugin

    $marketplace = Read-JsonFile -Path $marketplacePath
    $marketplace.metadata.version = $TargetVersion
    foreach ($pluginEntry in $marketplace.plugins) {
        if ($pluginEntry.name -eq "mission-control-agent-team") {
            $pluginEntry.version = $TargetVersion
        }
    }
    Write-JsonFile -Path $marketplacePath -InputObject $marketplace
}

function Get-VersionState {
    $canonical = Get-CanonicalVersion
    $team = Read-JsonFile -Path $teamPath
    $plugin = Read-JsonFile -Path $pluginPath
    $marketplace = Read-JsonFile -Path $marketplacePath

    return [pscustomobject]@{
        canonical = $canonical
        team = $team.team.version
        plugin = $plugin.version
        marketplace = $marketplace.metadata.version
        marketplacePlugin = ($marketplace.plugins | Where-Object { $_.name -eq "mission-control-agent-team" } | Select-Object -ExpandProperty version)
        stage = $team.team.stage
        releaseStatus = $team.team.releaseStatus
    }
}

switch ($Command) {
    "show" {
        Get-VersionState | Format-List
        break
    }
    "check" {
        $state = Get-VersionState
        $expected = $state.canonical
        $mismatches = @()

        foreach ($pair in @(
            @{ Name = "team"; Value = $state.team },
            @{ Name = "plugin"; Value = $state.plugin },
            @{ Name = "marketplace"; Value = $state.marketplace },
            @{ Name = "marketplacePlugin"; Value = $state.marketplacePlugin }
        )) {
            if ($pair.Value -ne $expected) {
                $mismatches += "$($pair.Name)=$($pair.Value)"
            }
        }

        if ($mismatches.Count -gt 0) {
            throw "Version mismatch detected. VERSION=$expected but " + ($mismatches -join ", ")
        }

        Write-Host "Version state is consistent: $expected"
        break
    }
    "sync" {
        $canonical = Get-CanonicalVersion
        Sync-VersionTargets -TargetVersion $canonical -TargetReleaseStatus $ReleaseStatus
        Write-Host "Synced version targets to $canonical"
        break
    }
    "set" {
        if ([string]::IsNullOrWhiteSpace($Version)) {
            throw "The set command requires -Version."
        }

        Set-CanonicalVersion -NewVersion $Version
        Sync-VersionTargets -TargetVersion $Version -TargetReleaseStatus $ReleaseStatus
        Write-Host "Set and synced version to $Version"
        break
    }
    "bump-patch" {
        $canonical = Get-CanonicalVersion
        $next = Get-BumpedVersion -CurrentVersion $canonical -BumpType "patch"
        Set-CanonicalVersion -NewVersion $next
        Sync-VersionTargets -TargetVersion $next -TargetReleaseStatus $ReleaseStatus
        Write-Host "Bumped patch version to $next"
        break
    }
    "bump-minor" {
        $canonical = Get-CanonicalVersion
        $next = Get-BumpedVersion -CurrentVersion $canonical -BumpType "minor"
        Set-CanonicalVersion -NewVersion $next
        Sync-VersionTargets -TargetVersion $next -TargetReleaseStatus $ReleaseStatus
        Write-Host "Bumped minor version to $next"
        break
    }
    "bump-major" {
        $canonical = Get-CanonicalVersion
        $next = Get-BumpedVersion -CurrentVersion $canonical -BumpType "major"
        Set-CanonicalVersion -NewVersion $next
        Sync-VersionTargets -TargetVersion $next -TargetReleaseStatus $ReleaseStatus
        Write-Host "Bumped major version to $next"
        break
    }
}
