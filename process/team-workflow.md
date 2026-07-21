# Team Workflow — Multiple Developers

How the framework scales from one developer to a team. Everything per-feature
(spec-first, one-phase-only, gates, source-artifact rules) is unchanged — those
disciplines parallelize cleanly as long as ownership is exclusive. This file adds
the coordination layer.

## 1. One Feature = One Owner = One Branch

The unit of parallelism is the **feature**. Two developers never work in the same
`specs/<feature>/` folder or feature branch simultaneously.

If a feature genuinely needs two people (e.g. backend + frontend), split it into
two features with a contract between them (see rule 5) — the cross-repository
feature rule in `docs/process/repository-strategy.md` is the template.

## 2. The Roadmap Is the Assignment Board

- Roadmap items carry an **Owner** column.
- Claiming a feature = a small commit setting the owner. Two developers cannot
  accidentally start the same feature.
- Status updates happen at **phase boundaries only** (`/phase-done` item 7) and
  are one-line changes — trivially mergeable, so the shared roadmap file does not
  become a merge-conflict hotspot.

## 3. CI Runs the Same Gate Scripts

CI runs `./gate.sh` (or `gate.ps1`) on every PR — the exact script the developer
ran locally. There is no separate CI command chain to drift out of sync.

- Locally, the gate stays user-run (per `docs/process/gate-command.md`).
- CI is the team-level backstop: **no phase merges without a green gate**, even
  if a developer skipped running it.

## 4. Human Review Is Peer Review

On a team, the human review required by
`docs/process/definition-of-done.md` item 6 is a PR reviewed by a developer
**other than the feature's owner** (reviewer ≠ owner). Use
`specs/_templates/human-pr-review-template.md`. Self-review does not satisfy
item 6 when more than one developer is available.

## 5. Contract-First for Shared Surfaces

Parallel features collide at their interfaces: API contracts, shared schemas,
shared components. The rule (generalized from the cross-repository rule):

> Anything two features/developers both depend on gets its contract defined and
> **merged before either side implements against it**.

Changes to a merged contract are a **stop-and-report event** for every feature
that consumes it — never change a shared contract silently mid-phase.

## 6. Settings Split

- `.claude/settings.json` — committed, shared by the team: hooks (e.g. the
  package guard) and the common permissions allowlist.
- `.claude/settings.local.json` — gitignored, per developer: personal
  permissions and machine-specific entries.

A developer must not weaken a shared hook by overriding it locally; changing
shared enforcement is a reviewed commit to `settings.json`.

## What Does NOT Change

- One phase only, gate per phase, spec-first, `git diff --stat` scope checks.
- Source-artifact rules (`docs/process/source-artifacts.md`).
- Session start from the CLAUDE.md root — every developer, every session.
