# APM adapter

This adapter syncs the repository's canonical Mission Control sources into the generated APM package at `packages/mission-control-agent-team/`.

APM is the preferred cross-harness package/install layer, but `agents/`, `skills/`, `hooks/session-trace/`, and `.github/extensions/mission-control/` remain the authoring sources for now. Run:

```powershell
.\adapters\apm\build.ps1 -Clean
```

Then validate with a scratch root from the repository root:

```powershell
.\tests\install\validate-apm.ps1
```

The root `apm.yml` is a development workspace that depends on `./packages/mission-control-agent-team`. The package-local `apm.yml` is the APM-native package manifest. Keep the package directory free of install outputs such as `.github/`, `.claude/`, `.codex/`, `.agents/`, `apm_modules/`, and `apm.lock.yaml`; `-Clean` removes those if a package-local validation run accidentally creates them.

Use source dependency installs for full hook validation. APM 0.21 can pack the generated hook assets into a plugin-format bundle, but `apm install <bundle>` currently deploys only the plugin-native agents and merged `hooks.json`; it does not copy referenced hook scripts into Copilot's hook script directory. Treat bundle publishing as a follow-up until that install path can preserve hook script assets.

To observe that known bundle limitation without making it a blocking check, run:

```powershell
.\tests\install\validate-apm.ps1 -IncludeBundleDiagnostic
```

The generated `.apm/extensions/mission-control/` bundle is for APM's experimental canvas primitive. Consumers must enable APM canvas support and trust dependency-provided canvas extensions before dependency installs deploy executable `extension.mjs` content.
