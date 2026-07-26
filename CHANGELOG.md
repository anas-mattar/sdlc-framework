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
`docs/process/`, `stacks/<stack>/` → `docs/stacks/<stack>/`,
`modules/contracts/` → `docs/contracts/`,
`tooling/claude/` → `.claude/`, `tooling/gate/` → each repo root,
`tooling/ci/` → `.github/workflows/` and `.github/CODEOWNERS`.

(Entries for 2.2.0 and earlier name `docs/stack-backend/` and
`docs/stack-frontend/`, the two fixed slots 2.3.0 replaced. They are left as
written: a released entry records what the layout was at the time.)

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
every real install path open. `guard-installs.sh` / `.ps1` closes it: 56 command
forms, the same approval marker, the same exit codes.

### Self-tests: 34 assertions -> 91, across four suites

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
- **The CI exceptions step had no tests at all.** New `tests/exceptions-check.sh`:
  21 cases, and the awk program is extracted from the shipped `gate.yml` between
  marker comments rather than copied, so a test cannot go on passing after the
  code it covers has drifted.
- **The `.ps1` parity checks now FAIL in CI when `pwsh` is missing** rather than
  skipping. "must not skip in CI" was in the message and nowhere in the code, so
  the whole parity guarantee rested on `ubuntu-latest` continuing to ship it.
- **The stub ratchet is compared behaviourally**, not by its constants — same
  count on the tree, same source/skip verdict on 46 fixture paths, same flagged
  lines in one fixture file.

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

### One spec-folder layout, not two

`specs/<feature>/` was asserted by the README, `CLAUDE.md.template`,
`source-artifacts.md` and both slash commands. `specs/feature/NNN-<name>/` was
asserted by `branch-strategy.md` — which calls itself *the authoritative branch
naming and spec-path convention* — both review templates, and the shipped example.
A third form, `specs/feature/<feature>/`, appeared in the example's `CLAUDE.md`.
All 33 occurrences now use `specs/feature/NNN-<name>/`, and a self-test fails on
any reintroduction.

This mattered more than a cosmetic inconsistency. The receipt machinery survived
it **by luck**: git pathspecs are matched with `fnmatch` *without* `FNM_PATHNAME`,
so `*` crosses `/` and `specs/*/status.md` happens to match the nested real path.
The comment directly above that pattern was written in the other layout — so a
maintainer "correcting" the pattern to agree with the comment would have silently
un-excluded every status file, and every receipt would have gone stale the moment
`/phase-done` wrote one. The pathspec behaviour is now documented in all four gate
scripts, where it is load-bearing and was written down nowhere.

`CHANGELOG.md` is deliberately exempt from the new check: it records what past
releases said, and rewriting a released entry to match a later convention is
falsification rather than consistency.

### "~15 minutes" is gone

Realistic best case for a greenfield install on a stack that already ships rules
is half a day; a stack without rules is a day or more, because Question 1 asks you
to author one and there is no template. `SETUP.md` and the example now say so, and
say where the time actually goes — reading enough to answer Q2 and Q6, filling
`CLAUDE.md`, and the first green gate. A user told fifteen minutes who is ninety
minutes in concludes the framework is broken rather than that the estimate was
optimistic, and reads every later instruction with less trust.

### The install manifest — `/framework-upgrade` can finally resolve its own targets

The install **renames** most of what it copies: `stacks/<name>/` becomes
`docs/stack-backend/`, `modules/contracts/` becomes `docs/contracts/`,
`tooling/gate/gate-<stack>.sh` becomes `gate.sh` at each repo root,
`tooling/ci/gate.yml` becomes `.github/workflows/gate.yml`. Nothing recorded those
renames, so drift detection — the step the command calls *the step that earns the
command* — could only handle `docs/process/`, the one 1:1 mapping. It silently
skipped layer 2, the review templates, the gate scripts and CI, which is where all
the editable content lives. The stack identity was destroyed outright: once
`stacks/dotnet-api/` is called `docs/stack-backend/`, nothing on disk says it was
`dotnet-api`.

`.claude/framework-manifest.json` (from `tooling/claude/framework-manifest.template.json`,
written at SETUP step 7) records every installed artifact, the upstream path it came
from, and a class:

| class | an upgrade may |
|---|---|
| `copy` | replace outright; any local difference is a finding |
| `merge` | never overwrite — quote the upstream change for a human to apply |
| `local` | report template changes, never touch the file |

`/framework-upgrade` Step 3 now walks `files[]` instead of a hardcoded directory
list, and refuses to proceed when the recorded version's git tag does not resolve —
diffing against a missing tag reports *no drift at all*, so the upgrade would have
quietly overwritten real local edits. `/framework-doctor` check 7 became a real
layout check instead of asserting a fixed directory list and reporting every
optional path as N/A.

**Preserved regions** resolve a contradiction that made the upgrade contract
unusable. Three layer-1 files ship mandatory `{{PLACEHOLDER}}`s that must be filled
to mean anything, and the CHANGELOG classes them *Copy: replace outright* — fill
them and the next upgrade reverts them, leave them and layer 1 ships broken text.
A `copy` file may now carry one region an upgrade re-inserts:

```markdown
<!-- LOCAL: preserved by /framework-upgrade -->
<!-- /LOCAL -->
```

A self-test asserts every `upstream` path in the template exists, so the template
cannot rot into naming moved files — which would recreate the silent skip it was
written to end.

### The stub ratchet — something finally requires the implementation to be real

Nothing did. The word *coverage* appears nowhere as a requirement, and greps for
`stub`, `TODO`, `not implemented` and `NotImplementedException` across `process/`,
`stacks/` and the commands returned zero hits. The two review checkboxes that
gesture at it do not close the gap: *"tests accompany the behavior introduced in
this phase"* is a **co-location** predicate that a test asserting nothing
satisfies, and *"no tests weakened, skipped, or deleted"* is a **diff** predicate
constraining changes to existing tests while saying nothing about the strength of
new ones.

So a phase could persist a value, leave the block holding the feature's stated core
invariant empty behind a `TODO`, write three tests asserting a status code and the
presence of a field, pass the build, earn a **genuine** valid receipt with no
forgery involved, tick every box in the AI review, and reach *"Done pending human
review"* — with the feature unimplemented. The only thing between that and merge is
the manual acceptance step, which is the first thing that gets rubber-stamped.

`tooling/gate/check-stubs.sh` / `.ps1` is a **ratchet, not a threshold**: a
brownfield repo baselines wherever it is today, and the only rule is that the
number may not rise. Demanding zero would be ignored within a week, and a rule that
gets ignored trains people to ignore the others. It runs as a CI step, covers
tracked *and* untracked files (the gate runs on a dirty tree), excludes tests and
docs, and fails closed with the one-command fix on screen when
`.gate-stubs-baseline` is absent. `approved-stub: <where the spec defers it>`
exempts a line, so a deliberate deferral is declared and reviewable rather than
invisible.

The AI review's unfalsifiable checkbox is replaced with a mapping: **for each
acceptance criterion this phase touches, name the test that would fail if it
regressed.** A criterion with no such test is a FAIL. That is something a reviewer
can spot-check in ten seconds.

### Breaking — n stack slots, and a layer 1 that ships only what you earn

**`docs/stack-backend/` and `docs/stack-frontend/` are replaced by
`docs/stacks/<name>/`, one directory per stack, named after the stack.**

The old layout offered exactly two slots and every cross-reference was written
against those two names, so a project could install **at most two stacks and they
had to map onto a backend/frontend dichotomy**. A Python CLI, a Rust service, a Go
binary, an iOS app, a data pipeline or a library fitted neither slot, and every doc
reference read wrong forever. Mobile + API + admin web was unrepresentable; so was
a monorepo with two backend services. The package guard already covered 56
ecosystems — the tooling was ready for a Go project and the document architecture
was not.

`stacks/TEMPLATE/` now states the file contract, because the two shipped stacks do
not agree on it: one has `architecture-rules.md` with 36 numbered rules, the other
`rules.md` with 8. A third-stack author was reverse-engineering the shape from two
folders that contradict each other.

`CLAUDE.md.template`'s task→doc map no longer ships pre-filled rows naming two
specific stacks' filenames — one of them named after a particular RPC library,
inside a template that claims to be stack-neutral. The stack rows are written at
setup from the files a project's own `docs/stacks/<name>/` folders contain.

Definition of Done item 5 is now conditional in both directions: **each stack this
phase touches**, and only **where that stack ships a compliance checklist**. A
checklist is optional in the stack contract, and demanding one from a stack that
has none makes the item impossible to satisfy honestly — which is how items get
ticked dishonestly.

### The Small tier is actually small now

`process/` is bucketed in the source tree — `core/`, `team/`, `optional/` — and
SETUP copies only the buckets a project's answers earn. **The installed layout is
unchanged and still flat at `docs/process/`**, so every `docs/process/<file>.md`
cross-reference in every document keeps working; only this repository's own
`process/<file>.md` references moved.

| Bucket | Copied when | Words |
|---|---|---|
| `core/` | always | 4,524 |
| `team/` | Q5 says 2+ developers | 1,525 |
| `optional/` | per Q2, Q4, and whether you run agent workflows | 1,312 |

A Small solo install drops from 7,361 to 4,524 words of layer 1, and stops shipping
`team-workflow.md` (which Q5 told it to skip), `repository-strategy.md` (which Q2
told it to skip), `orchestration.md`, and a self-declared placeholder. Text a tier
disclaims but ships anyway is how a file titled MANDATORY ends up overriding its
own tier.

### One source of truth per fact — and a solo project that stops losing CI

Design Principle #2 says *never duplicate a rule in two files, link it*, and this
repository violated it more than any rule it states. That is not untidiness: when
the gate contract changed in v2.0.0 one copy was missed, and a MANDATORY stack
checklist went on saying *"Gate run by the user with confirmed exit code 0"* for
two more releases — telling an AI in writing that a pasted number satisfies the
gate, which is the exact loophole v2.0.0 was written to close. **A fact stated in
seven places changes in six.**

Enforcing this immediately found a live bug introduced by the layer-1 split above.
`team-workflow.md` §3 read *"This section is **not** team-only. A solo project has
no peer review either, so CI is its sole mechanical enforcement"* — and `team/` is
only copied for 2+ developers, so **a solo install would no longer have received
the CI rule at all**. The projects for which CI is the only mechanical enforcement
were the ones about to stop being told to set it up. The rule now lives in
`process/core/gate-command.md` → *CI Runs the Same Gate — Solo Included*, which is
always installed; `team-workflow.md` §3 keeps its number so existing references
resolve, and is now a pointer.

Three restatements of the peer-vs-solo review rule became pointers
(`project-rules.md`, `review-process.md`, `team-workflow.md` §4). Each had restated
the rule *and then* linked to `definition-of-done.md` item 6.

`CONTRIBUTING.md` gains a **Canonical locations** table: eleven rows, one canonical
file per repeated fact, and the rule that makes pointers real — *a pointer is a
sentence, not a paragraph; restating the rule and then linking to it is still a
second copy, it just looks tidier while it drifts.*

`framework-checks.sh` ratchets the spread of the four worst offenders, with
baselines measured rather than aspirational. The check counts **files mentioning a
fact**, not restatements, and says so: no grep can tell a pointer from a copy, and
one that pretended to would be wrong often enough to be trained away — which is the
failure mode this framework names better than anyone. Spread is the proxy, the
table is the judgement, review is where they meet.

### Definitions the framework relied on but never wrote down

- **What a phase is.** Every rule is scoped to "a phase" and the word was never
  defined, leaving both gerrymanders open: one mega-phase satisfies every scope
  rule trivially (nothing is unrelated when the phase is everything), and twelve
  micro-phases farm green gates and train the reviewer that these are formalities
  — which holds right up to the phase with the authorization bug. Now defined in
  `project-rules.md`: one reviewable increment of behaviour, independently
  gateable, roughly a day. Explicitly **not** a layer — "all the repositories,
  then all the services" is one phase cut the wrong way.
- **"Stop and report" now leaves an artifact.** It appeared 13 times across 7
  documents and produced nothing checkable: a silent resolution and no conflict at
  all look identical afterwards. Conflicts become rows in
  `specs/feature/NNN-<name>/decisions.md`, and the AI review requires an explicit
  negative assertion — *"none encountered"* is a claim that can be wrong; silence
  is not. `decisions.md` is fingerprinted, so a conflict resolved after the gate
  invalidates the receipt.
- **One source-of-truth ranking.** Two partial rankings shipped — one over spec
  artifacts, one over rule documents — with no overlap in their middle entries, so
  at least six artifact pairs had no defined order at all, including screenshots
  versus the stack compliance checklist where both are mandatory and both
  reachable. `source-artifacts.md` now carries all 12 entries in one order. Two
  people get wrong: screenshots outrank the spec **for layout and nothing else**,
  and `docs/project/` outranks `docs/stacks/` because a recorded gotcha beats a
  stack convention.
- **What the fingerprint does not cover.** Gitignored files, submodule contents,
  and — sharpest — `.git/info/exclude`, which is not in the worktree, so *the
  change that hides a file is itself unfingerprintable*. These are the boundary of
  what hashing a git tree can mean, not bugs; they are written down because a
  control whose limits are undocumented gets trusted past them.

### An exception path, with a cost

Greps for *waiver, exception, emergency, hotfix, deadline, override, bypass* across
every process document returned **zero hits**. A process with no escape hatch is
not followed more carefully under pressure — it is abandoned under pressure,
silently, and abandonment leaves no artifact.

`process/core/exceptions.md` bounds it: a recorded row naming which Definition of
Done items are unmet, the external forcing function, a **named human** authoriser,
and a remediation date. Every column is required.

The mechanism that makes it work is in `tooling/ci/gate.yml`: **CI fails every
subsequent pull request while an open exception is past its remediation date** —
not the PR that opened it, the next one. An exception path with no cost is just the
process and will be used for convenience within a month; one that blocks the *next*
piece of work gets paid down, because the debt lands on whoever tries to move
rather than on whoever incurred it.

Never available for: committing the package-guard override, weakening `gate.sh` or
CI or `CODEOWNERS` to make a check pass, or skipping human review on money,
permissions or migrations.

### Dependency resolution is guarded, not just declaration

Guard patterns **56 → 86**. The additions cover where packages come *from* rather
than which ones are declared: `.npmrc`, `.yarnrc.yml`, `nuget.config`, `pip.conf`,
`.bundle/config`, `go.work`, `global.json`, `packages.lock.json`, Dockerfiles and
compose files. **A registry redirect is worse than a manifest edit** — it repoints
every dependency in the project at once while the manifest and the lockfile still
look pristine, so the diff a reviewer reads says nothing changed.

### The second implementation always lagged — so parity is now behavioural

An adversarial re-review of this release's own patches found the same shape eight
times: a control was added, and its twin was not brought along. Three of those
defeated controls this release shipped, each with a single character.

| Was | Now |
|---|---|
| **One double quote defeated the entire install guard.** The `.sh` hooks pulled their input out of the payload with `sed -n 's/.*"command".*"\([^"]*\)".*/\1/p'`. `[^"]*` stops at the first quote and nothing un-escapes `\"`, so the guard inspected a truncated string: `npm install left-pad` was blocked, and `echo "installing deps" && npm install left-pad` — ordinary shell, not an evasion — was **allowed**. A literal tab or newline did the same. `guard-packages.sh` had the identical defect on `file_path`. The `.ps1` twins used `ConvertFrom-Json` and were never affected, so this was also a platform split on exactly the hook macOS and Linux users are told to run. | Both `.sh` hooks parse the payload with a string-aware `awk` walk that decodes escapes and only accepts a string as a key when a `:` follows it — so a decoy `"command":"ls"` inside another value is skipped, which the old greedy `.*` got wrong in the other direction by taking the *last* match. One `awk` replaces the two forks it removes. `awk`, not `python3`: this runs on every Bash call and POSIX `awk` is already a dependency of the platform. |
| **Extraction failure meant "allow".** `[ -n "$cmd" ] \|\| exit 0` and the `.ps1` `catch { exit 0 }` both treated an unreadable payload as nothing to judge. | The extractor distinguishes *no such key* (exit 0 — a tool this hook does not judge) from *key present but unreadable* (exit 2). Both platforms now fail closed on a malformed payload, and say so. |
| **The self-guard was case-sensitive, nine lines above the case fold that fixed exactly that bug for manifests.** `.claude/settings.json` was blocked; `.claude/Settings.json`, `.claude/SETTINGS.json`, `.Claude/settings.json` and `.claude/Allow-Package-Changes` were **allowed**. On case-insensitive macOS those are the same file, so one `Write` disabled both hooks. The suite tested `Package.json` for case but never the self-guard. | The self-guard moved below the fold and matches the folded path. `.ps1` was already correct — `-like` is case-insensitive — so this closed a parity gap rather than opening one. |
| **`guard-installs` guarded none of the paths `guard-packages` protects**, so `touch .claude/allow-package-changes`, `printf '{}' > .claude/settings.json` and `rm .claude/hooks/guard-packages.sh` all passed through the Bash hook untouched. The argument in `guard-packages`' own comment — that the block "has to be here, at the moment of the write" — applied verbatim to the hook this release had just added. | Both install guards block **mutation** of the guard's own perimeter, and only mutation: `cat .claude/settings.json` and `sh .claude/hooks/verify-guard.sh` still work, because that is how the doctor reads them. There is deliberately no marker escape hatch — the marker cannot authorise its own creation. `gate.sh` and `.gate-sha256` are deliberately *not* here: they are pinned by CI and owned in CODEOWNERS, and blocking them would block `chmod +x gate.sh` during setup. |
| **`NotebookEdit` was in the matcher and invisible to the guard**, which only ever read `file_path`. | Both file guards fall back to `notebook_path`. |

**Parity is now behavioural, and that is the change that matters.** Every defect
above sat *around* the pattern lists, and the parity self-tests compared the
lists as text — so they passed the entire time, certifying `the same 86 patterns`
while one implementation truncated its input and the other did not.
`tests/fixtures/guard-cases.tsv` is 79 payloads, and every one is executed against
**both** implementations: each must return the expected code, and the two must
agree with each other. Reintroducing the case-fold bug now fails four cases twice
over — once for the wrong answer, once for the disagreement. The string
comparisons are kept as a cheap early warning; they are no longer the only thing
certifying parity.

The `.ps1` side runs through `tests/run-guard-cases.ps1`, one process for the
whole fixture. Spawning `pwsh` per case took the suite from seconds to minutes on
Windows, and a self-test that slow stops being run — which would leave the `.ps1`
hooks exactly as unexercised as they were before.

### The overdue-exceptions check failed every PR, silently

Shipped in this release and wrong in both directions. A `while` loop returns the
status of the last command in its body, so when the last date scanned was *not*
overdue the `&&` list returned 1 → the pipeline returned 1 → the command
substitution returned 1 → GitHub's default `bash -e` killed the step before the
`if` was ever evaluated. **One legitimate open exception with a future date
failed every pull request with no output at all**, and a genuinely overdue row
that was not the *last* row exited 1 without ever printing `OVERDUE:` or its
remediation guidance. The predictable outcome of a step that fails silently and
inexplicably is that someone deletes it, which would have made the mechanism
worse than not shipping it.

It is now one `awk` pass with no `set -e` hazard, and three parser bugs went with
it:

- **The deadline is found by its column header, not by position.** Anchoring to
  the last cell silently disabled the check for every row the moment anyone
  appended a *Status* column. Scanning every cell instead is worse, not better:
  the first column of this table is the date the exception was *opened*, which is
  in the past by definition. A table with no *Remediate by* header now fails
  loudly rather than passing vacuously.
- **`grep -v '~~'` closed rows it should not have.** It dropped a row if `~~`
  appeared anywhere in it, so `~~cancelled~~ prod incident` in the *Why* cell
  closed an exception that was still open. Only the first cell decides now.
- **Deleting `docs/exceptions.md` passed.** The check began `[ -f "$f" ] || exit 0`,
  so removing the file erased every open exception and its deadline. Deleting a
  file that has ever existed now fails the build; the checkout takes
  `fetch-depth: 0` so that test can actually see history rather than passing
  vacuously.

`docs/exceptions.md` is now in CODEOWNERS. Editing a remediation date is how an
exception becomes permanent without anyone deciding that it should.

### The fixes that reopened one layer down

Three of the controls repaired earlier in this release were repaired *at the layer
they were reported at* and stood open one layer below. This is the pattern worth
naming, because it is not a coding mistake — it is what happens when a fix is
written before the test that would have proved it.

- **Quotes stopped defeating the parser and went on defeating the matcher.** The
  extractor rewrite made `echo "hi" && npm install x` readable. The matcher
  underneath it still treated `"` and `'` as ordinary word characters, so the
  padded-glob match never fired on `sh -c "npm install evil"` or
  `eval "pip install requests"` — the character before `npm` was a quote, not a
  space. Shell metacharacters now normalise to whitespace before matching, in both
  implementations. `>` and `<` are deliberately left alone; the perimeter block
  reads them.
- **A read earlier in the same command defeated the guards' own perimeter.** The
  block inspected `${cmd%%"$path"*}` — everything before the **first** occurrence
  of the path — so `ls .claude/settings.json && printf {} > .claude/settings.json`
  moved the inspected window onto a prefix with no verb in it and was allowed. The
  command is now split into simple commands at the shell separators first, and each
  one is judged on its own.
- **The perimeter verb list was a blocklist, and it missed the ordinary verbs.**
  `sed -i`, `/bin/rm` (the old test required a literal space before `rm`),
  `git checkout --`, `git clean -fd`, `perl -pi`, `python -c`, `xargs rm` and
  `find -delete` all wrote to the hook directory unchallenged. It is now an
  **allowlist**: if a perimeter path appears in a segment and its first word is not
  a known read-only tool, the command is blocked. `cat`, `ls`, `grep`, `diff`,
  `head`, `tail`, `stat`, `test`, `git diff`, `sh .claude/hooks/verify-guard.sh`
  and `cp .claude/settings.json /tmp/backup` all still pass — that last one was
  over-blocked before, and backing up the hook config is what `/framework-upgrade`
  would do.

### The JSON extractor: quadratic, unscoped, and open on three truncation shapes

The string-aware extractor built earlier in this release walked the payload one
character at a time and grew each string with `s = s c`. Appending to a string in
awk copies it, so the cost was quadratic: **200KB took 0.5s, 800KB took 11.7s and
1MB took 21.8s** — about 24× its own `.ps1` twin and 170× the `tr`+`sed` pipeline
it replaced. The block comment claimed it was "indistinguishable at every realistic
payload size" on the strength of the 200KB measurement, which is the one number a
quadratic curve and a linear one agree on. A hook that exceeds Claude Code's
timeout is a hook that is not enforcing, so a fix for a correctness bug had opened
an availability path to the same outcome.

It now does one `split()` on the quote character — a single pass in C — and walks
segments. String bodies are skipped by index, never by character and never by
concatenation, and `LC_ALL=C` keeps `substr` counting bytes rather than decoding
the payload to wide characters on every call. Measured end to end on Git
Bash/MSYS, `Write` payloads whose content precedes the path (the worst case — the
whole string is scanned before the key is found):

| Payload | Was | Now |
|---|---|---|
| 200 KB | 0.50s | 1.40s total, of which ~0.15s is the hook |
| 800 KB | 11.7s | 1.49s total |
| 2 MB | (extrapolates to ~90s) | 1.55s total |

Roughly 1.4s of every figure in the *Now* column is MSYS spawning the process at
all, which is why Windows is pointed at the `.ps1` twins and why the curve is
flat rather than falling. Three other defects went with the rewrite:

- **It is scoped to `tool_input`,** matching what the `.ps1` twin has always read.
  Taking the first `command` key *anywhere* in the payload produced five verdict
  divergences, and in four of them the `.sh` hook — the one macOS and Linux users
  are pointed at — was the one that allowed.
- **`\uXXXX` decodes** instead of becoming a space. `"npm install left-pad"`
  used to be extracted as `" pm install left-pad"` and **exit 0** — the
  "value printed successfully" contract — with a value that was not the payload's.
  A code point that cannot be decoded exits 4 and blocks.
- **All four truncation shapes fail closed.** Three of them returned "no such key"
  (allow) while the `.ps1` rejected all four. Any unbalanced brace at the end of the
  payload is now malformed, which is the same answer `ConvertFrom-Json` gives.

`.cargo/config.toml` and `.bundle/config` were in the guarded-manifest list for
three releases and could never fire: the list is matched against the **basename**,
and theirs are `config.toml` and `config`. Patterns containing a `/` are now
matched against the path. Those two files decide where every package in a project
comes from, which is the case the list itself calls worse than a manifest edit.

### The exceptions check, again — four more ways it passed silently

Every defect this check has ever had made it **pass**, which is the only failure
mode that cannot be found by reading it. It now has its own test suite
(`tests/exceptions-check.sh`, 21 cases), extracted from the shipped `gate.yml` so
the tests cannot drift from the code they cover.

- **A column named *Remediation notes* disabled it.** The header was matched with
  `h ~ /remediate|remediation|dueby/` and `next` fired on the first hit, so any
  earlier column whose name contained the word won over the real deadline column.
  `exceptions.md` explicitly invites adding and reordering columns — precisely the
  edit that turned the check off, with no signal. The match is now exact, and two
  deadline columns in one table are an error rather than a coin toss.
- **The column index was bound once per file.** A short row, a second table with
  different columns, and a header written below its own data rows all passed with a
  genuinely overdue exception in the file. The column is re-bound per table, and a
  row whose width does not match its header is now a failure — skipping it is how
  an exception outlives its deadline with nobody noticing.
- **Impossible dates were accepted.** Shape-checked by regex and compared as text,
  so `2026-13-45` bought five months of silence and `9999-99-99` bought forever.
  Month and day are range-checked now, leap years included.
- **A prose-only file hard-failed.** Closing your last exception by removing the
  rows produced `MALFORMED: … has no 'Remediate by' column` on every PR, and the
  file could be neither emptied nor deleted. A file with no table now passes.

### The pin did not name its subject

`sha256sum -c` verifies the lines it is **given** and says nothing about the ones
it is not, so a `.gate-sha256` naming `README.md` passed with `README.md: OK` and
rc=0 while `gate.sh` sat unpinned. This mattered more, not less, once the install
guard's perimeter block started *delegating* `gate.sh` protection to the pin on the
stated grounds that it was "pinned by CI and owned in CODEOWNERS". The reasoning
was sound; the pin it delegated to did not hold.

The `Pin the gate` step now asserts that the pin **names** `gate.sh`,
`check-stubs.sh` and `.gate-stubs-baseline` before verifying it. The stub ratchet
is in there because `echo 9999 > .gate-stubs-baseline` turns it off and the script
then prints `improved` and exits 0 — congratulating you for disabling it — and all
three are in CODEOWNERS for the same reason.

Also in CI, and absent until now: **`verify-guard` runs on every pull request.** A
misconfigured `PreToolUse` hook fails open, and the only thing that says so was a
script nothing ran on a clean checkout. It falls back to the POSIX twin of a
configured `.ps1` command when PowerShell is not on the machine, and says so, so a
Windows-configured project still gets the behavioural assertions in Linux CI.

### The stub ratchet's two implementations returned different numbers

`sh → 1`, `pwsh → 3`, same repository, same four files — while the self-test
printed `PASS check-stubs.sh and .ps1 hunt the same 9 markers`, because it compared
the marker **strings**, which were identical and always had been. The divergence
lived beside them:

- `Select-String` and `-notmatch` are case-**insensitive** by default, so
  `// todo: later` counted on Windows and nowhere else. Both calls are now
  case-sensitive.
- The file filters disagreed. `check-stubs.sh` matched `*[Tt]est*` against the
  whole path and `check-stubs.ps1` matched it against the filename, so
  `src/latest/run.ts` was source on one platform only. Both now implement the same
  rules, rule for rule, and the self-test feeds them the same 50-path fixture and
  diffs the verdicts — plus the same tree, and the same file line by line.
- **`approved-stub:` now needs a reason.** `// TODO: everything approved-stub:`
  exempted the line while saying nothing at all. An escape hatch whose entire cost
  is typing eleven characters is a delete key with extra steps.

### Smaller corrections

- **The Node gate now ships `{{PLACEHOLDER}}`s** like the .NET gate, so
  `/framework-doctor` check 2 catches an uncustomised install. It previously
  shipped real commands with only a comment asking you to change them — and
  `yarn check` is a Yarn 1 command that does not exist in the Yarn version the
  file's own corepack note implies, so the default was broken as well as generic.
- **Every cited rule ID must now resolve.** The README's own example was `F12`,
  which appeared exactly once in the repository: in the sentence claiming it
  exists. The claim now cites real IDs and says coverage is partial *on purpose* —
  an ID earns its place when a reviewer could plausibly disagree, and numbering the
  rest dilutes the ones that matter.
- **The AI review names a tree, not a sha.** It runs pre-commit, so the honest
  answers were "none yet" or `HEAD` — the *previous* phase's commit, actively
  misleading. The receipt's `tree` hash is available pre-commit, identifies exactly
  what was reviewed, and is already printed by `--verify`, which makes the review
  artifact independently checkable for the first time.
- **Feature numbering is no longer stated absolutely.** `max(existing)+1` is
  correct solo and races on a team; `branch-strategy.md` now says so and points at
  `team-workflow.md` §2a, and the "no direct commits to main" rule names the
  claim-commit exemption that exists to prevent exactly that collision.
- **Layer-3 material out of layer 1.** `rollback-process.md` spent 19 of 35 lines
  on posted ledger entries and per-legal-entity scoping — meaningless for a
  compiler, a CLI or a data pipeline, and a mandatory checklist half of which is
  inapplicable trains readers to skim the half that isn't. It is now about
  *irreversible records* generally, with the project's own list pushed to
  `docs/project/domain-rules.md` and a safe default until it exists.
  `deployment-standards.md` is optional, and its "record your identity provider and
  committed-secret locations" section now sits in a `LOCAL` preserved region rather
  than in a file the next upgrade overwrites.
- **Review checkboxes 72 → 68**, and the unapproved-packages box is gone with the
  reason stated: two guards block it at write time and CI fails if the marker was
  committed. Re-checking by eye what a hook already enforces spends the scarcest
  resource in the process on the item least likely to be wrong.
- The example install is stamped v2.3.0 rather than v2.0.0.

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
| `tooling/gate/check-stubs.sh`, `.ps1` | **Install** — new. Copy to each repo root, run `sh check-stubs.sh --baseline`, commit `.gate-stubs-baseline`. |
| `tooling/claude/framework-manifest.template.json` | **Install** — new. Fill it in and commit as `.claude/framework-manifest.json`; `/framework-upgrade` offers to reconstruct one for older installs. Without it the next upgrade still skips layer 2, the templates, the gates and CI. |
| `tooling/ci/CODEOWNERS` | **Install** — new. |
| `process/core/exceptions.md` | **Install** — new, part of `core/`. Create `docs/exceptions.md` only when you first need one. |
| `tooling/gate/gate-node.sh`, `.ps1` | **Merge** — now ships `{{PLACEHOLDER}}`s. Keep your commands; take the other hunks. |
| `tooling/claude/hooks/guard-packages.sh`, `.ps1` | **Copy** |
| `tooling/ci/gate.yml` | **Merge** — you uncommented a toolchain block. Take the `checkout` (`fetch-depth: 0`), `Pin the gate`, `No overdue exceptions` and `The package guards actually block` hunks; keep your toolchain. Then **regenerate `.gate-sha256`**: the pin step now requires it to name `gate.sh`, `check-stubs.sh` and `.gate-stubs-baseline`, and a pin that names only `gate.sh` fails with `UNPINNED`. |
| `.gate-sha256` | **Regenerate** — `sha256sum gate.sh check-stubs.sh .gate-stubs-baseline > .gate-sha256` from each repo root. Add `gate.ps1` if your team runs the PowerShell gate. |
| `.github/CODEOWNERS` | **Merge** — add `/check-stubs.sh`, `/check-stubs.ps1` and `/.gate-stubs-baseline`, and replace `/docs/stack-backend/` and `/docs/stack-frontend/` with `/docs/stacks/`. Those two lines have matched nothing since 2.3.0 renamed the stack folders, and GitHub ignores a CODEOWNERS path that matches no files **in silence** — so layer 2 has been unowned in every project that believed it was covered. |
| `docs/exceptions.md` | **Check by hand, once.** The check is stricter in four ways and each one used to pass silently: the deadline header must be exactly *Remediate by* or *Due by* (a *Remediation notes* column no longer wins), every row must be as wide as its header, the date must be a real calendar date, and each table binds its own column. If you have an open exceptions table, re-read it against `docs/process/exceptions.md` before your next PR. |
| `tooling/claude/hooks/verify-guard.sh`, `.ps1` | **Copy** — then re-run it; a project that installed only the file guard fails here, which is the point. |
| `tooling/claude/settings.json` | **Merge** — you edited the allowlist. The `PreToolUse` matcher widens to `Edit\|MultiEdit\|Write\|NotebookEdit` and a second `Bash` entry is added for `guard-installs`. Delete any `PowerShell(...)` allow entry: Claude Code has no PowerShell tool, so the entry matched nothing and the prompt it was meant to suppress appeared anyway. A `.ps1` gate is run through `Bash(pwsh -File ./gate.ps1 -Verify)`. |
| `tooling/claude/framework-manifest.template.json` | **Merge** — you filled it in. Add the entry for the manifest itself, and the `{{FRONTEND_DIR}}` entries for `check-stubs.*`; without them the upgrade cannot resolve its own record, or the ratchet in a second repo. |
| `CONTRIBUTING.md` | **None** — upstream only; adds the canonical-locations table. |
| `process/*` | **Breaking — re-copy per bucket.** Layer 1 moved to `process/core|team|optional/` upstream. Installed layout is unchanged (flat `docs/process/`), so re-copy `core/` plus whichever of `team/`, `optional/*` your answers earn, and **delete the installed files you no longer earn**. |
| `docs/stack-backend/`, `docs/stack-frontend/` | **Breaking — rename.** `git mv docs/stack-backend docs/stacks/<name>` per stack, keeping the upstream folder name, then update `CLAUDE.md` and the manifest's `stacks` map. |
| `stacks/TEMPLATE/` | **Install** — new; the file contract for writing a stack. |
| `stacks/nextjs-trpc/compliance-checklist.md` | **Copy** |
| `CLAUDE.md.template` | **Merge** — you filled its placeholders. The spec paths in the task→doc map and the source-of-truth list change to `specs/feature/NNN-<name>/`. |
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
