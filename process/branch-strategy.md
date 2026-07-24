# Branch Strategy

Authoritative branch naming and spec-path convention for the project.
This document governs human-facing git branches and how Spec Kit tooling resolves
the feature directory. It complements `docs/process/repository-strategy.md` (which
governs *which repository* a branch lives in and the cross-repository feature rule).

## Decision

The hybrid **`feature/NNN-<name>`** convention is authoritative: a typed prefix, a
sequential three-digit number, and a descriptive kebab-case name. Feature
specifications live under `specs/feature/NNN-<name>/` so the spec path mirrors the
branch name.

## Branch Taxonomy

| Prefix | Use for | Example |
|--------|---------|---------|
| `feature/NNN-<name>` | New functionality / a deliverable feature | `feature/001-order-intake` |
| `fix/NNN-<name>` | Bug fix or correction (incl. post-merge reverts) | `fix/002-quantity-rounding` |
| `chore/NNN-<name>` | Tooling, config, maintenance (no behavior change) | `chore/003-upgrade-framework` |
| `docs/NNN-<name>` | Documentation / governance only | `docs/004-baseline-and-project-setup` |

`NNN` is a zero-padded sequential number shared across all prefixes (the next
number is `max(existing branch and spec numbers) + 1`). `<name>` is lowercase,
kebab-case, descriptive, and stable for the life of the branch.

## Rules

- `main` is **protected**. No direct commits to `main`.
- **One branch per feature.** Do not bundle unrelated work onto a single branch.
- Merge to `main` only **after the gate passes (a valid receipt locally, plus the
  green CI gate on the PR) and human review is approved** (see
  `docs/process/gate-command.md`, `docs/process/review-process.md`, and
  `docs/process/definition-of-done.md`).
- Never force-push `main`.
- Each implementation phase is its own commit on the feature branch so a bad phase
  reverts cleanly (see `docs/process/rollback-process.md`).

## Branch → Spec-Path Mapping (Spec Kit resolution)

The feature directory is resolved from the branch name by stripping the prefix
and reusing the remainder under `specs/feature/`:

```text
branch:     feature/NNN-<name>
spec dir:   specs/feature/NNN-<name>/
            ├─ spec.md
            ├─ plan.md
            ├─ tasks.md               (phase definitions -- fingerprinted)
            ├─ status.md              (phase progress -- NOT fingerprinted)
            ├─ research.md            (optional)
            ├─ data-model.md          (optional)
            ├─ contracts/             (optional)
            ├─ notes.md               (optional)
            ├─ screenshots/           (optional)
            └─ checklists/            (optional)
```

Example: branch `feature/001-order-intake` → `specs/feature/001-order-intake/`.

> **Spec Kit note**: Spec Kit commands resolve the feature directory from the current
> branch path — the prefix (`feature/`, `fix/`, `chore/`, `docs/`) is stripped and the
> numbered remainder is reused under `specs/feature/`. The branch path stays the single
> source of truth: never rename a spec directory independently of its branch. The
> number lives *inside* the name (after the typed prefix), never as a bare `NNN-`
> branch prefix.

## Cross-Repository Features

*Applies only to multi-repo projects — see the optional module in
`docs/process/repository-strategy.md`.*

When a feature spans backend and frontend, create matching branches in each
repository (`{{BACKEND_DIR}}`, `{{FRONTEND_DIR}}`) using the same `NNN-<name>`, and
follow the cross-repository feature rule in `docs/process/repository-strategy.md`
(backend contract defined before frontend implementation; backend merged after
gate + review).
