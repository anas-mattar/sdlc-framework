# Adopting the Framework in an Existing Project

`SETUP.md` covers new projects. This file covers the far more common case: a
project that already has code, history, and habits. The framing that makes
adoption safe:

> **The framework governs new work. It never demands retrofitting old code.**

Rules apply to all new work immediately; surfaces built before adoption are
brought into compliance only as they are touched. Nothing in the framework
requires the existing code to change on day one.

## The Six Steps

### 1. Install without touching code

Follow `SETUP.md` steps 1–8 (answer the six questions, copy the layers, install
tooling, generate CLAUDE.md, verify). Everything lands in `docs/`, `.claude/`,
`specs/`, and the gate scripts — zero code risk. One commit:
`chore: adopt <framework> vX.Y.Z`.

Do not skip step 8. Run `/framework-doctor`, and in particular confirm the guard
self-test reports `GUARD: verified`. On an existing project this is the install
step most likely to fail silently — the hook lands but never runs, and nobody
finds out until an unreviewed dependency reaches a pull request.

### 2. Baseline gate first — before any feature work

Fill in the gate scripts and get the **existing** build and tests to `EXIT: 0`.

- If the project cannot pass its own build/tests today, fixing that is
  **feature 001** — specced, phased, and gated like any other work.
- A green baseline is the regression contract every future phase is measured
  against. This step alone justifies the adoption.
- The baseline run leaves a receipt (`.gate-result.json`) proving the gate was
  green against that exact tree. Gitignore it, and expect it to go **stale** the
  moment feature work begins — that is the mechanism working, not a fault.

### 3. Layer-3 archaeology — the biggest immediate win

Spend a session filling `docs/project/gotchas.md` and
`docs/project/domain-rules.md` with the tribal knowledge that currently lives
only in people's heads: the misspelled name that must stay, the file that isn't
where convention says, the domain vocabulary, the external-system quirks.

This is what makes AI assistance safe on a legacy codebase. Ask every developer
for their "things I'd warn a new hire about" list — that list *is* the file.

### 4. New features follow the full flow from day one

Claim → spec → plan → tasks → gated phases → reviews. No transition period is
needed, because the flow never touches code it wasn't asked to touch (the
`git diff --stat` scope guard enforces this).

### 5. Compliance-as-you-touch for legacy surfaces

Never mass-refactor old code to meet stack rules. A legacy surface is brought
into compliance when — and only when — a feature already requires modifying it.
Record known deviations in `docs/project/` instead of "fixing" them
speculatively; a deviation that is written down is under control.

### 6. Don't backfill specs

Writing specs for already-shipped features is waste. A legacy feature earns its
spec at the moment it is next modified: the spec first captures **current
behavior**, then describes the change. Over time, the actively-maintained parts
of the system become specced — exactly the parts where specs pay off.

## What Adoption Looks Like After Six Months

- Every change since adoption is specced, phased, gated, and reviewed.
- `docs/project/` holds the tribal knowledge that used to be in heads.
- The most-touched legacy surfaces have drifted into compliance naturally.
- Untouched legacy code is exactly as it was — and that is correct: it was
  working before, and nothing rewrote it for process reasons.

## Anti-Patterns

- **The big-bang cleanup** — pausing delivery to "bring the codebase up to the
  rules" before using the framework. The framework needs no such thing, and the
  cleanup itself would violate one-phase-only.
- **Spec archaeology** — backfilling specs for stable, untouched features.
- **Silent divergence** — adopting the docs but skipping the tooling (gates,
  hooks, commands). The prose without the behavior is how process documents
  rot; if you adopt one half, adopt the tooling half.
