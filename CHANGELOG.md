# Changelog

What changed in each version, and **what a consuming project must do about it**.

The commit log says what changed upstream. This file says what to do downstream —
without it, the upstream-first rule in `README.md` cannot be honoured by anyone
who already installed the framework.

## How to read the upgrade actions

| Action | Meaning |
|---|---|
| **Copy** | A layer 1/2 doc. Projects never edit these (layer discipline), so replace the installed copy outright. |
| **Install** | A file that did not exist before. Copy it in; nothing to preserve. |
| **Merge** | You edited this file at install time — `CLAUDE.md` (filled placeholders) and the gate scripts (project commands). Apply the change by hand; **do not overwrite**. |
| **None** | Upstream-only (`README.md`, `SETUP.md`, `ADOPTION.md`, `CHANGELOG.md`, `VERSION`). Nothing to do downstream. |

Installed locations come from `README.md` → *Installed Layout*: `process/` →
`docs/process/`, `stacks/<stack>/` → `docs/stack-backend/` or
`docs/stack-frontend/`, `modules/contracts/` → `docs/contracts/`,
`tooling/claude/` → `.claude/`, `tooling/gate/` → each repo root,
`tooling/ci/` → `.github/workflows/`.

Run `/framework-upgrade <path-to-framework-repo>` to have this walked for you,
including detection of local edits that an upgrade would overwrite.

---

## 2.0.0

**Breaking — the gate contract changed.** A pasted `EXIT: 0` no longer satisfies
the Definition of Done. The gate now writes `.gate-result.json`, a receipt
recording the exit code, the mode, and a fingerprint of the exact working tree it
verified; `--verify`/`-Verify` re-fingerprints and reports
`valid` / `stale` / `min` / `failed` / `missing`. An AI can check a receipt and
cannot fabricate one, and a stale pass no longer counts.

Also in this release:

- **DoD contradiction fixed** — items 1–5 gate the phase *commit*; item 6 (human
  review) gates the *merge*. The old text demanded all six before committing, but
  item 6 needs a commit to review.
- **Package guard fails closed on Windows.** The hook shipped as
  `sh …guard-packages.sh`; without Git Bash that exits 127, which Claude Code
  treats as a hook *error* rather than a block — so the guard silently stopped
  guarding. The Windows command is now the shipped default, and `verify-guard`
  proves the configured hook actually blocks.
- **All `.ps1` files are ASCII-only.** Windows PowerShell 5.1 reads
  UTF-8-without-BOM as ANSI, so an em dash decoded to bytes containing a quote and
  killed the script — which, for a hook, means failing open.
- **CI backstop for every tier.** `SETUP.md` Q5 no longer tells solo developers to
  skip `team-workflow.md` wholesale; that skipped §3, the only mechanical
  enforcement in the framework, and solo projects have no peer review either.
- **An upgrade path exists at all.** This changelog, git tags on every release
  back to `v1.0.0`, and two new commands: `/framework-upgrade` (walk the changelog,
  detect local drift against the recorded version, stop for approval) and
  `/framework-doctor` (prove an install is intact). Until now the upstream-first
  rule had no downstream half — a project on v1.4.0 had no way to learn what
  v1.9.0 changed, let alone what to re-copy.
- **The framework tests itself, in CI.** `tests/run-all.sh` is the framework's own
  gate — static consistency checks plus the receipt contract — and
  `.github/workflows/selftest.yml` runs that same script on every push and PR, so
  there is no separate CI chain to drift. Until this existed, none of the
  enforcement this repo ships was itself enforced: it was verified by hand, once.
- **Layers 1 and 2 are now genuinely reusable.** The layer-discipline check found
  11 references to the original WMS project in the supposedly product-neutral
  layers — including a mandatory frontend compliance checklist instructing every
  project to call `ctx.featcher`, and a stack rule preserving a misspelled
  `purshase-order/` directory. All are genericised, with the specifics moved to
  `docs/project/` where the framework's own layer rule says they belong. The check
  is now at a zero baseline and fails on any reintroduction.

Upgrade:

- **Merge** `tooling/gate/gate-*.{ps1,sh}` → each repo root. You filled in project
  commands here, so port the receipt machinery rather than overwriting: the
  `RECEIPT_EXCLUDES` list, `fingerprint()`/`Get-GateFingerprint`, the `--verify`
  branch, and the receipt write before the `EXIT:` line.
- **Copy** `process/gate-command.md`, `process/definition-of-done.md`,
  `process/team-workflow.md`, `process/branch-strategy.md`,
  `process/orchestration.md`, `process/deployment-standards.md` → `docs/process/`
- **Copy** `tooling/claude/commands/phase-done.md` → `.claude/commands/`
- **Install** `tooling/claude/hooks/verify-guard.{ps1,sh}` → `.claude/hooks/`
- **Install** `tooling/claude/commands/framework-doctor.md` and
  `framework-upgrade.md` → `.claude/commands/`
- **Merge** `tooling/claude/settings.json` → `.claude/` — take the new hook
  command and the two `--verify` allowlist entries; keep your own additions.
- **Install** `tooling/ci/gate.yml` → `.github/workflows/gate.yml`, uncomment your
  toolchain, and require the check on `main`. **Solo projects too.**
- **Merge** `CLAUDE.md.template` → your `CLAUDE.md`: workflow step 7 now requires
  `RECEIPT: valid` instead of a reported `EXIT: 0`.
- **Action** — add `.gate-result.json` to each repo's `.gitignore`.
- **Action** — run `verify-guard` and confirm `GUARD: verified` before trusting
  the package rule again. If you are on macOS/Linux, swap the hook command back to
  `sh .claude/hooks/guard-packages.sh`.
- **None** — `README.md`, `SETUP.md`, `ADOPTION.md`, `CHANGELOG.md`, `VERSION`,
  `tests/receipt-contract.sh`.

---

## 1.9.0 — orchestration governance for multi-agent AI work

Added `process/orchestration.md`: boundaries for running multiple agents —
no agent chain crosses a gate, human gates are not delegable, one writer many
readers, output lands in artifacts not chat. Governance, not a recommendation.

Upgrade:

- **Install** `process/orchestration.md` → `docs/process/`
- **Merge** `CLAUDE.md.template` → your `CLAUDE.md`: add the *"Running multiple
  AI agents/sessions"* row to the Task→Doc map.
- **None** — `README.md`

## 1.8.0 — brownfield adoption path

Added `ADOPTION.md`: install without touching code, baseline gate first, layer-3
archaeology, compliance-as-you-touch, no spec backfilling.

Upgrade:

- **None** — `ADOPTION.md`, `README.md`, `SETUP.md` are upstream-only. Worth
  reading if you adopted into an existing codebase.

## 1.7.0 — optional worktrees for parallel feature checkouts

`team-workflow.md` §7: one worktree = one feature = one branch; per-worktree
package-approval marker; do **not** worktree a multi-repo wrapper.

Upgrade:

- **Copy** `process/team-workflow.md` → `docs/process/`
- **None** — `SETUP.md`

## 1.6.0 — `/claim-feature` command

The feature-claim protocol as an executable command rather than steps to follow
from memory.

Upgrade:

- **Install** `tooling/claude/commands/claim-feature.md` → `.claude/commands/`
- **Copy** `process/team-workflow.md` → `docs/process/`
- **Merge** `CLAUDE.md.template` → your `CLAUDE.md`: workflow step 3 now points at
  `/claim-feature`.

## 1.5.2 — claim commits push directly to main

Explicit, reasoned exemption from the review gate: a claim held on a branch is
invisible to other developers' pulls, so the lock would not exist when needed.
Tracker-issue IDs are the sanctioned alternative where branch protection forbids
direct pushes.

Upgrade:

- **Copy** `process/team-workflow.md` → `docs/process/`

## 1.5.1 — the feature-number space is project-wide

One sequence across **all** roadmaps. Per-roadmap sequences collide, because
numbers name entries in shared namespaces (spec folders, branches).

Upgrade:

- **Copy** `process/team-workflow.md` → `docs/process/`

## 1.5.0 — feature numbers are allocated, not computed

Any scheme that computes the next number by scanning folders hands two developers
the same number. The claim commit is the allocator; git is the lock.

Upgrade:

- **Copy** `process/team-workflow.md` → `docs/process/`
- **None** — `SETUP.md`

## 1.4.0 — roadmap structure and multi-developer workflow

Added `process/team-workflow.md` (ownership, roadmap as assignment board, CI gate,
reviewer ≠ owner, contract-first shared surfaces, settings split). Roadmap rules
added to `source-artifacts.md`.

Upgrade:

- **Install** `process/team-workflow.md` → `docs/process/`
- **Copy** `process/source-artifacts.md` → `docs/process/`
- **Merge** `CLAUDE.md.template` → your `CLAUDE.md`: roadmap as delivery source of
  truth, and the team-workflow row in the Task→Doc map.
- **None** — `README.md`, `SETUP.md`

## 1.3.0 — multi-source rules for guides and requirement docs

Wherever a guide lives (repo file, GitHub/GitLab pinned SHA, Notion export, loose
file), it gets a versioned markdown snapshot in `docs/business/` with provenance
before any spec derives from it.

Upgrade:

- **Copy** `process/source-artifacts.md` → `docs/process/`
- **None** — `SETUP.md`

## 1.2.0 — multi-source prototype rules

HTML, Figma, AI-generated, or no design — all normalise to the same contract, a
frozen `specs/<feature>/screenshots/` with provenance in `notes.md`.
**AI-generated designs require human approval before becoming authority**;
without that, "never invent a UI layout" is circular.

Upgrade:

- **Copy** `process/source-artifacts.md` → `docs/process/`
- **Merge** `CLAUDE.md.template` → your `CLAUDE.md`: the *Design Source &
  Screenshots* section and its fallback chain.
- **None** — `SETUP.md`

## 1.1.0 — source-artifact authority and derivation rules

Added `process/source-artifacts.md`: each artifact type owns one dimension of
authority — roadmap = scope/status, guides = behaviour, prototype = layout. Specs
are *derived*; if a source changes after derivation, report the divergence.

Upgrade:

- **Install** `process/source-artifacts.md` → `docs/process/`
- **Copy** `tooling/claude/commands/phase-done.md` → `.claude/commands/`
  (roadmap-sync step)
- **Merge** `CLAUDE.md.template` → your `CLAUDE.md`: the source-of-truth priority
  list and the derivation note.
- **None** — `README.md`, `SETUP.md`

## 1.0.0 — initial extraction from the WMS project

Layer 1 (`process/`), layer 2 (`stacks/dotnet-api/`, `stacks/nextjs-trpc/`), the
contracts module, the gate scripts, the package-guard hook, `/phase-review`,
`/phase-done`, and `CLAUDE.md.template`.

Upgrade: n/a — this is the baseline.
