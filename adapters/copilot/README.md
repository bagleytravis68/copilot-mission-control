# Copilot adapter

This adapter packages the Mission Control team as a **GitHub Copilot CLI plugin** and exposes a **plugin marketplace manifest** for one-command installation.

## Official documentation

Read these before changing this adapter:

- Plugin creation: https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/plugins-creating
- Plugin marketplace: https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/plugins-marketplace
- Plugin installation: https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/plugins-finding-installing
- Plugin reference: https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-plugin-reference

## Adapter responsibilities

- define how canonical source agents map into Copilot plugin agent files
- maintain the installable plugin package under `plugins/mission-control/`
- maintain the marketplace manifest under `.github/plugin/marketplace.json`
- provide build tooling that syncs `agents/` and `skills/` into the plugin package

## Authoring rule

Edit source agents under `agents/` first, then run:

```powershell
.\adapters\copilot\build.ps1
```

For component-specific instructions, see `adapters/copilot/INSTRUCTIONS.md`.

Do not treat the plugin bundle as the primary authoring location unless the change is specific to plugin packaging metadata.
