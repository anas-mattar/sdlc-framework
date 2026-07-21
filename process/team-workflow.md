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

## 2a. Feature Numbering — Allocated, Not Computed

Sequential spec numbers (`specs/feature/002-…`) race when two developers start
features concurrently: any scheme that **computes** the next number by scanning
existing folders hands both developers the same number. On a team, numbers are
**allocated** instead:

- **The claim commit is the allocator.** The same roadmap commit that sets the
  owner (rule 2) also assigns the next free number. Order is strict:
  1. Pull the specs repo.
  2. Add the roadmap line: number + feature name + owner.
  3. **Push immediately** — before creating any branch, folder, or spec.
  4. Push rejected? Someone claimed concurrently: pull, take the next free
     number, push again.

  Git itself is the lock — two claims of the same number cannot both land, and
  the collision surfaces at the cheapest moment: before anything references the
  number. Hence the strict order: **claim → push → then branch and spec**,
  never the reverse.
- **The number space is project-wide — one sequence, even with multiple
  roadmaps.** Numbers identify entries in shared namespaces (`specs/feature/`
  folders, branches, commits), so per-roadmap sequences would collide. "Next
  free number" means the highest across **all** roadmaps and existing spec
  folders, plus one (the roadmap index in `docs/roadmap/README.md` makes this a
  quick check). Stream grouping lives in the slug (`014-grn-annex`,
  `015-putaway-zones`), never in the number. On multi-roadmap projects the
  tracker-ID scheme below is especially attractive — issue numbers are already
  one global atomic sequence.
- **The number is identity: allocated once, never recycled, never compacted.**
  Branches, folders, and commits reference it. A cancelled feature's number
  stays burned; gaps are fine — numbers are identifiers, not counters.
- **Scaffold auto-numbering is advisory.** Tools that compute the next number
  from existing directories (e.g. Spec Kit's create-new-feature script) offer a
  suggestion; the roadmap allocation wins on conflict.
- **Sanctioned alternative — tracker issue IDs.** On issue-driven projects
  (GitHub/GitLab), create the issue first and use its number as the spec number
  (`specs/feature/142-…`). The tracker is an atomic allocator: zero
  coordination, and every spec folder links to its ticket. Numbers will be
  sparse and non-contiguous — cosmetic only. Pick ONE scheme per project.

Solo developers are unaffected: with one writer, computed numbering is safe.

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
