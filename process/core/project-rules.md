# Project Rules

## Purpose

This project uses an AI coding assistant as a controlled engineering assistant. The AI must follow the SDLC workflow and must not directly implement large features without specification, plan, tasks, gate, and review.

## Session Start

All AI sessions start from the repository root that contains `CLAUDE.md` (for multi-repo projects, the wrapper root).

## Spec First

Implementation starts only after the feature's spec artifacts exist and are
approved. Which artifacts, and how work is gated, follows the **scope tier**
recorded in `CLAUDE.md`:

| | Small | Medium / Large |
|---|---|---|
| Required before implementation | `spec.md` (with the task list inline) | `spec.md`, `plan.md`, `tasks.md` |
| Gate granularity | once per feature | once per phase |
| Review | AI review + developer acceptance | AI review + human review |

In every tier: screenshots are placed in `specs/[feature-name]/screenshots/` when
UI is involved, and implementation never starts from an unapproved spec.

## One Phase Only

*(Medium and Large tiers. Small-tier features are implemented and gated as a
single unit — the rules below then apply once, to the feature.)*

The AI may implement only the current approved phase.

Do not move to another phase until:
1. User runs the gate script (see `docs/process/gate-command.md`).
2. User checks `git diff --stat`.
3. Current phase issues are fixed.
4. User approves the next phase.

## Branch Rule

Use one branch per feature. Do not mix features.

Before implementation:
- Check branch.
- Check working tree.
- Stop if unrelated uncommitted changes exist.

## Commit Rule

Commit each successful phase.

Recommended commit style:

```bash
git add .
git commit -m "feat([feature-name]): complete phase [phase-number]"
```

## Review Rule

AI review is not enough: a **human** approves before merge, in every tier, and
never the AI. Who that human may be — and what counts as evidence that they
approved — is defined once, in `docs/process/definition-of-done.md` item 6.
