# Changelog

All notable changes to this repository should be tracked here.

This project is currently **pre-1.0** and is **not released for production use**. By repository policy, versions below `1.0.0` are treated as alpha. Until testing begins, changes should be recorded under `Unreleased` while the canonical version stays aligned to the `VERSION` file.

Use `.\scripts\version.ps1` to set, bump, sync, and check the repository version state.

Contribution policy:

- Normal PRs append noteworthy entries under `Unreleased`.
- PRs that do not need a changelog entry should use the `no-changelog` label.
- Only maintainers should bump `VERSION`.
- Only release or milestone PRs should move entries out of `Unreleased` into a versioned section such as `## [0.2.0] - 2026-06-19`.

## [Unreleased]

### Added
- APM workspace manifest, generated APM-native package layout, adapter sync script, and APM-first installation guidance for cross-harness Mission Control packaging.
- APM install validation script and GitHub Actions job for fresh-runner source package install checks.
- Generic agent-team source layout under `agents/` and `skills/`
- GitHub Copilot CLI plugin packaging under `plugins/mission-control/`
- Copilot marketplace manifest under `.github/plugin/marketplace.json`
- Installer scripts and Copilot adapter build scaffolding
- Harness-specific maintainer instructions for agents, skills, and hooks
- Session trace hook assets that write minimal Copilot lifecycle metadata to `.tmp/sessions/<sessionId>/session.json`
- Shared communication wrapper schema and Copilot guard hooks for native Mission Control subagent handoffs
- Safety toggles for disabling the whole Copilot plugin or bypassing Mission Control hooks, guard enforcement, or trace writing during live testing
- GitHub Copilot app harness findings and a best-effort project extension for app-supported session/tool trace metadata, including trace-only bypass support
- Per-event trace source labels so overlapping Copilot app and Copilot CLI hook telemetry can be attributed
- GitHub Copilot app session-event telemetry for model, sub-agent, tool, skill, and usage metadata in the shared session trace
- Local Copilot app SDK documentation and type-reference guidance for future extension development
- Intent-driven PR description and commit authoring skills added to canonical `skills/` source with synced generated plugin/APM package copies.

### Changed
- Added repo-wide branch naming governance for app-created worktree sessions and PR policy checks, including rejection of `feature/` branch prefixes and a preference for existing issue-backed branch naming when available.
- Scoped communication guard enforcement to explicit Mission Control agent targets so unrelated custom agents are not blocked by the Mission Control handoff wrapper.

### Fixed
- Serialized GitHub Copilot app extension trace writes so concurrent SDK events do not crash the extension.
- Ignored generated session trace files while preserving `.tmp/sessions/.gitkeep`.
