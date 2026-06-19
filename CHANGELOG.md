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
- Generic agent-team source layout under `agents/` and `skills/`
- GitHub Copilot CLI plugin packaging under `plugins/mission-control/`
- Copilot marketplace manifest under `.github/plugin/marketplace.json`
- Installer scripts and Copilot adapter build scaffolding
- Harness-specific maintainer instructions for agents, skills, and hooks
