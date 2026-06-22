# Copilot component instructions

Use this document when changing the **GitHub Copilot CLI** adapter or plugin package in this repository.

## Read these first

### Plugin packaging

- Plugin creation: https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/plugins-creating
- Plugin marketplace: https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/plugins-marketplace
- Plugin installation: https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/plugins-finding-installing
- Plugin reference: https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-plugin-reference

### Skills

- Skills: https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-skills

### Hooks

- Hooks usage: https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/use-hooks
- Hooks reference: https://docs.github.com/en/copilot/reference/hooks-reference

### GitHub Copilot app/local SDK extensions

The GitHub Copilot app harness uses the local Copilot SDK extension surface in addition to, and sometimes overlapping with, Copilot CLI plugin behavior. Before changing `.github/extensions/mission-control/`, read the installed SDK docs and types from the target machine:

```text
%LOCALAPPDATA%\Programs\GitHub Copilot\copilot-sdk\docs\extensions.md
%LOCALAPPDATA%\Programs\GitHub Copilot\copilot-sdk\docs\agent-author.md
%LOCALAPPDATA%\Programs\GitHub Copilot\copilot-sdk\docs\examples.md
%LOCALAPPDATA%\Programs\GitHub Copilot\copilot-sdk\extension.d.ts
%LOCALAPPDATA%\Programs\GitHub Copilot\copilot-sdk\session.d.ts
%LOCALAPPDATA%\Programs\GitHub Copilot\copilot-sdk\types.d.ts
%LOCALAPPDATA%\Programs\GitHub Copilot\copilot-sdk\generated\session-events.d.ts
```

Use SDK hooks for interception and guardrails, and `session.on(...)` session events for richer traceability. Model IDs are exposed on events such as `assistant.usage`, `assistant.message`, `tool.execution_start`, `tool.execution_complete`, `subagent.started`, `subagent.completed`, and `session.model_change` when the runtime emits those fields.

## Current repository conventions

- Canonical custom-agent source: `agents/<agent-id>/agent.md`
- Canonical skill source: `skills/<skill-name>/SKILL.md`
- Copilot plugin package: `plugins/mission-control/`
- Copilot plugin agent output: `plugins/mission-control/agents/`
- Copilot plugin skill output: `plugins/mission-control/skills/`
- Copilot build sync script: `adapters/copilot/build.ps1`
- Copilot plugin manifest: `plugins/mission-control/plugin.json`
- Copilot marketplace manifest: `.github/plugin/marketplace.json`
- Canonical session trace hooks: `hooks/session-trace/`
- Canonical communication wrapper schema: `team/communication.schema.json`
- GitHub Copilot app compatibility extension: `.github/extensions/mission-control/extension.mjs`
- Copilot plugin hook config output: `plugins/mission-control/hooks.json`
- Copilot plugin hook asset output: `plugins/mission-control/hooks/`

## Goal: add a custom agent

1. Read the plugin creation and plugin reference docs.
2. Create or edit the canonical source file:

```text
agents/<agent-id>/agent.md
```

3. If it is a new agent, update:

- `team/team.json`
- `adapters/copilot/mapping.json`

4. Run:

```powershell
.\adapters\copilot\build.ps1
```

5. Confirm the generated file exists in:

```text
plugins/mission-control/agents/
```

6. Reinstall the plugin locally for testing:

```powershell
$pluginPath = (Resolve-Path .\plugins\mission-control).Path
copilot plugin install $pluginPath
```

7. Verify the agent loads in Copilot CLI.

## Goal: add a skill

1. Read the skills doc and plugin docs.
2. Create the canonical source directory:

```text
skills/<skill-name>/
```

3. Add the required file:

```text
skills/<skill-name>/SKILL.md
```

4. Follow the Copilot skill rules:

- the directory name must be lowercase and hyphenated
- `SKILL.md` is required
- `name` is required in YAML frontmatter and should typically match the directory name
- `description` is required in YAML frontmatter
- scripts and supporting files should live inside the same skill directory

5. Be careful with `allowed-tools`:

- only pre-approve powerful tools when the skill is trusted and the behavior is intended
- avoid casually pre-approving shell access

6. Run:

```powershell
.\adapters\copilot\build.ps1
```

7. Confirm the skill was synced into:

```text
plugins/mission-control/skills/<skill-name>/
```

8. Reinstall the plugin locally:

```powershell
$pluginPath = (Resolve-Path .\plugins\mission-control).Path
copilot plugin install $pluginPath
```

9. Verify the skill in Copilot CLI:

```text
/skills list
/skills info <skill-name>
```

## Goal: add a hook

1. Read the hooks usage and hooks reference docs.
2. Decide whether the hook belongs:

- inside the plugin package, or
- only as repository-level behavior

3. If the hook is part of the plugin, keep it in the plugin package described by the official docs and point `plugin.json` at it when needed.
4. For session trace hooks, edit canonical files under `hooks/session-trace/`, then run `.\adapters\copilot\build.ps1` instead of hand-editing generated plugin hook copies.
5. Prefer cross-platform hook definitions by providing both `bash` and `powershell` entries when practical.
6. Keep JSON valid and ensure `version` is correct.
7. Test with the documented Copilot hook loading behavior instead of assuming hooks are discovered the same way as agents or skills.
8. Preserve the Mission Control hook bypasses unless intentionally changing safety behavior:
   - `MISSION_CONTROL_DISABLED=1` or `.tmp/mission-control.disabled`
   - `MISSION_CONTROL_GUARD_DISABLED=1` or `.tmp/mission-control-guard.disabled`
   - `MISSION_CONTROL_TRACE_DISABLED=1` or `.tmp/mission-control-trace.disabled`

## Sync and verification

After any change to agents or skills:

```powershell
.\adapters\copilot\build.ps1
$pluginPath = (Resolve-Path .\plugins\mission-control).Path
copilot plugin install $pluginPath
```

Minimum verification expectations:

- custom agents: confirm the plugin installs and the agent is available
- skills: confirm the plugin installs and the skill appears in `/skills list`
- hooks: confirm the plugin installs and the hook file shape matches the docs
- hook safety: confirm `.\scripts\mission-control-toggle.ps1 -Command disable-hooks` bypasses hook behavior and `enable-hooks` restores it
- plugin safety: in CLI builds without `copilot plugin enable/disable`, use `.\scripts\mission-control-toggle.ps1 -Command disable-plugin` to uninstall and `enable-plugin` to reinstall from `plugins/mission-control`

## Do not do this

- Do not author primary source directly in `plugins/mission-control/agents/`
- Do not author primary source directly in `plugins/mission-control/skills/`
- Do not add plugin metadata fields by guesswork
- Do not assume repo-level `.github/skills` guidance is identical to plugin-packaged skills without checking the docs
