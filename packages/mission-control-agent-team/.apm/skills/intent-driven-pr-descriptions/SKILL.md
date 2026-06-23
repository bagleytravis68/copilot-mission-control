---
name: intent-driven-pr-descriptions
description: Reusable guidance for generating high-quality, intent-first pull request titles and descriptions.
---

# Customized Pull Request Descriptions Skill

Use this skill whenever generating, improving, or reviewing a pull request title, summary, or description.

## PR Title Rules

Pull request titles MUST follow the Conventional Commit format:

`<type>[optional scope]: <description>`

Examples:

- feat(authentication): allow multi-factor authentication enrollment
- chore(dependencies): upgrade MCP client libraries

### Allowed Types

Use the most appropriate type:

| Type | Purpose |
|--------|---------|
| feat | New functionality or capability |
| fix | Bug fix |
| refactor | Structural improvement without changing behavior |
| perf | Performance improvement |
| docs | Documentation-only change |
| test | Test additions or modifications |
| build | Build or dependency changes |
| ci | CI/CD pipeline changes |
| chore | Maintenance work |
| revert | Reverting a previous change |

### Scope Rules

When possible, include a meaningful scope representing the primary area affected.

Examples:

- feat(authentication): ...
- fix(pr-generation): ...

### Title Description Rules

The description portion should:

- Start with a verb.
- Be concise.
- Explain the outcome.
- Use sentence-style wording.
- Avoid ending punctuation.

Good:
- feat(authentication): allow multi-factor authentication enrollment
- fix(search): prevent duplicate repository indexing

Bad:
- feat(authentication): MFA
- fix: stuff
- update files
- misc changes

## Core Behavior

When asked to generate a pull request description, inspect all available context, including:

- pull request diff
- branch name
- commit messages
- linked work item IDs
- issue references
- explicit user-provided context
- test changes
- configuration or infrastructure changes
- database, API, contract, schema, or migration changes

**Action Item** - If no linked work or issue context is found, prompt the user once to ask if they want to supply a link.

Then generate a PR description using the required structure below.

If context is incomplete, make the best possible PR description from available information and clearly call out any assumptions or missing information in **Notes for Reviewers**.

---

# Required PR Description Structure

## 🧭 What & Why

Start with one concise sentence that explains the intent of the change.

The sentence should describe the business value, user outcome, engineering objective, or problem solved.

The opening sentence must be outcome-aware and should avoid simply restating filenames, commit messages, or implementation details.

---

## 🛠️ Key Changes

Group changes by logical feature, behavior, or impact.

Do **not** group changes by filename.

Use this format:

- **Feature or Fix Name**
 - Explain what changed.
 - Explain why the change was made.
 - Mention important architectural or logical decisions.
 - Include notable behavior changes.
 - Avoid minor syntax, formatting, or mechanical details unless they affect behavior.

---

## 🧪 How This Was Tested

Explicitly describe how the change was verified based on the available diff and context.

Include concrete verification signals only when they are supported by the available information.

Examples:

- `Added unit coverage for work item parsing and fallback behavior.`

Do not invent tests.

If the diff does not show tests and no test evidence is provided, say so plainly.

---

## ⚠️ Notes for Reviewers

Call out anything reviewers should pay special attention to.

If there are no special notes, write:

`No special reviewer notes identified from the provided context.`

---

# WHY Section Enrichment

When work item context is available, the **What & Why** sentence and any WHY-oriented bullets should answer:

- What problem does this solve?
- Who benefits?
- What outcome does this enable?
- Why is this change needed now?
- What acceptance criteria does it satisfy?

Avoid:

- implementation-only explanations
- file-only summaries
- vague statements like `This updates the logic`
- unsupported claims about performance, reliability, or security

Only mention performance, reliability, or security impact when supported by the diff, tests, or work item context.

---

# Output Format

When generating a complete PR description, use exactly this structure:

~~~markdown
## 🧭 What & Why

<One concise sentence explaining the intent, problem solved, or value delivered.>

## 🛠️ Key Changes

- **<Logical Feature or Fix Name>**
 - <What changed and why.>
 - <Important implementation or behavior detail.>

- **<Another Logical Group>**
 - <What changed and why.>

## 🧪 How This Was Tested

- <Specific test or verification step supported by the available context.>
- <If no tests are found, explicitly state that no test evidence was found.>

## ⚠️ Notes for Reviewers

- <Breaking changes, migrations, performance considerations, security implications, assumptions, or warnings.>

If there are no special notes, write exactly:

No special reviewer notes identified from the provided context.
~~~
