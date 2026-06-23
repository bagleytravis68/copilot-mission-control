---
name: intent-driven-commits
description: Minimal guidance for generating high-signal Conventional Commit messages from the diff.
---

# Intent-Driven Commit Messages Skill

Use this skill when generating or improving a git commit message.

## Conventional Commit Format

```text
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

Supported `type` values:

- feat
- fix
- refactor
- perf
- docs
- test
- build
- ci
- chore
- revert

Analyze the diff to determine:

- **Type (required)**: What kind of change is this? Must be one of the supported Conventional Commit types.
- **Scope**: What area/module is affected?
- **Description**: One-line summary of what changed (present tense, imperative mood, <72 chars)
- **Body (optional, concise)**: 1-3 short lines that explain why this change exists and any important context
- Explain what and why, not how

Message quality rules:

- Keep the subject specific and actionable (avoid vague terms like "update" or "changes")
- Do not restate file-by-file diffs in the body
- Keep body to high-signal context only; skip body if no useful rationale is needed
- Prefer one strong sentence over multiple weak sentences
