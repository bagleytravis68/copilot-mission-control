param(
    [ValidateSet("copilot")]
    [string]$Target = "copilot",

    [ValidateSet("local", "marketplace")]
    [string]$Source = "local",

    [string]$MarketplaceSpec,
    [string]$MarketplaceName = "mission-control-marketplace",
    [string]$PluginName = "mission-control-agent-team",
    [switch]$Build
)

$ErrorActionPreference = "Stop"

if ($Target -ne "copilot") {
    throw "Only the 'copilot' target is implemented right now."
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$pluginPath = Join-Path $repoRoot "plugins\\mission-control"

if ($Build) {
    & (Join-Path $repoRoot "adapters\\copilot\\build.ps1")
}

if (-not (Get-Command copilot -ErrorAction SilentlyContinue)) {
    throw "The 'copilot' CLI was not found on PATH."
}

switch ($Source) {
    "local" {
        & copilot plugin install $pluginPath
    }
    "marketplace" {
        if ([string]::IsNullOrWhiteSpace($MarketplaceSpec)) {
            throw "Marketplace installs require -MarketplaceSpec OWNER/REPO or a marketplace path."
        }

        & copilot plugin marketplace add $MarketplaceSpec
        & copilot plugin install "$PluginName@$MarketplaceName"
    }
}
