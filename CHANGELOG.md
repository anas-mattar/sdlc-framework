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

## 2.3.0 (unreleased)

**Fail-closed release.** Four controls reported success while doing nothing. Each
was a place where the framework wrote prose and skipped the mechanism — the exact
failure its own first design principle warns against — so the fixes come with the
self-tests that would have caught them.

### The controls that failed open

| Was | Now |
|---|---|
| `gate.ps1` reported `EXIT: 0` and wrote a **valid** receipt when `yarn`/`dotnet` was not on PATH. `$LASTEXITCODE` is set only by a native executable; an unresolvable command left it `$null`, and `[int]$null` is `0`. | Each step resets `$LASTEXITCODE`, catches `CommandNotFoundException`, and treats "no exit code" as `127`. A Windows and a Linux developer now get the same verdict on the same commit. |
| An unfingerprintable tree recorded `"tree": "unknown"` — and `"unknown" = "unknown"` made that receipt valid **forever**, whatever changed on disk. Triggered by `fatal: detected dubious ownership`, the standard Docker/WSL/CI-container failure. | The gate refuses to write a receipt it cannot fingerprint, and `--verify` reports `RECEIPT: unverifiable` and exits 1. |
| The package guard's approval marker, its `settings.json`, and its own hook script were **not guarded** — and the block message named the marker to create. Two `Write` calls disabled it. | The guard blocks writes to `.claude/allow-package-changes`, `.claude/settings*.json` and `.claude/hooks/*` before anything else, with its own message. |
| The guard matched case-sensitively on POSIX and case-insensitively on Windows. On case-insensitive macOS — where this framework directs users to the `.sh` hook — `Package.json` wrote the real manifest straight past it. | Both guards fold case. Windows paths arriving with doubled backslashes now normalise correctly too. |

### New: the install guard

`guard-packages.*` only ever watched `Edit`/`Write` against manifest **files** —
the least likely way an agent adds a dependency. `npm i`, `yarn add`,
`dotnet add package`, `pip install`, `go get` and `cargo add` are `Bash` calls the
file guard never saw, so a project could run reporting `GUARD: verified` with
every real install path open. `guard-installs.sh` / `.ps1` closes it: 46 command
forms, the same approval marker, the same exit codes.

### Self-tests: 34 assertions → 57

The suite passed while examining almost nothing. Each of these is a check that
now tests what the README already claimed it tested:

- **The internal-link check validated 0 of 218 references.** It searched for
  `](file.md)` markdown links; the repo contains none and hundreds of backticked
  paths. It iterated an empty set and printed `PASS`. Rewritten to resolve
  backticked paths through the installed→upstream map, ratcheted at 0.
- **The layer-discipline check grepped five strings from one former codebase** —
  a regression test against a past mistake, unable to detect a new product name,
  language or tool, while the README claimed layer discipline was "enforced".
  Replaced with structural assertions: layer 1 references no `stacks/` path, uses
  no language-tagged code fence, and names no stack toolchain. The vocabulary
  ratchet is kept for what it is, and now scans `tooling/` as well.
- **`receipt-contract.sh` stubbed out the whole `yarn check && yarn test` line**,
  so the shell operators joining the steps came from the test rather than the
  gate. Injecting `|| true` into the real gate yielded 18/18 PASS. Now only the
  command *words* are stubbed, and four assertions cover `&&` semantics in both
  directions.
- **The two `.ps1` gates had zero behavioural tests** — which is how the
  `EXIT: 0` bug shipped. New `tests/gate-powershell.sh`: 13 assertions, including
  the missing-toolchain, unfingerprintable-tree and one-step-gate arms.
- **No tags now FAILs in CI** rather than skipping. A skipped check in CI is a
  check that is not running.
- New ratchet: no document outside `gate-command.md` may offer an exit code as
  gate evidence. This is what let a MANDATORY stack checklist keep saying
  "confirmed exit code 0" for two releases after v2.0.0 removed it.

### `verify-guard` was blind to the wiring

It read the *first* `"command"` string in `settings.json` and nothing else, so two
misconfigurations verified clean:

- **A missing second hook.** Any project upgrading to this release installs
  `guard-installs`; without the check, one that forgets it still prints
  `GUARD: verified` while every install path stands open.
- **The matcher.** Rewiring the hook to `"matcher": "Read"` — a tool that edits
  nothing — left the command intact and still verified. `/framework-doctor` trusts
  this script, so it reported a completely inert guard as healthy.

Both verifiers now pair each matcher with its command, assert that a matcher
covering `Edit` also covers `Write`, and exercise both guards. Verified against
seven misconfigurations: correct install, `matcher: Read`, install guard removed,
Edit-without-Write, no hooks at all, wrong-platform hook command, and correct
again.

Use `verify-guard.ps1` on Windows. The `.sh` verifier spawns a shell per case and
MSYS fork-and-pipe is slow enough that a long run intermittently stalls — a
verifier that hangs teaches you to stop running it. The two guards' own process
counts are down by a third for the same reason.

### Corrected claims

The README said the receipt is evidence an AI "cannot fabricate". The fingerprint
is a plain `git write-tree` over a documented exclusion list, computed on the
developer's own machine, and the agent is a party with commit access on that
machine. The receipt defends against **staleness and transcription error**; CI is
what makes the gate binding. `README.md`, `process/definition-of-done.md` and
`SECURITY.md` now say so. Overstating the one hard guarantee teaches people to
stop checking the others.

### Also fixed

- `rollback.md` was required by two mandatory checklists and shipped nowhere. It
  is a Large-tier per-feature artifact; it is now named as such in
  `branch-strategy.md`'s spec-directory listing, and both templates reference it
  explicitly and conditionally.
- `.gitattributes` pins `*.ps1` to CRLF and `*.sh`/`*.md` to LF, and the ASCII
  check strips `\r` before testing — so a Windows checkout no longer reports a
  line-ending style as an encoding defect.
- The `stacks/nextjs-trpc` checklist's package rule now names `spec.md` at Small
  tier, which ships no `plan.md`.
- Warehouse-project vocabulary removed from `gate-dotnet.sh` and `gotchas.md`.

### Upgrade actions

| File | Action |
|---|---|
| `tooling/gate/gate-node.sh`, `gate-dotnet.sh`, `gate-node.ps1`, `gate-dotnet.ps1` | **Merge** — you edited the step commands. Take the receipt-machinery and step-runner hunks; keep your steps. `gate-dotnet.ps1` now uses a `$Steps` array like the Node gate. |
| `tooling/claude/hooks/guard-installs.sh`, `.ps1` | **Install** — new files. |
| `tooling/claude/hooks/guard-packages.sh`, `.ps1` | **Copy** |
| `tooling/claude/hooks/verify-guard.sh`, `.ps1` | **Copy** — then re-run it; a project that installed only the file guard fails here, which is the point. |
| `tooling/claude/settings.json` | **Merge** — you edited the allowlist. The `PreToolUse` matcher widens to `Edit\|MultiEdit\|Write\|NotebookEdit` and a second `Bash` entry is added for `guard-installs`. |
| `process/*`, `stacks/nextjs-trpc/compliance-checklist.md` | **Copy** |
| `README.md`, `SETUP.md`, `SECURITY.md`, `CHANGELOG.md`, `VERSION`, `tests/*`, `.gitattributes` | **None** — upstream only. |

After upgrading, re-run `verify-guard` and confirm **both** hooks are wired: a
project that installs only the file guard has the install path standing open.

---

## 2.2.0

**Breaking — the receipt now fingerprints requirements, and status moves to its
own files.** Closes the last correctness gap from the v2.0.0 review.

v2.0-2.1 excluded `specs/*/tasks.md` and the whole of `docs/roadmap/` from the
receipt fingerprint, because `/phase-done` writes phase and feature status into
them *after* the gate runs. But those files also carry **requirements**: a
phase's task definitions, and the roadmap's scope and sequencing. So a task could
be rewritten after the gate to match whatever was actually built, or a roadmap
item quietly descoped, and `--verify` would still report `RECEIPT: valid`. The
receipt claimed the code was measured against requirements that had since moved.

The fix separates the two rather than choosing between them:

| Path | Fingerprinted | |
|---|---|---|
| `specs/<feature>/status.md` | no | **new** — phase progress |
| `specs/<feature>/tasks.md` | **yes** | was excluded — defines the phases |
| `docs/roadmap/status.md` | no | **new** — the delivery board |
| `docs/roadmap/` (everything else) | **yes** | was excluded — scope and sequencing |
| `specs/*/ai-code-review.md`, `specs/*/human-pr-review.md` | no | unchanged — pure review output |

Mixing mutable status into a requirements document forces a choice between a
receipt that goes stale on every status tick and an exclusion that hides
requirement changes. Separating them costs one small file per feature and removes
the choice.

- `/phase-done` Step A now writes `status.md` and refuses to touch `tasks.md`:
  wanting to edit the task definitions at that point means the requirements moved
  during implementation, which is a stop-and-report event, not paperwork.
- **Two new self-tests.** `tests/framework-checks.sh` fails the build if any gate
  script excludes a whole requirements artifact (the v2.0 list is rejected), and
  if the four gate scripts stop agreeing on the exclusion list — they each claim
  to be "identical in every gate script" and nothing enforced it, while
  `receipt-contract.sh` only ever exercises `gate-node.sh`.
- `tests/receipt-contract.sh` now asserts both new directions: `tasks.md` and
  roadmap definitions MUST invalidate; the two `status.md` files MUST NOT.

**Upgrade actions**

| File | Action |
|---|---|
| `tooling/gate/gate-{node,dotnet}.{sh,ps1}` | **Merge** — replace the `RECEIPT_EXCLUDES` / `$ReceiptExcludes` block; keep your project's build commands |
| `process/gate-command.md` | **Copy** → `docs/process/` |
| `process/source-artifacts.md` | **Copy** → `docs/process/` |
| `process/branch-strategy.md`, `process/team-workflow.md` | **Copy** → `docs/process/` |
| `tooling/claude/commands/phase-done.md` | **Copy** → `.claude/commands/` |
| `CLAUDE.md` | **Merge** — add the status-file paragraph to Source of Truth Priority |
| **your specs and roadmap** | **Migrate** — see below |

**Migration (one-time, per project).** Move phase status ticks out of each
`specs/<feature>/tasks.md` into a new `specs/<feature>/status.md`, leaving the
task *definitions* behind. Move the roadmap's status column into
`docs/roadmap/status.md`, leaving scope and sequencing behind. Until you do,
finishing a phase will invalidate the receipt it just verified — the failure is
loud (`RECEIPT: stale`) and cannot pass silently, which is the intended direction
for a breaking change to a control.

Per `README.md` → Support & Version Policy, breaking changes in minor releases
are expected until v3.0.

---

## 2.1.0

**Consistency release.** No new rules — this removes places where the framework
contradicted itself or depended on something it never shipped. Prompted by an
external review of v2.0.0.

- **The Definition of Done is now authoritative on its own.** It previously cited
  constitution principles I, X, XVI and XVII as its authority, and stated that the
  constitution *prevailed* over it — but the framework never shipped or installed
  such a document. Consuming projects were receiving rules that deferred to an
  authority that did not exist. All principle numerals are gone from layers 1 and
  2; `tests/framework-checks.sh` now fails if any come back.
- **Human review is honest about solo projects.** Item 6 still requires a human to
  approve before merge, in every tier — but who that human is now depends on the
  project: an independent peer on a team, the developer's own deliberate
  acceptance review when solo. The old text demanded an independent reviewer that a
  solo project cannot produce, which trains people to ignore rules.
- **Scope tiers reach the rules that implement them.** `project-rules.md` and
  `definition-of-done.md` are now tier-aware: Small requires `spec.md` only and
  gates per feature; Medium/Large require `spec.md` + `plan.md` + `tasks.md` and
  gate per phase. Previously `README.md` promised Small tier one thing and the
  installed rules demanded another. The tier and team size are now recorded in
  `CLAUDE.md`. *(Partial: the rules are conditional, not generated per tier —
  executable tier profiles remain open. See README → Scope Tiers, Known gap.)*
- **Feature numbering defaults to tracker issue IDs** on teams, with the claim
  commit as the alternative for projects without a tracker. The claim commit
  requires a direct push to `main`, which many organizations forbid outright — it
  could not be the default.
- **One feature = one accountable owner**, not one person. A feature may have
  contributors if `spec.md` declares the boundary between them. One branch per
  feature is unchanged: the gate and the scope check both operate on a single diff.
- **Windows self-test entry point** — `tests/run-all.ps1` locates the `sh.exe` that
  Git for Windows already installs and runs `run-all.sh`. A launcher, not a second
  suite; there is still exactly one definition of "the framework passes".
- **v2.0.0 is tagged.** It was released with a `VERSION` bump and a changelog entry
  but no git tag, which made it unreachable by `/framework-upgrade` for every clone
  but the author's. A new self-test fails a `VERSION` with no matching tag, unless
  its changelog heading is marked `(unreleased)`.
- **Public-repository essentials** — `LICENSE` (MIT), `CONTRIBUTING.md`,
  `SECURITY.md`, issue and PR templates, and `examples/minimal-node/`: a real
  Small-tier solo install, checked by the self-tests for unfilled placeholders.
- **The package guard covers every mainstream ecosystem, not just the two with
  shipped stack rules.** It previously matched only `package.json`, the JS
  lockfiles, and the .NET manifests — so on a Python, Go, Rust, Java, PHP, Ruby,
  Swift, Dart or Elixir project it installed cleanly, passed `verify-guard`,
  reported `GUARD: verified`, and then permitted every dependency change
  silently. The rule appeared enforced while enforcing nothing, which is the
  framework's stated worst failure mode. Now 56 patterns across all of those
  ecosystems, matched on the basename so `docs/notes-package.json` and a
  directory named `Gemfile/` no longer false-positive. Two new self-tests: the
  `.sh` and `.ps1` pattern lists must be identical (they are maintained
  separately and nothing else forced them to agree), and the shipped shell guard
  must block and allow the right paths before it is installed anywhere.
- **Positioning corrected** — "Claude Code-first, with tool-neutral SDLC
  principles", labelled a public beta. The process is portable; the enforcement
  (`.claude/` commands, hooks, permissions) is not, and claiming otherwise set up
  users of other assistants to be disappointed.

**Upgrade actions**

| File | Action |
|---|---|
| `process/definition-of-done.md` | **Copy** → `docs/process/` |
| `process/project-rules.md` | **Copy** → `docs/process/` |
| `process/review-process.md` | **Copy** → `docs/process/` |
| `process/branch-strategy.md` | **Copy** → `docs/process/` |
| `process/team-workflow.md` | **Copy** → `docs/process/` |
| `process/templates/*.md` | **Copy** → `specs/_templates/` |
| `tooling/claude/commands/claim-feature.md` | **Copy** → `.claude/commands/` |
| `tooling/claude/hooks/guard-packages.{sh,ps1}` | **Copy** → `.claude/hooks/` — then re-run `verify-guard` |
| `tooling/claude/hooks/verify-guard.{sh,ps1}` | **Copy** → `.claude/hooks/` |
| `CLAUDE.md` | **Merge** — add the `Scope tier:` and `Developers:` lines under `Framework:` |
| everything else | **None** — upstream only |

No gate, receipt, or CI behavior changed in this release. The package guard now
blocks strictly more than before: if your project edits a manifest this list
newly covers, that edit needs `.claude/allow-package-changes` as JS and .NET
manifests always did. Nothing that was blocked before is allowed now. If your project
maintains its own constitution, nothing breaks: it simply is no longer *required*
for the installed rules to make sense.

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
