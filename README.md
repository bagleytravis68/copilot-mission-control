# copilot-mission-control

Mission Control is a **portable agent-team source repository** with a **GitHub Copilot CLI plugin adapter** and **marketplace manifest** from the start. The repo defines one specialized software-delivery team, keeps the agent source organized in a runtime-neutral structure, and packages that team for Copilot installation through either a plugin command or a helper script.

## Mission

The goal is to make a high-signal AI agent team easy to version, inspect, install, and extend without treating a hidden Copilot folder as the product.

This repository is built around three ideas:

- **generic team source first**
- **runtime adapters second**
- **install surfaces third**

That gives us one canonical team definition today, a real Copilot CLI plugin now, and space to add Claude Code, Codex, or other harnesses later without restructuring the repo again.

## What this repository provides

This repository currently contains:

- the canonical Mission Control agent source under `agents/`
- the canonical Mission Control skill source under `skills/`
- a team manifest under `team/`
- a canonical version file at `VERSION`
- an unreleased change tracker in `CHANGELOG.md`
- a Copilot adapter under `adapters/copilot/`
- an installable Copilot CLI plugin under `plugins/mission-control/`
- a Copilot marketplace manifest under `.github/plugin/marketplace.json`
- installer scripts under `install/`

## Architecture

### 1. Core source of truth

The source of truth for the team lives in:

- `agents/`
- `skills/`
- `team/team.json`

Each agent has its own folder so the team is readable and maintainable without forcing consumers to work directly inside a hidden runtime-specific folder.

### 2. Runtime adapter

The first runtime adapter is **GitHub Copilot CLI**.

The Copilot adapter owns:

- file-name mapping from source agents into plugin agent files
- skill-directory sync from canonical source into plugin skill folders
- the plugin package layout
- the build script that syncs source agents into the plugin bundle
- the marketplace manifest used for discovery and installation

### 3. Install surfaces

This repo supports two Copilot installation paths:

1. **Plugin install** using `copilot plugin install`
2. **Installer script** using `install/install.ps1` or `install/install.sh`

The plugin path is the primary distribution model. The scripts are convenience wrappers and fallback install surfaces.

## Versioning

This repository is currently **pre-1.0** and should be treated as **alpha / unreleased** until testing begins.

- Canonical version source: `VERSION`
- Management script: `.\scripts\version.ps1`
- Combined CI policy guard: `.github/workflows/policy-checks.yml`
- Current working scheme: standard semantic versions below `1.0.0`
- Current stage metadata is mirrored in:
  - `team/team.json`
  - `plugins/mission-control/plugin.json`
  - `.github/plugin/marketplace.json`
- Ongoing changes should be recorded in `CHANGELOG.md` under `Unreleased`

Use the version script instead of editing all version targets manually:

```powershell
.\scripts\version.ps1 -Command show
.\scripts\version.ps1 -Command check
.\scripts\version.ps1 -Command bump-patch
.\scripts\version.ps1 -Command bump-minor
.\scripts\version.ps1 -Command set -Version 0.2.0
```

The script treats `VERSION` as the source of truth and syncs the mirrored runtime/package versions automatically.
GitHub Actions runs `.\scripts\version.ps1 -Command check` on pushes and pull requests so drift fails in CI.

PR policy:

1. Every PR should update `CHANGELOG.md` under `Unreleased`.
2. If a changelog entry is not needed, apply the `no-changelog` label to skip the CI changelog requirement.
3. Only maintainers should bump `VERSION` and the mirrored package versions.
4. Only maintainer-owned milestone or release PRs should move items from `Unreleased` into a versioned changelog section.
5. The combined GitHub Actions policy workflow should stay green.

When to bump:

1. **Patch** (`0.1.0` -> `0.1.1`) for smaller internal milestones, docs/process changes, packaging fixes, or incremental scaffolding work.
2. **Minor** (`0.1.0` -> `0.2.0`) for meaningful new capabilities such as a new harness adapter, new plugin surface, or a substantial expansion of the team package.
3. **Major** (`0.x.y` -> `1.0.0`) only when the repo is tested, intentionally released, and ready to stop being treated as unstable.

Recommended progression:

1. Stay below `1.0.0` while scaffolding and packaging are still being shaped.
2. Use normal semantic bumps during the unstable phase; by repo policy, anything below `1.0.0` is treated as alpha.
3. Do not cut `1.0.0` until the install flow, plugin packaging, and runtime behavior have been tested.

Release or milestone PR workflow:

1. Merge normal contributor PRs into `Unreleased`.
2. When a milestone is ready, a maintainer opens a dedicated PR that:
   - rolls selected `Unreleased` entries into `## [0.x.y] - YYYY-MM-DD`
   - bumps `VERSION` with `.\scripts\version.ps1`
   - lets CI validate the mirrored package versions
3. Merge that PR only after review confirms the changelog is concise and the selected entries are milestone-worthy.

## Agent team

The current team defined in this repository is:

| Agent | Role | Primary responsibility |
| --- | --- | --- |
| Maestro | Orchestrator | Routes work, enforces scope, and quality-checks outcomes |
| Pax | Planner | Produces decision-complete implementation plans |
| Scout | Explorer | Performs fast internal repo discovery and context gathering |
| Ava | Architect | Drives architecture decisions and tradeoff analysis |
| Carl | Coder | Implements features, fixes, and focused refactors |
| Tess | Tester | Creates tests and improves verification coverage |
| Sera | Security | Reviews for vulnerabilities, secrets, and security risk |
| Riley | Relay | Handles CI/CD, pipelines, build scripts, and automation |
| Sam | Scribe | Writes and updates technical documentation |
| Libby | Librarian | Performs external research and documentation lookup |

### Maestro (Orchestrator)

Maestro is the control layer for the team. Maestro classifies work, routes to the smallest useful specialist set, evaluates evidence, and acts as the quality gatekeeper rather than an implementation specialist.

### Pax (Planner)

Pax turns ambiguous work into execution-ready plans with explicit scope, constraints, sequencing, and verification strategy.

### Scout (Explorer)

Scout maps the repository quickly, identifies the right files and patterns, and provides implementation context for the rest of the team.

### Ava (Architect)

Ava handles structural design questions, architecture tradeoffs, and long-term system-shape guidance.

### Carl (Coder)

Carl is the implementation specialist for features, bug fixes, and tightly scoped refactors.

### Tess (Tester)

Tess owns the testing lane: test creation, coverage improvements, edge-case analysis, and verification-focused support.

### Sera (Security)

Sera performs security review and hardening guidance, including vulnerability detection and secret-sensitive analysis.

### Riley (Relay)

Riley owns CI/CD, pipelines, automation workflows, deployment configuration, and build-system changes.

### Sam (Scribe)

Sam writes and updates READMEs, guides, PR descriptions, diagrams, and other technical documentation.

### Libby (Librarian)

Libby performs external research against current documentation, framework behavior, APIs, and third-party guidance.

## Copilot installation model

This repository is structured to work with the **GitHub Copilot CLI plugin system**, not just repo-local custom agents.

### Install from the local plugin bundle

```powershell
copilot plugin install .\plugins\mission-control
```

### Install from the repository subdirectory

```text
copilot plugin install bagleytravis68/copilot-mission-control:plugins/mission-control
```

### Install through the marketplace path

First add this repository as a marketplace:

```powershell
copilot plugin marketplace add bagleytravis68/copilot-mission-control
```

Then install the plugin:

```powershell
copilot plugin install mission-control-agent-team@mission-control-marketplace
```

### Install with the helper script

Local plugin install:

```powershell
.\install\install.ps1 -Source local -Build
```

Marketplace install:

```powershell
.\install\install.ps1 -Source marketplace -MarketplaceSpec bagleytravis68/copilot-mission-control -MarketplaceName mission-control-marketplace
```

## Working with the source

When updating the team:

1. Edit the canonical agent source in `agents/`.
2. Edit the canonical skill source in `skills/` when adding or updating skills.
3. Update metadata in `team/team.json` if the roster or packaging metadata changes.
4. Run the Copilot adapter build script:

```powershell
.\adapters\copilot\build.ps1
```

That script syncs the source agents and source skills into `plugins/mission-control/`.

## Repository layout

```text
.
├─ agents/
│  ├─ ava/
│  ├─ carl/
│  ├─ libby/
│  ├─ maestro/
│  ├─ pax/
│  ├─ riley/
│  ├─ sam/
│  ├─ scout/
│  ├─ sera/
│  └─ tess/
├─ skills/
│  └─ README.md
├─ team/
│  └─ team.json
├─ CHANGELOG.md
├─ VERSION
├─ scripts/
│  └─ version.ps1
├─ adapters/
│  ├─ copilot/
│  │  ├─ INSTRUCTIONS.md
│  │  ├─ README.md
│  │  ├─ build.ps1
│  │  └─ mapping.json
│  ├─ claude-code/
│  │  ├─ INSTRUCTIONS.md
│  └─ codex/
│     ├─ INSTRUCTIONS.md
├─ plugins/
│  └─ mission-control/
│     ├─ plugin.json
│     ├─ agents/
│     └─ skills/
├─ .github/
│  └─ plugin/
│     └─ marketplace.json
├─ install/
│  ├─ install.ps1
│  └─ install.sh
├─ agents.md
└─ README.md
```

## Future adapter space

The repo already reserves adapter space for:

- `adapters/claude-code/`
- `adapters/codex/`

Those folders are placeholders only. They should not be implemented by guesswork. Any future work there should begin by reading the official plugin or extension documentation for that harness and then designing the adapter to match its real packaging and install model.

## Current scope

What is implemented now:

- generic agent-team source folders
- a team manifest
- a Copilot CLI plugin package
- a Copilot marketplace manifest
- local and marketplace-oriented installer scripts
- documentation for maintainers and AI agents

What is intentionally left for later:

- Claude Code adapter implementation
- Codex adapter implementation
- additional skills, hooks, MCP servers, or runtime-specific extensions beyond the initial Copilot plugin packaging

This keeps the initial setup correct for Copilot without locking the repository into a Copilot-only shape.
