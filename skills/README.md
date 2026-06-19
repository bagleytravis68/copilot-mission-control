# Canonical skills

This directory is the canonical source for portable skills in this repository.

Author skills here first, regardless of harness:

1. Create a skill under `skills/<skill-name>/`.
2. Add a required `SKILL.md`.
3. Keep any scripts or supporting files inside that skill directory.
4. Use the relevant runtime adapter instructions to package the skill for a specific harness.

Current adapter status:

- Copilot packaging is implemented via `adapters/copilot/INSTRUCTIONS.md`.
- Claude Code and Codex adapter folders are reserved for future implementation.

Do not author primary skill content directly in the plugin bundle.
