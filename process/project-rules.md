# Project Rules

## Purpose

This project uses an AI coding assistant as a controlled engineering assistant. The AI must follow the SDLC workflow and must not directly implement large features without specification, plan, tasks, gate, and review.

## Session Start

All AI sessions start from the repository root that contains `CLAUDE.md` (for multi-repo projects, the wrapper root).

## Spec First

Implementation starts only after:
- `spec.md` defines business behavior.
- `plan.md` defines technical approach.
- `tasks.md` splits execution into small phases.
- Screenshots are placed in `specs/[feature-name]/screenshots/` when UI is involved.

## One Phase Only

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

AI review is not enough. Human review is required before merge.
