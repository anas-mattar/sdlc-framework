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

## What a Phase Is

Every rule in this framework is scoped to "a phase", and the word was never
defined — which leaves both gerrymanders open. **One mega-phase** satisfies every
scope rule trivially, because nothing is unrelated when the phase is everything.
**Twelve micro-phases** farm green gates and train the reviewer that these reviews
are formalities, which holds right up until the phase with the authorization bug.

A phase is:

- **One reviewable increment of behaviour.** It changes what the system does, in a
  way a reviewer can state in a sentence without using "and also".
- **Independently gateable.** It builds and its tests pass on its own. A phase that
  only compiles once the *next* phase lands is not a phase.
- **Roughly a day's work, and no more than three.** This is a smell test, not a
  rule with a checker: a phase that has run for a week was either mis-scoped or has
  quietly become three phases, and a phase measured in minutes is probably a step
  within one.

A phase is **not** a layer. "All the repositories, then all the services, then all
the controllers" is three phases none of which can be reviewed for behaviour and
none of which can be gated meaningfully — it is one phase cut the wrong way.

Phases are defined in `tasks.md` **before implementation begins**, and `tasks.md`
is fingerprinted by the gate receipt precisely so that they cannot be redrawn
afterwards to match what was built. Wanting to re-cut the phases mid-flight is a
stop-and-report event, not a paperwork update.

## One Phase Only

*(Medium and Large tiers. Small-tier features are implemented and gated as a
single unit — the rules below then apply once, to the feature.)*

The AI may implement only the current approved phase.

Do not move to another phase until:
1. User runs the gate script (see `docs/process/gate-command.md`).
2. User checks `git diff --stat`.
3. Current phase issues are fixed.
4. User approves the next phase.

## Stop and Report Leaves an Artifact

"Stop and report" is the framework's answer to every conflict between artifacts,
and on its own it is **undetectable**. A silent resolution and no conflict at all
look exactly the same afterwards: both produce working code and no record. The one
checkbox aimed at it is ticked by the same agent that would have done the silent
resolving — a self-report on a self-report.

So it produces a row. Append to `specs/feature/NNN-<name>/decisions.md`:

```markdown
| # | Artifacts in conflict | What each said | Resolved by | Decision |
|---|---|---|---|---|
| 1 | `spec.md` §3 vs screenshot 04 | spec: single-step form; screenshot: two steps | A. Nkemi, 2026-03-04 | Follow the screenshot; spec corrected in the same commit. |
```

And the review requires an **explicit negative assertion**: the AI review states
either the conflicts encountered or *"none encountered"*. "Nothing written" is not
the same claim as "nothing happened", and only one of them is falsifiable.

The gate receipt fingerprints `decisions.md`, exactly as it does `spec.md` and
`tasks.md` — `docs/process/gate-command.md` explains where that boundary falls and
why. A conflict resolved after the gate moved what the phase was measured against.

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
