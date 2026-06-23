# Copilot Mission Control

Mission Control is an experimental AI agent team for software delivery. The goal is to make a small group of specialized agents easier to install, inspect, and improve without locking the project to one AI tool forever.

Today, the project works best as a GitHub Copilot CLI plugin. We are also moving toward [APM](https://microsoft.github.io/apm/) as the main packaging and installation path so the same team can eventually be installed across more agent harnesses with less custom installer code.

## Why this exists

Most AI coding setups start as a pile of prompts, scripts, and tool-specific folders. That makes them hard to review, hard to test, and hard to move between tools.

Mission Control is trying to solve that by keeping the team definition in one clear place, then generating the tool-specific install packages from that source.

Use this repo if you want:

- a structured software-delivery agent team
- a working Copilot CLI plugin today
- a project that is actively moving toward tool-agnostic installation
- lightweight trace data that shows when Mission Control hooks and app extension events are firing

## What is included

- `agents/` — canonical agent source
- `skills/` — canonical skill source
- `hooks/session-trace/` — session trace hook source
- `team/team.json` — team and packaging metadata
- `plugins/mission-control/` — installable Copilot plugin package
- `packages/mission-control-agent-team/` — generated APM package source
- `.github/extensions/mission-control/` — Copilot App compatibility extension
- `apm.yml` — APM workspace manifest

Detailed maintainer docs live in `agents.md` and the adapter docs under `adapters/`.

## Current state

This repository is **pre-1.0** and should be treated as **alpha / unreleased**. It is usable for testing and iteration, but the install story is still being refined.

APM is already being used as a tested installation path for the generated source package. It is not yet the only installation path, because some APM distribution modes still need work and the older Copilot CLI plugin remains available as a fallback.

| Harness | Installation method | Preferred method | How to install | Status | Notes |
| --- | --- | --- | --- | --- | --- |
| **GitHub Copilot CLI** | **APM source install** | Yes | `.\adapters\apm\build.ps1 -Clean` then `apm install --target copilot` | Ready for development validation | This is the main APM path tested today. Validation confirms agents, hook config, and hook scripts are placed correctly. |
| **GitHub Copilot CLI** | Existing local plugin package | No | `.\install\install.ps1 -Source local -Build` | Ready as stable fallback | The local `plugins/mission-control/` plugin installs in a clean Copilot CLI home and runs a smoke prompt. |
| **GitHub Copilot CLI** | APM packed bundle | No | `apm pack` then `apm install <bundle> --target copilot` | Not ready | APM can build the bundle, but this install path does not copy Mission Control hook scripts correctly yet. |
| **GitHub Copilot CLI** | APM marketplace | No | Future `apm install <marketplace-ref> --target copilot` | Not validated | Marketplace distribution is a goal, but this repo has not validated it yet. |
| **GitHub Copilot App** | Repo-local project extension | Yes | Already present at `.github/extensions/mission-control/` | Ready for local app validation | This is the preferred app testing path today. The extension loads in the app and writes app trace events. This is not an APM install path yet. |
| **GitHub Copilot App** | APM Copilot App/canvas extension install | No | Future APM experimental canvas/app extension flow | Not validated | APM has relevant experimental extension support, but Mission Control has not validated it as an app install path yet. |
| **GitHub Copilot App** | Marketplace-style app distribution | No | Future marketplace or extension distribution path | Not validated | The app distribution story still needs to be proven separately from repo-local extension loading. |
| **Claude Code** | **APM source install** | Yes | `.\adapters\apm\build.ps1 -Clean` then `apm install --target claude` | Ready for file-placement validation | APM places the expected agent files into the Claude target layout. Runtime behavior in Claude Code is not validated yet. |
| **Claude Code** | APM packed bundle | No | Future `apm install <bundle> --target claude` | Not validated | Bundle, skills, hooks, and runtime behavior still need validation for this harness. |
| **Claude Code** | APM marketplace | No | Future `apm install <marketplace-ref> --target claude` | Not validated | Marketplace distribution has not been tested. |
| **Codex** | **APM source install** | Yes | `.\adapters\apm\build.ps1 -Clean` then `apm install --target codex` | Ready for file-placement validation | APM places the expected agent files into the Codex target layout. Runtime behavior in Codex is not validated yet. |
| **Codex** | APM packed bundle | No | Future `apm install <bundle> --target codex` | Not validated | Bundle, skills, hooks, and runtime behavior still need validation for this harness. |
| **Codex** | APM marketplace | No | Future `apm install <marketplace-ref> --target codex` | Not validated | Marketplace distribution has not been tested. |
| **Shared `agent-skills` target** | **APM source install** | Yes | `.\adapters\apm\build.ps1 -Clean` then `apm install --target agent-skills` | Partial validation | This is the preferred future skills path. APM creates the shared `.agents` location, but there are no real skills to validate yet. |

## Install

### Install methods explained (plain language)

- **APM source install**: Install directly from this repo's generated package source.  
  **How it works**: run the APM build/sync step, then `apm install --target <harness>`.  
  **Pros**: most transparent and reproducible; best for development and validation.  
  **Cons**: requires local source checkout and build step.

- **Existing local plugin package**: Install the prebuilt/copied local Copilot plugin folder from this repo (`plugins/mission-control`).  
  **How it works**: `install.ps1`/`install.sh` can rebuild then run Copilot plugin install locally.  
  **Pros**: stable Copilot fallback when APM flow is not what you want.  
  **Cons**: Copilot-specific, not harness-agnostic.

- **APM packed bundle**: Install from a packaged artifact created by `apm pack` instead of source files.  
  **How it works**: produce bundle, then `apm install <bundle> --target <harness>`.  
  **Pros**: shareable artifact, closer to release distribution flow.  
  **Cons**: currently less validated here than source install.

- **APM marketplace**: Install from a published APM registry/market reference.  
  **How it works**: `apm install <marketplace-ref> --target <harness>`.  
  **Pros**: simplest end-user experience at scale.  
  **Cons**: depends on publication pipeline and marketplace validation.

- **Repo-local project extension**: Use the extension that lives inside this repository at `.github/extensions/mission-control/` (Copilot App path).  
  **How it works**: Copilot App loads the extension from the repo itself.  
  **Pros**: fastest way to iterate on app-extension behavior locally.  
  **Cons**: tied to this repo checkout; not a portable install mechanism by itself.

- **APM Copilot App/canvas extension install**: Use APM to place Copilot App extension assets instead of relying on repo-local files.  
  **How it works**: APM installs extension files into the expected app extension location for the selected target.  
  **Pros**: aligns app-extension delivery with the same APM model used elsewhere.  
  **Cons**: still an emerging/validation path for this project.

- **Marketplace-style app distribution**: Deliver Copilot App extension through a marketplace/distribution channel rather than source checkout.  
  **How it works**: users install from a published app/extension distribution reference.  
  **Pros**: easiest non-technical onboarding once mature.  
  **Cons**: publication and validation workflow is still not finalized here.

### Preferred direction: APM source package

```powershell
.\adapters\apm\build.ps1 -Clean
apm install --target copilot
```

To validate the APM install shape across the currently tested targets:

```powershell
.\tests\install\validate-apm.ps1
```

The APM validation script installs the package into disposable folders and checks that the expected files are actually placed there.

### Stable fallback: Copilot CLI plugin

```powershell
.\install\install.ps1 -Source local -Build
```

## What is next

- finish APM bundle install validation
- validate marketplace install flow
- validate APM-driven Copilot App/canvas extension install
- expand validation to cover every installed asset type as the package grows, including skills, hooks, instructions, prompts, commands, MCP config, and app/canvas extension assets

## Source of truth

If you are changing behavior, start from the canonical source files:

- `agents/`
- `skills/`
- `hooks/session-trace/`
- `team/team.json`
- `adapters/*/README.md`
- `agents.md`

Generated package folders are intentionally duplicated install output. Do not edit them as the primary source unless the change is specifically runtime-only.
