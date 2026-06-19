param(
    [Parameter(Mandatory = $true)]
    [ValidateSet(
        "status",
        "enable-plugin",
        "disable-plugin",
        "enable-hooks",
        "disable-hooks",
        "enable-guard",
        "disable-guard",
        "enable-trace",
        "disable-trace"
    )]
    [string]$Command
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$tmpDir = Join-Path $repoRoot ".tmp"
$pluginName = "mission-control-agent-team"
$markers = @{
    hooks = Join-Path $tmpDir "mission-control.disabled"
    guard = Join-Path $tmpDir "mission-control-guard.disabled"
    trace = Join-Path $tmpDir "mission-control-trace.disabled"
}

function Enable-Marker {
    param([string]$Path)

    New-Item -ItemType Directory -Path (Split-Path $Path -Parent) -Force | Out-Null
    New-Item -ItemType File -Path $Path -Force | Out-Null
}

function Disable-Marker {
    param([string]$Path)

    Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
}

function Write-Status {
    Write-Output "Mission Control plugin: use 'copilot plugin list' for installed state."
    Write-Output "All hooks disabled: $(Test-Path -LiteralPath $markers.hooks)"
    Write-Output "Guard disabled: $(Test-Path -LiteralPath $markers.guard)"
    Write-Output "Trace disabled: $(Test-Path -LiteralPath $markers.trace)"
    Write-Output "Env MISSION_CONTROL_DISABLED: $($env:MISSION_CONTROL_DISABLED)"
    Write-Output "Env MISSION_CONTROL_GUARD_DISABLED: $($env:MISSION_CONTROL_GUARD_DISABLED)"
    Write-Output "Env MISSION_CONTROL_TRACE_DISABLED: $($env:MISSION_CONTROL_TRACE_DISABLED)"
}

switch ($Command) {
    "status" {
        Write-Status
    }
    "enable-plugin" {
        $pluginPath = Join-Path $repoRoot "plugins\mission-control"
        & copilot plugin install $pluginPath
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to install Mission Control plugin."
        }
    }
    "disable-plugin" {
        & copilot plugin uninstall $pluginName
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to uninstall Mission Control plugin."
        }
    }
    "enable-hooks" {
        Disable-Marker -Path $markers.hooks
        Write-Output "Mission Control hooks enabled for this repository."
    }
    "disable-hooks" {
        Enable-Marker -Path $markers.hooks
        Write-Output "Mission Control hooks disabled for this repository."
    }
    "enable-guard" {
        Disable-Marker -Path $markers.guard
        Write-Output "Mission Control communication guard enabled for this repository."
    }
    "disable-guard" {
        Enable-Marker -Path $markers.guard
        Write-Output "Mission Control communication guard disabled for this repository."
    }
    "enable-trace" {
        Disable-Marker -Path $markers.trace
        Write-Output "Mission Control session trace enabled for this repository."
    }
    "disable-trace" {
        Enable-Marker -Path $markers.trace
        Write-Output "Mission Control session trace disabled for this repository."
    }
}
