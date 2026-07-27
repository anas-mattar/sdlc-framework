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

## 2.3.2

**The first fresh install of the current version, and the three things it found.**
2.3.1 proved the *upgrade* path by walking v2.2.0 → v2.3.0. Nobody had followed the
current `SETUP.md` start to finish. This release is what happened when someone did —
Medium tier, team, multi-repo, both shipped stacks, GitHub — and all three findings
are in the install path rather than the enforcement.

**Pasting the review-evidence command into the manifest produced invalid JSON.**
`SETUP.md` Q7 says to record `review_evidence_cmd` in
`.claude/framework-manifest.json`. That is a JSON string value, and three of the four
commands in `tooling/ci/README.md` contain double quotes:

```
gh pr view --json reviews --jq '[.reviews[] | select(.state=="APPROVED") | .author.login]'
```

Paste it as instructed and the manifest no longer parses — so `/framework-doctor`,
which reads that file, fails at the last step of the install for a reason nothing
warned about. It broke on GitHub, Azure DevOps and Bitbucket; only GitLab's command
is quote-free. The README now carries both forms side by side, plain for `CLAUDE.md`
and escaped for the manifest, plus a one-liner that derives the escaped value. The
suite substitutes each of the four escaped commands into the template and parses the
result — the template alone proved nothing, because it holds a placeholder and is
therefore always valid.

**`/framework-doctor` check 2 failed on a correctly completed install.** It grepped
for a bare `{{`, and five hits survive filling every genuine placeholder: the
template's own instruction line in `CLAUDE.md`, and four comments in the node gate
scripts explaining the convention — one of which tripped the check while describing
it. A doctor that fails a correct install is a doctor whose output gets skimmed, and
then a real `{{SOLUTION}}` walks through; that is the argument this framework makes
about the pin and about code ownership, applied to its own diagnostics. The pattern
is now anchored to `{{UPPER_SNAKE}}`, which is the only form the templates ship.

**Step 5 left a second copy of the manifest template in `.claude/`.** "Copy
`tooling/claude/` content" brought `framework-manifest.template.json` along; step 7
then installs it under a different name. The result is a file with 26 unfilled
placeholders sitting inside the directory the guards protect, recorded in no manifest
and mentioned by no check. Step 5 now names the three things to copy.

**And one the fixes themselves introduced.** Chasing a loose end — a per-platform
wrapper filename rule added in 2.3.1 with no fixture row — showed the rule was not
loose at all: it was *masking* a bug. 2.3.1 put its new dotfile-config test in the
same `case` as the extension tests, and a `case` stops at its first matching arm, so
every dotfile matched `.*)` and the block ended before `*.md`, `*.json` or `*.yml`
were ever reached. `.foo.md` classified as **source** while `README.md` did not —
along with `.bar.json`, `.baz.yaml`, `.notes.txt`, `.data.csv` and `.lock.sum`. The
filename rule happened to catch the one instance anybody had noticed,
`.gitlab-ci.yml`, which is why it looked redundant rather than load-bearing.

The dotfile test now sits in its own `case` after the extension block, so an excluded
extension wins and an extension-less dotfile is still skipped. The filename rule is
gone from both twins, since all three wrapper names end in `.yml` and were already
covered.

This was a **real sh/ps1 divergence** for the length of 2.3.1: `check-stubs.ps1`
expresses the same rules as sequential `if`s, each returning only on its own match,
so the ordering costs nothing there and it was correct throughout. Same rules, same
order, different construct — and only one of them had the bug. Seven fixture rows now
pin the agreement.

**And the docs now say which wrappers have actually run.** Only the GitHub one has
ever executed on a real runner — where it earned its place, catching a CRLF-only bug
invisible on a local checkout and a `.sh`/`.ps1` divergence five review rounds had
missed. GitLab, Azure DevOps and Bitbucket are reviewed text. What the suite proves
about all four is narrow and is now stated as such: that every wrapper invokes all
six steps and marks none of them allowed-to-fail. That is a check on the wrapper's
*text*. It says nothing about whether the runner accepts the YAML, whether the image
has `sha256sum` and `awk`, whether the checkout is deep enough for `git write-tree`
to give the same fingerprint, or whether the job is required rather than advisory.
`SETUP.md` and `tooling/ci/README.md` now tell installers on those three platforms to
break the gate on purpose and confirm it blocks — a gate that reports without
blocking is worse than none, because it produces evidence of a check that is not
there.

Suite: 104 passing.

**Upgrade actions**

| Action | What |
|---|---|
| **Re-copy** | `.claude/commands/framework-doctor.md` |
| **Re-copy** | `check-stubs.sh` and `check-stubs.ps1` — the dotfile shadowing fix |
| **Action** | if `.claude/framework-manifest.template.json` exists in your project, delete it — step 5 used to copy it in by accident |
| **Action** | **re-baseline the ratchet** if you have any dotfile with an excluded extension (`.foo.md`, `.something.json`) carrying a marker. Those counted under 2.3.1 and no longer do, so the count may drop |
| **Check by hand, once** | your manifest parses: `python3 -c "import json;json.load(open('.claude/framework-manifest.json'))"`. If it does not, the review-evidence command needs its double quotes escaped — see `tooling/ci/README.md` |
| **Check by hand, once** | **not on GitHub?** Break the gate on purpose — add a `// TODO` to a source file — and confirm the pipeline goes red *and* the change request will not merge. Those three wrappers have never run on a real runner |

## 2.3.1

**The first real upgrade rehearsal, and the five things it found.** A v2.2.0
multi-repo install was built from the tag — Medium tier, team, both shipped stacks,
a wrapper plus two sub-repos, worked in with a feature spec and layer-3 knowledge —
then upgraded to v2.3.0. The upgrade completed. Five things were wrong on the way,
and one of them was introduced by 2.3.0 itself.

**`tooling/ci/gate-ci.sh` was in neither protection.** The install guard
deliberately leaves `gate.*` and `check-stubs.*` outside its perimeter *on the
stated grounds that CI pins them* — and when 2.3.0 moved the six enforcement steps
out of the platform YAML into that one script, the file deciding what CI enforces
was covered by neither the pin nor the perimeter. Code ownership only, which is
advisory until somebody reads the diff. It is in `PINNED` now, and tampering with
it fails the pin step.

**The stub ratchet counted the framework's own tooling as project source.** A fresh
multi-repo install with *zero application code* baselined at **1**, from the word
`TODO` in a **comment** inside `gate-ci.sh`. Appending one more explanatory
`# TODO:` line there then failed the ratchet on a project whose own code had not
changed — so every framework release that edits a comment in its own tooling would
break every consuming project's ratchet. `gate.sh`, `gate.ps1`, `gate-ci.sh`,
`.claude/`, `.github/` and the per-platform wrapper filenames are excluded now, and
a zero-code install baselines at 0. There is deliberately **no** `tooling/ci/`
directory rule: the only framework file there is `gate-ci.sh`, already excluded by
basename, and a directory rule swallowed a project's own
`src/tooling/ci/pipeline.ts`. Excluding a path because it *resembles* the
framework's layout is how a ratchet stops counting the code it exists for.

**Leading-dot config files counted as source.** `.gitignore`, `.gitattributes`,
`.editorconfig`, `.npmrc` — while `README.md` did not, purely because the deny-list
happened to name one and not the other. A dotfile *with* a code extension
(`.eslintrc.js`) still counts.

**`/framework-upgrade` Step 3's drift recipe was file-only.** Eight of the
manifest's twenty-two entries are directories — all of layer 2, the hooks, the
slash commands, the layer-3 skeletons. `git show v2.2.0:process/` prints a tree
*listing*, not files, and the documented `diff` then exits 2. It failed loudly
rather than reporting false agreement, which is the only reason this was a nuisance
and not a hole — but the step that earns the command had no working recipe for 36%
of the manifest. `git archive | tar x` with `diff -r` covers both kinds.

**Step 2's manifest reconstruction pointed at a template describing only the
current layout.** So reconstructing for a pre-2.3.0 install produced wrong
`installed` paths for exactly the files a breaking rename had moved. Step 2 now
carries the v2.2.0 mapping table and says to read the installed side off disk and
the upstream side out of that version's own `SETUP.md`.

Two findings about the **suite** rather than the framework. The classification
fixture only ran when `pwsh` was present, so on every macOS and Linux machine all
80 paths went unchecked and the `.sh` classifier could regress freely — found by
reverting a fresh fix and watching the suite stay green. And seventeen fixture rows
used padded whitespace, because the file's own header aligned its two examples into
columns while `--classify` prints one space; the rows added in this release would
themselves have failed CI.

Suite: 103 passing.

**Upgrade actions**

| Action | What |
|---|---|
| **Re-copy** | `check-stubs.sh` and `check-stubs.ps1` |
| **Re-copy** | `tooling/ci/gate-ci.sh`, into every code repo |
| **Re-copy** | `.claude/commands/framework-upgrade.md` |
| **Action** | **Re-baseline the ratchet.** The count will DROP, because the framework's own installed tooling no longer counts. Run `sh check-stubs.sh --baseline` and commit `.gate-stubs-baseline`, or the next CI run reports "improved" and invites you to do it anyway |
| **Action** | **Regenerate `.gate-sha256`.** `PINNED` gained a sixth entry — `tooling/ci/gate-ci.sh` — so a pin written before this release no longer names every pinned file and CI will fail with `UNPINNED`. The command is printed by `--baseline` and in `SETUP.md` |
| **Check by hand, once** | if any `.gitignore`-style config file was carrying a marker you relied on being counted, it no longer is |

## 2.3.0

### The last five findings: globs, quotes, `cp`, trailing dots, and the exemption's scope

Five bypasses, none critical on its own, all in the two guards and the ratchet.
**29 fixture rows were added before any of them was fixed** — 23 failed on the first
run — and the behavioural fixture is now 128 cases.

**A glob never contains the string it matches.** The perimeter was tested with a
literal substring, so `rm -rf .cla*` removed `.claude` entirely while never
mentioning it. Verified as ordinary shell, not evasion syntax:

```
$ ls -a          .  ..  .claude
$ rm -rf .cla*
$ ls -a          .  ..
```

Any word carrying `*`, `?` or `[` is now checked by its non-glob prefix: `.cla*` →
`.cla` is a prefix of `.claude`, so it is a hit; `dist/*` → `dist/` is not. A bare
`*` has an empty prefix, which is a prefix of everything, so it blocks — `rm -rf *`
at the project root really would take the perimeter with it.

**A quote inside a word is removed by the shell, not treated as a separator.** The
normaliser mapped `"` and `'` to a *space*, which is right at a word boundary and
exactly wrong inside one: `npm in"stall" x` became `npm in stall x`, so the word
`install` existed in no haystack and no pattern could match. A backslash failed from
the other side — mapped to `/` for path stripping, `n\pm install x` became
`n/pm install x` and the path rule then deleted the word. There are now six
haystacks: three with those characters translated, three with them **deleted**.

**Enumerating option spellings loses to a tool with abbreviation matching.** The
round-4 fix listed `-t`, `--target-directory` and `-*t`; GNU `cp` also takes the
directory attached to the short option and any unambiguous long-option
abbreviation. `cp -t.claude/hooks /tmp/x` and `cp --targ=.claude/hooks/ /tmp/x`
both overwrote a hook. Inverted: any `cp` segment carrying an option at all treats
a perimeter path as a destination. `cp -v <perimeter> /tmp/out` is now over-blocked,
which is the direction this guard is documented to fail in.

**Win32 strips trailing spaces and dots when it opens a file.** So
`package.json `, `package.json.`, `Gemfile.` and — worst — `.claude/allow-package-changes `
all reached the real file while the guard returned 0. One `Write` with a trailing
space created the marker that disables both guards permanently, on the platform
`settings.json` ships configured for. Now stripped per component, before the slash
squeeze rather than after (squeezing first turned `src/../package.json` into
`src//package.json`, and the directory-shaped patterns are matched against the
whole path).

**The stub exemption was matched against the path.** `grep -H` prefixes each match
with `<path>:<lineno>:`, and the filter ran over the whole line — so
`git mv src/ledger.ts 'src/approved-stub: deferred/'` removed every marker beneath
that directory from the ratchet, silently and without limit. The same "a rename is
not a code-review event" argument this framework already makes about
`latest-ledger.ts`. It was also a divergence: the `.sh` counted 1 where the `.ps1`,
which filters the line text only, counted 4. The prefix is now stripped before the
exemption is applied, located by the `:<digits>:` field so a path containing a
colon cannot shift the split.

**Seven install patterns added** — `npm exec`, `npm x`, `go mod tidy`,
`go mod download`, `dotnet restore`, `dotnet tool restore`, `cargo fetch`. Each is a
sibling of a pattern already listed, reached by the spelling the tool's own
documentation uses; `npx` was guarded while `npm exec`, its documented modern
equivalent, was not. The list is 56 → 63 and **all four digests were regenerated**.

Every fix landed on both twins in the same change, and each was verified to fail
with its fix reverted. Suite: 100 passing, 0 failing.

**Upgrade actions**

| Action | What |
|---|---|
| **Re-copy** | `.claude/hooks/guard-installs.{sh,ps1}`, `guard-packages.{sh,ps1}`, `verify-guard.{sh,ps1}`, `check-stubs.{sh,ps1}` |
| **Expect** | `cp -v <perimeter> /tmp/out` to be blocked now. Copy without options, or read with `cat` |
| **Expect** | a wider install block: `dotnet restore` and `go mod tidy` were previously allowed and now need approval, which is a behaviour change in day-to-day work |
| **Check by hand, once** | any `approved-stub:` you relied on. If a *directory* name was carrying the exemption, its markers now count and the ratchet will fail until you baseline or exempt them per line |

### The self-verification stops certifying things it never checked

Three controls reported success while the thing they check was broken. All three
are in the two files a consuming project is left alone with — `verify-guard.sh`,
which is the *only* mechanical check an installed project gets, and the stub
ratchet, whose dangerous failure direction is not "wrong number" but "zero".

**`verify-guard` read hook pairs from outside `hooks.PreToolUse`.** The pair
extractor was a boolean flag set by any line matching `/"PreToolUse"/`, with no
idea where in the document it was. `settings.json` already ships a top-level
`$comment`, so an `$examples` sibling holding a well-formed hook block is
idiomatic rather than suspicious — and this was certified:

```
"$examples": { "PreToolUse": { "file guard": {
    "matcher": "Edit|MultiEdit|Write|NotebookEdit",
    "command": "sh .claude/hooks/guard-packages.sh" } } },
"hooks": { "PreToolUse": [ { "matcher": "Read", "hooks": [ ... ] } ] }
```

What Claude Code installs there is one hook on `Read`, which edits nothing, and no
`Bash` matcher at all: every manifest edit and every install command unguarded,
`GUARD: verified`, CI green. The extractor now counts brace depth and accepts
pairs only inside the real subtree; a `matcher` or `command` key anywhere else is
a hard failure rather than an ingredient. Minified JSON is refused by name instead
of being misread.

**The guard-list floors were counts, so substitution beat them.** Round 4 added
`GUARDED_FLOOR=86` / `INSTALL_FLOOR=56` to stop an 85% cut being certified. A
count detects deletion and not replacement: keeping the twelve commands
`verify-guard` exercises, replacing the other forty-four with `zzjunk00`, and
leaving the line count at 56 produced two `PASS` lines and `GUARD: verified` while
`npm ci`, `yarn install`, `uv add`, `poetry add`, `bundle add`, `conda install`,
`pipx install`, `go install`, `yarn upgrade` and `pnpm dlx` were all open. Both
lists are now pinned by **SHA-256 digest** — four of them, because the configured
command may name either twin and the shipped default names the `.ps1`, so the
PowerShell lists are covered for the first time. Regenerate with
`sh .claude/hooks/verify-guard.sh --print-digests`. Where no digest tool exists
the script falls back to the count, says so, and exits **3** rather than 0.

**The stub ratchet reported a clean tree when the scan failed.** The whole file
list went to a single `exec` with `grep`'s stderr discarded, so a repository large
enough to exceed `ARG_MAX` produced no output, `wc -l` said 0, and the ratchet
printed `STUBS: 0 (baseline 5) — improved` and invited the user to write `0` into
the **pinned** baseline. Measured on 1202 files with 1810-byte paths and one real
marker: `--count` → `0`, rc 0. Now batched through `xargs -0`, with grep's stderr
treated as fatal. Two more silent-zero paths closed with it: `git ls-files`
listing nothing (not a repository, versus a repository containing nothing — not
the same answer) and **UTF-16 source files**, which store `TODO` as
`T\0O\0D\0O\0` and are invisible to a byte-oriented scan. `-a` fixes the NUL-byte
case; the UTF-16 case is refused rather than undercounted, because a Windows
editor produces those by accident.

A note on the fix for the fix: the first version of the stub-ratchet change put
`exit 4` inside `all_stub_lines`, which runs on the **left of a pipeline** and in a
command substitution — so it exited a subshell and the script carried on to report
a clean tree. Exactly the failure being removed, reintroduced by its own remedy.
There is now a sentinel file and an `assert_scan_ok` the main shell calls.

**And a second one, worth recording because it is this project's signature
failure.** All three fixes above landed on the `.sh` side only. For a few hours the
tree therefore shipped:

| | `.sh` | `.ps1` |
|---|---|---|
| W2 substituted list | pinned by digest | `$GuardedFloor = 86` — **still counting** |
| W4 unreadable tree | exits 4 | returned 0 |
| W4 UTF-16 source | exits 4 | **counted** it (`Select-String` decodes UTF-16) |

The W2 row was the serious one: `settings.json` ships the PowerShell commands
*because* that is the platform where the POSIX form fails open, so the fix was
absent from the platform most likely to run it. The W4 rows were worse in kind —
not merely unfixed but **disagreeing**, two verdicts for one tree. Both twins now
pin four digests and refuse both trees, and `verify-guard.ps1` gained
`-PrintDigests`.

Neither divergence was reachable by the existing parity coverage: it compares
counts on this repository's own tree (which has no UTF-16 file) and classification
verdicts about *paths*, not encodings. Two checks close that:

- **11b-0** builds an unreadable tree and a UTF-16 tree and asserts **both**
  implementations refuse. A count of `0` from either fails it.
- **11b-iii** asserts both verifiers pin four digests, that the four values are the
  same on both sides, *and* that they are the digests of the lists on disk right
  now — constants that agree with each other and not with the file are a pin of
  nothing.

The digest constants were verified three ways, because no PowerShell runtime was
available: the POSIX pipeline, an independent reimplementation of the `.ps1`
normalisation, and the values as committed. All four agree. That is not a
substitute for executing `verify-guard.ps1` — CI is still the first thing that
will.

Six new assertions, each verified to fail with its fix reverted: the decoy config,
the substituted list, the unreadable tree, the UTF-16 source, and — closing a
vacuity finding of its own — a mutation of `guard-packages`, because every
existing `verify-guard` assertion mutated `guard-installs`, so deleting
`verify-guard`'s entire 57-line manifest half left the suite byte-identical.

**Upgrade actions**

| Action | What |
|---|---|
| **Re-copy** | `.claude/hooks/verify-guard.sh` and `.ps1`, `check-stubs.sh` and `.ps1` |
| **Check by hand, once** | run `sh .claude/hooks/verify-guard.sh`. Exit 3 now has two distinct causes — the configured interpreter being absent, or no digest tool on the machine — and each says which |
| **Check by hand, once** | if you have edited either guard list in your project, `--print-digests` and paste the four constants, or `verify-guard` will correctly report your own edit as tampering |
| **Expect** | the ratchet to now FAIL rather than report 0 on a repo it cannot read, and to refuse UTF-16 sources. If a UTF-16 file is legitimate, convert it or set `working-tree-encoding` in `.gitattributes` |

### Four hosting platforms, and the CI gate becomes a script

**Breaking: `tooling/ci/gate.yml` and `tooling/ci/CODEOWNERS` are gone.** CI was
GitHub-only in a framework whose stated goal is tool-neutral principles. GitLab,
Azure DevOps and Bitbucket are now supported alongside it.

The gate's six enforcement steps moved out of the workflow YAML into
**`tooling/ci/gate-ci.sh`**, and each platform gets a thin wrapper that invokes
them. This is not a refactor for tidiness. Porting a 250-line exceptions parser
that has had five separate bugs into four YAML dialects would have created four
twins to keep in sync, and this framework's entire defect history is twins that
stopped agreeing in the copy nobody brought along. One script, four wrappers, and a
self-test that asserts every wrapper invokes every step.

New layout:

```
tooling/ci/gate-ci.sh                            the checks (installed everywhere)
tooling/ci/README.md                             the platform matrix
tooling/ci/github/{gate.yml,CODEOWNERS}
tooling/ci/gitlab/{.gitlab-ci.yml,CODEOWNERS}    CODEOWNERS is Premium-only
tooling/ci/azure-devops/{azure-pipelines.yml,branch-policy.md}
tooling/ci/bitbucket/{bitbucket-pipelines.yml,default-reviewers.md}
```

**Ownership is not equal across platforms, and the docs now say so.** GitHub and
GitLab Premium have a tracked, diffable `CODEOWNERS`. Azure DevOps and Bitbucket
have portal configuration that git cannot see and that leaves no trace when it
changes; GitLab Free enforces nothing at all while still parsing the file. Each
carries its own file explaining what you do and do not get, and `CLAUDE.md` gains a
`Perimeter ownership:` line whose accepted value includes `UNOWNED` — because a
documented gap gets budgeted for and an undocumented one gets trusted past.

**Layer 1 no longer names a vendor.** `docs/process/review-process.md` holds the
canonical glossary: *change request* (pull request, or merge request on GitLab),
*protected-branch rules*, *code ownership*. Definition of Done item 6 stopped
hardcoding `gh pr view` and now reads the command from `CLAUDE.md` — a checklist
naming one vendor's CLI cannot be satisfied honestly on any other platform. The
per-platform commands are tabulated in `tooling/ci/README.md`.

**Three findings fixed because they lived in the code being rewritten**, rather
than being left to propagate into four new files:

- The pin's coverage test accepted `$2` of any line while `sha256sum -c` skips
  `#`-comments silently, so a `.gate-sha256` naming every pinned file **as a
  comment**, plus one real hash for `README.md`, passed both halves at once with
  `gate.sh` set to `exit 0`. The naming line now requires a 64-hex digest, and the
  count of lines verified must equal the count of non-blank lines present.
- `bound` was tracked per file while rows of a deadline-less table were skipped, so
  **one decoy table** with a satisfied date disabled the overdue check for every
  other table in the file.
- **Emptying `docs/exceptions.md` of its rows** erased every open exception exactly
  as deleting the file did, for one edit less, and only the file deletion was
  caught. `exceptions.md` documented the hole as intended behaviour; it no longer
  does.

**`/phase-done` gained the multi-repo receipt rule.** A receipt is a `git
write-tree` over one repository, so on the wrapper pattern a sub-repo receipt says
nothing about a `tasks.md` in the wrapper. `repository-strategy.md` now states the
rule — one receipt per repo touched, the wrapper committed first, its tree clean at
phase close, its HEAD recorded in `status.md` — and states plainly what that does
not close.

**Also:** `specs/[feature-name]/` in `project-rules.md` and
`repository-strategy.md` were the last two documents on the pre-2.3.0 spec layout;
the scan that should have caught them matched only angle brackets, so it reported
`0` while the CHANGELOG claimed all 33 occurrences were converted.

**Upgrade actions**

| Action | What |
|---|---|
| **Delete** | `.github/workflows/gate.yml`, `.github/CODEOWNERS` — replaced below |
| **Install** | `tooling/ci/gate-ci.sh` into **every code repo**, at `tooling/ci/gate-ci.sh` |
| **Install** | your platform's wrapper — see the table in `tooling/ci/README.md` |
| **Install** | your platform's ownership file, or read its `.md` and configure the portal |
| **Re-copy** | `process/core/` — `review-process.md` (new glossary), `definition-of-done.md`, `exceptions.md`, `gate-command.md`, `branch-strategy.md`, `project-rules.md` |
| **Re-copy** | `process/optional/repository-strategy.md` if multi-repo — new receipt rule |
| **Re-copy** | `process/team/team-workflow.md`, `tooling/claude/commands/` |
| **Merge** | `CLAUDE.md` — add `Hosting platform:`, `Review evidence:`, `Perimeter ownership:` |
| **Merge** | `.claude/framework-manifest.json` — add `forge` and `review_evidence_cmd`; **move the CI entries into `per_repo_files[]`** (they were installed once per project, so a multi-repo project got one pipeline for whichever repo came first) |
| **Check by hand, once** | `docs/exceptions.md` — if you ever closed an exception by deleting its rows, CI now fails until they are restored and struck through |
| **Check by hand, once** | that the check is *mandatory*, not merely defined. No platform does this from the pipeline file: branch protection (GitHub), Pipelines must succeed (GitLab), a Build Validation policy (Azure DevOps), minimum successful builds (Bitbucket) |

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

### Self-tests: 34 assertions -> 107, across four suites

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
  29 cases. Both the awk program and the whole `run:` block are extracted from the
  shipped `gate.yml` between marker comments rather than copied, so a test cannot
  go on passing after the code it covers has drifted — and the step's exit
  status is asserted, not just what its awk prints.
- **The `.ps1` parity checks now FAIL in CI when `pwsh` is missing** rather than
  skipping. "must not skip in CI" was in the message and nowhere in the code, so
  the whole parity guarantee rested on `ubuntu-latest` continuing to ship it.
- **The stub ratchet is compared behaviourally**, not by its constants — same
  count on the tree, the verdict the fixture demands on 58 fixture paths, same
  flagged lines in one fixture file, and a planted count on a scratch repository
  so the arithmetic itself is asserted and not merely agreed upon.

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

### The newest controls carried the newest bugs

The round-four review found every earlier fix holding and the defects concentrated
in the two controls added last — the ones with the least coverage behind them.

- **The stub counter returned `"0\n0"` on any tree with no markers.** `grep -c`
  prints `0` *and exits 1* when nothing matches, so the `|| echo 0` fallback fired
  as well. That is the state every project adopting the ratchet on a clean
  codebase starts in: `--baseline` wrote a corrupt two-line value into the
  **pinned** baseline file, every comparison then died with `Illegal number`, and
  because a failed `[` is false the script fell through to `exit 0` — the ratchet
  passing inertly. Now `wc -l`, which exits 0 on empty input, plus a self-test
  that plants a known count on a scratch repository and asserts the number.
- **A repository file named `-q` silently zeroed the ratchet.** Tracked paths went
  to `grep` with no `--`, so a filename that looks like an option became one:
  `-q` and `-e` took the count to zero, `-i` re-enabled the case-insensitive
  matching this pair was rewritten to remove, and `*.ts` triggered pathname
  expansion. Enumeration is now NUL-delimited with an option terminator, which
  closes the space-in-path and non-ASCII gaps in the same edit — `git`'s default
  `core.quotePath=true` rendered `src/café.ts` as a quoted C string that matches no
  file, so **both** implementations skipped it in silence, and `mv ledger.ts
  lédger.ts` removed its markers on every platform with no message.
- **`verify-guard` certified a guard whose entire perimeter block had been
  deleted.** The file guard's self-protection was tested; the install guard's was
  not. It now runs the perimeter cases — the approval marker, a hook deletion,
  `sed -i` on the configuration, a redirection, a read-before-write, `rm -rf
  .claude` — and the reads that must still pass.
- **`verify-guard` said `verified` when it had tested a different file.** On Linux
  and macOS the shipped `settings.json` names `powershell`, which is not there, so
  the verifier fell back to the `.sh` sibling — the shipped default state, not an
  attack. Replacing both `.ps1` hooks with `exit 0` produced `GUARD: verified` and
  a green CI step. It now prints `GUARD: partially verified` and exits **3**, and
  the CI step fails on it and explains why.
- **The guard lists could be cut by ~85% and still verify.** Reduced to exactly
  the five commands the verifier tested, `npx`, `pnpm add`, `cargo add`, `bun
  install`, `gem install` and `composer require` all returned 0. The verifiers now
  assert a floor on each list's size and sample across it rather than from its
  front.
- **`cp -t DIR SRC` wrote into the perimeter** on both implementations: the
  destination is named by an option, so the last-argument test read a source file.
  `awk` left the read allowlist when `-i` is present — gawk's `-i inplace` writes.
- **`test` was matched as a substring, so a rename defeated the ratchet.**
  `git mv src/ledger.ts src/latest-ledger.ts` took the count from 1 to 0, as did
  `protest.go`, `contest.rb`, `Greatest.cs` and `attestation.ts`. The basename is
  now split into tokens and `test`/`spec` must *be* one, or end one in CamelCase.
- **Non-string and duplicated JSON values.** `{"command":["npm","install","x"]}`
  was allowed by the `.sh` hook and blocked by the `.ps1`; duplicate keys were
  read first-wins by one and last-wins by the other, so each failed open in one
  direction. Both now fail closed on a value they cannot read as a string, and
  both take the last of a duplicated key — which is what the JSON parser Claude
  Code itself uses does.
- **Options between a tool and its subcommand.** `npm --silent install left-pad`,
  `npm --prefix ./app install x`, `npm -g install x`, `yarn --cwd app add zod`,
  `/usr/local/bin/npm install x` and `npm.cmd install x` are documented
  invocations, and all six were allowed. Matching now also runs over normalised
  copies with options, directory prefixes and Windows executable suffixes removed.
- **`--baseline` and `-Baseline` wrote different bytes** for the same count — and
  the baseline is pinned, so a Windows developer re-baselining at an unchanged
  number tripped `CHANGED: … the gate has been weakened`. A control that cries
  wolf on a no-op is one people learn to regenerate reflexively.
- **The pin now names the `.ps1` halves.** The install guard leaves `gate.*` and
  `check-stubs.*` outside its perimeter *on the grounds that CI pins them*; the
  pin named only the POSIX halves, so the ratchet a Windows developer runs was
  editable in silence. Each file is required only if it exists.
- **The manifest no longer hardcodes two repos.** `repos` is an array and
  `$comment_stacks` says there is no limit of two, but the gate and stub ratchet
  sat in fixed `{{BACKEND_DIR}}`/`{{FRONTEND_DIR}}` slots, so a third repo got no
  entry and `/framework-upgrade` skipped its gate silently. Those entries move to
  `per_repo_files[]`, expanded once per repo. `process/optional/` is three
  independently-installed files and is now listed as three.
- **The exceptions suite tested the awk and not the step.** Changing `exit 1` to
  `exit 0` in the surrounding `run:` block left all 21 assertions green while an
  overdue exception stopped failing CI. The whole block is now extracted and
  executed, with its exit status asserted.
- **Parity is not correctness.** Gutting `is_source` in *both* implementations so
  that nothing was classified as source left the suite fully green — two
  implementations agreeing perfectly about nothing. The classification fixture now
  carries the verdict each path must receive, and neither implementation gets a
  vote on it.
- `is_source` assigned bare `p=`/`b=` with no locals and clobbered its caller's
  loop variable, so `--classify` could name the wrong path in a failure message.

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
| `tooling/ci/gate.yml` | **Merge** — you uncommented a toolchain block. Take the `checkout` (`fetch-depth: 0`), `Pin the gate`, `No overdue exceptions` and `The package guards actually block` hunks; keep your toolchain. Then **regenerate `.gate-sha256`**: the pin step now requires it to name every one of `gate.sh`, `gate.ps1`, `check-stubs.sh`, `check-stubs.ps1` and `.gate-stubs-baseline` that exists, and a pin that names only `gate.sh` fails with `UNPINNED`. |
| `.gate-sha256` | **Regenerate** — `sha256sum gate.sh gate.ps1 check-stubs.sh check-stubs.ps1 .gate-stubs-baseline > .gate-sha256` from each repo root, dropping any of those files this repo does not have. The pin step requires every one that **exists** to be named. |
| `.github/CODEOWNERS` | **Merge** — add `/check-stubs.sh`, `/check-stubs.ps1` and `/.gate-stubs-baseline`, and replace `/docs/stack-backend/` and `/docs/stack-frontend/` with `/docs/stacks/`. Those two lines have matched nothing since 2.3.0 renamed the stack folders, and GitHub ignores a CODEOWNERS path that matches no files **in silence** — so layer 2 has been unowned in every project that believed it was covered. |
| `docs/exceptions.md` | **Check by hand, once.** The check is stricter in four ways and each one used to pass silently: the deadline header must be exactly *Remediate by* or *Due by* (a *Remediation notes* column no longer wins), every row must be as wide as its header, the date must be a real calendar date, and each table binds its own column. If you have an open exceptions table, re-read it against `docs/process/exceptions.md` before your next PR. |
| `tooling/claude/hooks/verify-guard.sh`, `.ps1` | **Copy** — then re-run it; a project that installed only the file guard fails here, which is the point. |
| `tooling/claude/settings.json` | **Merge** — you edited the allowlist. The `PreToolUse` matcher widens to `Edit\|MultiEdit\|Write\|NotebookEdit` and a second `Bash` entry is added for `guard-installs`. Delete any `PowerShell(...)` allow entry: Claude Code has no PowerShell tool, so the entry matched nothing and the prompt it was meant to suppress appeared anyway. A `.ps1` gate is run through `Bash(pwsh -File ./gate.ps1 -Verify)`. |
| `tooling/claude/framework-manifest.template.json` | **Merge** — you filled it in. Add the entry for the manifest itself; move the gate and `check-stubs.*` entries out of the fixed `{{BACKEND_DIR}}`/`{{FRONTEND_DIR}}` slots into `per_repo_files[]`, which is expanded once per entry in `repos[]`; and split `process/optional/` into one entry per file you installed. |
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
