# Setting Up a New Project

> **Existing project?** Read `ADOPTION.md` instead — it wraps these install
> steps in a brownfield path (baseline gate first, tribal-knowledge capture,
> compliance-as-you-touch, no spec backfilling).

Answer the 7 questions, then follow the install steps.

**Budget half a day** for a new project on a stack that already ships rules
(`stacks/dotnet-api/`, `stacks/nextjs-trpc/`), and **a day or more** if you are
writing a new `stacks/` folder — Question 1 asks you to, and there is no template
to start from yet. Existing projects: getting the baseline gate green is the long
pole and is genuinely unbounded; `ADOPTION.md` treats it as feature 001 rather
than as setup, which is the honest framing.

The bulk of the time is not the copying. It is reading enough to answer Q2 and Q6
properly, filling `CLAUDE.md` (seven placeholder types, two architecture
paragraphs, sections to delete), and getting the gate green for the first time.

(You can also hand this file to Claude Code and say "set up this project with the
sdlc-framework at <path>" — it will interview you and do the steps. That removes
the copying, not the decisions or the first green gate.)

## The 7 Questions

**Q1. What stack(s)?**
Determines which `stacks/` folder(s) you copy. If your stack has no folder yet,
create one — start from the closest existing stack, keep the numbered-rule
convention, and strip anything project-specific.

**Q2. Single repo or multi-repo?**
Multi-repo (separate backend/frontend repos under a thin specs-wrapper repo) adds
real coordination cost. Choose it only when the repos have genuinely separate
deploy lifecycles or consumers. If multi-repo: the wrapper repo holds CLAUDE.md,
`docs/`, and `specs/`; each sub-repo gets only a `gate` script and a two-line
`AGENTS.md` pointer ("Rules live in the parent specs repo — do not work in this
repo standalone"). **All AI sessions start from the wrapper root — write that rule
into CLAUDE.md.**

**Q3. Where do designs come from?**
The design source can vary **per feature**: HTML prototype, Figma, AI-generated
mock, or no design at all. All sources normalize to the same contract — a frozen
`specs/feature/NNN-<name>/screenshots/` folder with provenance in `notes.md` — per the
table in `docs/process/source-artifacts.md`. When screenshots exist for a
feature they are the #1 layout authority; when a feature has no design, the
`spec.md` layout section plus the app's design system govern instead. Note the
project's *usual* source here so CLAUDE.md can say so, but do not delete the
fallback chain — different features may use different sources.

**Q4. External integrations?**
If the project calls or is called by external systems (APIs, webhooks, queues),
copy `modules/contracts/` and require a contract doc before any integration code.
Otherwise skip the module.

**Q5. How many developers?**
Solo: skip the *coordination* rules in `docs/process/team-workflow.md` (ownership,
claim commits, reviewer ≠ owner). Human review still applies — it becomes your own
acceptance review, completed deliberately against the human-review template rather
than waived (`docs/process/definition-of-done.md` item 6). **Also still adopt §3,
"CI runs the same gate scripts."** The local gate is run by the developer and its receipt is local
evidence; CI is the only check not performed by the party being checked. A team has
peer review as a second line of defence, and a solo project has nothing else — so
skipping CI removes the last mechanical enforcement in the framework. Install
`tooling/ci/gate-ci.sh` plus your platform's wrapper (Q7) and make the check
mandatory on `main`. Two or more: it applies — roadmap
items carry an Owner column (one feature = one owner = one branch), spec numbers
are allocated via the claim commit or tracker issue IDs (pick one scheme, never
computed by scanning folders), CI runs the same gate scripts on every change
request, human review means reviewer ≠ owner, and shared surfaces are contract-first.
Worktrees for parallel feature checkouts are optional (team-workflow §7). `.claude/settings.json` is committed/shared;
`settings.local.json` is per developer and gitignored.

**Q6. What does a mistake cost?** → picks the scope tier (see README):

- **Low** (internal tool, prototype, easily re-run): **Small** tier — single
  `spec.md` per feature, gate per feature, AI review only. Skip roadmap,
  compliance checklists, and per-phase gating.
- **Medium** (production app, real users, recoverable data): **Medium** tier —
  full spec/plan/tasks, per-phase gates, both reviews, stack checklists.
- **High** (money, inventory, compliance, external systems that sync state):
  **Large** tier — everything, including roadmap as delivery source of truth and
  rollback docs per feature.

Record the answer in `CLAUDE.md` (`Scope tier:`), along with solo/team from Q5
(`Developers:`). These two lines are not decoration: `process/core/project-rules.md`,
`process/core/definition-of-done.md`, and the `/phase-done` command all read them to
decide which artifacts a feature needs and what "human review" means here. An
unfilled tier line means every rule falls back to the strictest reading.

**Q7. Which hosting platform?** → `github`, `gitlab`, `azure-devops`, `bitbucket`

This decides three things, and `tooling/ci/README.md` is the table for all of them:

- **Which CI wrapper you copy.** The gate's logic is in `tooling/ci/gate-ci.sh`,
  which every platform installs; the wrapper is thin and platform-specific.
- **How the enforcement perimeter is owned.** GitHub and GitLab have a
  `CODEOWNERS` file. Azure DevOps and Bitbucket **do not** — ownership is portal
  configuration that is not tracked, not diffable, and leaves no trace in git when
  someone changes it. On those two, read the ownership file in `tooling/ci/<your
  platform>/` and record in `CLAUDE.md` which substitute you chose. **GitLab's
  CODEOWNERS requires Premium**; on Free it is parsed, displayed, and enforces
  nothing.
- **What proves a human approved a change request.** Definition of Done item 6
  needs evidence from outside the working tree, and every platform exposes it
  differently. Copy the command for yours from `tooling/ci/README.md` into
  `CLAUDE.md`. A ticked checkbox in a markdown file is not evidence: the agent
  wrote the file, so it can write the tick.

Record `Hosting platform:` and `Review evidence:` in `CLAUDE.md`, and `forge` and
`review_evidence_cmd` in the manifest. `/framework-doctor` checks the two agree —
a question answered twice and differently has one answer nobody is reading.

## Install Steps

1. **Copy layer 1 (per your answers):**
   The installed layout is **flat** — everything lands in `docs/process/`, and every
   cross-reference in the docs is written against that. The source tree is bucketed
   so a project receives only the rules it earns:

   | Copy | When | Contents |
   |---|---|---|
   | `process/core/*` | **always** | project rules (incl. what a phase is), gate contract, Definition of Done, branch strategy, rollback, source artifacts, review process, exceptions |
   | `process/team/*` | Q5 ≥ 2 developers | `team-workflow.md` — ownership, claim commits, reviewer ≠ owner |
   | `process/optional/repository-strategy.md` | Q2 = multi-repo | the wrapper pattern |
   | `process/optional/orchestration.md` | you use multi-agent AI workflows | agent boundaries |
   | `process/optional/deployment-standards.md` | you want a place to record deploy/secrets conventions | ships as a **placeholder** — fill it or skip it |

   All of them → `<project>/docs/process/` (flat, no subdirectories).

   **Do not copy `process/` wholesale.** A Small solo project that does receives
   `team-workflow.md` (which Q5 told it to skip), `repository-strategy.md` (which
   Q2 told it to skip), and a self-declared placeholder — roughly 2,800 words
   describing behaviour the project does not have. Text a tier disclaims but ships
   anyway is how a mandatory checklist ends up overriding its own tier.
2. **Copy layer 2 (per Q1):**
   - `stacks/<name>/` → `docs/stacks/<name>/`, once per stack, **keeping the folder
     name**. The directory is self-describing, and there is no limit of two: a
     project can install `docs/stacks/go-api/`, `docs/stacks/nextjs-trpc/` and
     `docs/stacks/swift-ios/` side by side. Record each in the manifest's `stacks`
     map under the role it plays.
   - If your stack has no folder yet, copy `stacks/TEMPLATE/` and fill it in — it
     states the file contract so you are not reverse-engineering the shape from the
     two shipped stacks, which do not agree with each other.
3. **Copy modules (per Q4):**
   - `modules/contracts/` → `docs/contracts/`
4. **Create layer 3 (empty):**
   - Copy `tooling/project-docs/` → `docs/project/` (starter skeletons for
     `gotchas.md` and `domain-rules.md`). Every product-specific fact discovered
     during development goes here — misspelled package names that must stay,
     vocabulary, external-system quirks.
   - Create the source-artifact slots that apply (`docs/business/`,
     `docs/prototypes/`, `docs/roadmap/`) and read
     `docs/process/source-artifacts.md` for their rules. If you create
     `docs/roadmap/`, put the mutable board in `docs/roadmap/status.md` and keep
     scope/sequencing in the other files — the gate receipt fingerprints the
     latter and not the former. Each artifact type owns
     one dimension of authority (roadmap = scope/status, guides = behavior,
     prototype = layout); guides and requirement docs — wherever they live
     (repo file, GitHub/GitLab, Notion, loose file) — get a versioned markdown
     snapshot in `docs/business/` with provenance before any spec derives from
     them; specs are derived from these sources, never the reverse.
5. **Install tooling:**
   - Copy the matching gate script(s) from `tooling/gate/` to each repo root;
     fill in the placeholder commands; verify `./gate.ps1` (or `./gate.sh`)
     prints `EXIT: 0` on the untouched baseline **before any feature work**.
   - Add `.gate-result.json` to each repo's `.gitignore`. The gate writes this
     receipt so `/phase-done` can prove a *fresh, full, green* run against the
     current working tree (`docs/process/gate-command.md`); it is local evidence
     and must never be committed.
   - Copy `tooling/gate/check-stubs.sh` (and `.ps1`) to each repo root, run
     `sh check-stubs.sh --baseline`, and commit `.gate-stubs-baseline`. This is
     the only mechanism in the framework that requires the implementation to be
     *real* — everything else is satisfied by code that persists a value and
     leaves the interesting block empty behind a `TODO`. It is a ratchet, not a
     threshold: an existing repo baselines wherever it is today, and the rule is
     only that the number may not rise. Mark a deliberate placeholder with
     `approved-stub: <where the spec defers it>` so the deferral is reviewable.
   - Copy `tooling/claude/` content into `<project>/.claude/` (settings, hooks,
     and the `/claim-feature`, `/phase-review`, `/phase-done`,
     `/framework-doctor`, `/framework-upgrade` commands). Review the permissions
     allowlist. **Two** guards ship and both are wired in `settings.json`:
     `guard-packages` blocks edits to manifest *files*, and `guard-installs`
     blocks the Bash *commands* that rewrite those same manifests (`npm i`,
     `dotnet add package`, `pip install`, `go get`). The file guard alone covers
     the least likely path, so do not install only one.

     **Point both hook commands at an interpreter this machine has, before you go
     any further.** They ship in their Windows form; on macOS/Linux swap them for
     `sh .claude/hooks/guard-packages.sh` and `sh .claude/hooks/guard-installs.sh`.
     This is not a tidiness step. A hook command that cannot run exits non-2,
     Claude Code treats that as a hook *error* rather than a block, and the guard
     silently stops guarding — so the shipped default, left alone on Linux or
     macOS, is an installed guard that enforces nothing.
   - **Prove the package guard actually blocks**: run
     `powershell -NoProfile -File .claude/hooks/verify-guard.ps1` (or
     `sh .claude/hooks/verify-guard.sh`) from the project root. It must print
     `GUARD: verified` and exit 0. Three outcomes, and the middle one is the one
     to know about:

     | Exit | Means |
     |---|---|
     | 0 | `GUARD: verified` — the *configured* hooks were run and they block |
     | 3 | `GUARD: partially verified` — the configured interpreter is absent, so the sibling script was tested instead. **The hook Claude Code runs is untested.** Fix the command (above) and re-run |
     | 1 | `GUARD: BROKEN` — a guard is not enforcing |

     An unverified guard is an absent guard, and a *partially* verified one is an
     absent guard that reports a number. CI treats 3 as a failure.
   - **Install CI — two files per repo, not one.** Copy
     `tooling/ci/gate-ci.sh` to `<repo>/tooling/ci/gate-ci.sh`, then copy your
     platform's wrapper from `tooling/ci/<platform>/` to the path in the table in
     `tooling/ci/README.md`. Uncomment **one** toolchain block in the wrapper (both
     ship commented out). Every check lives in the script; the wrapper only invokes
     it, so a repo with one and not the other has a gate that cannot run.
     **Then make the check mandatory** — this is a separate act on every platform
     and the pipeline file cannot do it for you: branch protection on GitHub,
     "Pipelines must succeed" on GitLab, a Build Validation policy on Azure DevOps,
     a minimum-successful-builds branch restriction on Bitbucket. Do this on solo
     projects too (see Q5). On multi-repo projects, **every code repo needs its own
     pair** — the pipeline runs where the code is.
   - **Baseline the stub ratchet.** From each repo root, run
     `sh check-stubs.sh --baseline` and commit `.gate-stubs-baseline`. It records
     how many unimplemented markers the repo has today; CI fails when the number
     goes up.
   - **Pin the gate.** From each repo root, run
     `sha256sum gate.sh gate.ps1 check-stubs.sh check-stubs.ps1 .gate-stubs-baseline > .gate-sha256`
     and commit all of it — dropping the `.ps1` names only if this repo does not
     have them. CI refuses to run an unpinned gate, and it checks that the pin
     **names** every one of those files that exists — `sha256sum -c` only verifies
     the lines it is given, so a pin listing `README.md` and nothing else reports
     `OK` while the gate sits unpinned. The `.ps1` halves are in the list because
     the install guard deliberately leaves `gate.*` and `check-stubs.*` outside
     its perimeter *on the grounds that CI pins them*; a pin naming only the POSIX
     halves left the ratchet a Windows developer actually runs editable in silence.

     This is what stops the gate being weakened silently: CI runs a script that
     lives in the repository, from the change request's own head branch, so a gate
     edited to `true` produces a genuine receipt and a green build. Pinning does
     not prevent the edit — it makes the edit require a second, obvious line in
     the same diff. `.gate-stubs-baseline` is in there for the same reason:
     `echo 9999 > .gate-stubs-baseline` turns the ratchet off, and the script then
     prints "improved" and exits 0.
   - **Own the enforcement perimeter** (per Q7). Everything the gate's verdict
     rests on — `gate.sh`, `check-stubs.sh`, `.gate-stubs-baseline`,
     `.gate-sha256`, `tooling/ci/`, the pipeline file, `.claude/` — lives inside
     the repository and can be changed in the same change request as the work it
     would excuse. Code ownership is the only trust anchor available that sits
     outside that perimeter. Worth doing solo: it makes the approval a timestamped
     act rather than an assumption.
     - **GitHub** — copy `tooling/ci/github/CODEOWNERS` to
       `<repo>/.github/CODEOWNERS`, replace the placeholders, and enable *Require
       review from Code Owners* in branch protection.
     - **GitLab** — copy `tooling/ci/gitlab/CODEOWNERS` to `<repo>/CODEOWNERS` and
       turn on *Require approval from Code Owners*. **Premium or Ultimate only.**
       On Free, read the fallback at the bottom of that file and pick one.
     - **Azure DevOps / Bitbucket** — there is no file to copy. Follow
       `tooling/ci/azure-devops/branch-policy.md` or
       `tooling/ci/bitbucket/default-reviewers.md`, and **delete the ownership
       entry from the manifest** rather than leaving it claiming a file that does
       not exist.
     Whichever applies, write the decision into `CLAUDE.md`. On the two platforms
     with no path-scoped ownership the perimeter is protected by portal settings
     that git cannot see, and an undocumented gap gets trusted past.
6. **Generate CLAUDE.md:**
   - Copy `CLAUDE.md.template` → `<project>/CLAUDE.md`, fill every `{{…}}`
     placeholder (including `{{SCOPE_TIER}}` and `{{TEAM_SIZE}}` from Q6 and Q5,
     and `{{FORGE}}` and `{{REVIEW_EVIDENCE_CMD}}` from Q7),
     delete sections your tier/answers exclude, and stamp the framework version
     from `VERSION`. `examples/minimal-node/CLAUDE.md` is a finished one to
     compare against.
7. **Record what you installed:**
   - Copy `tooling/claude/framework-manifest.template.json` →
     `<project>/.claude/framework-manifest.json`, fill the placeholders, and
     **delete every entry this project did not install** — a second stack it does
     not have, an optional layer-1 document it skipped, the `.ps1` gates on a
     POSIX-only team.
   - The template has **two** lists. `files[]` is installed once per project.
     `per_repo_files[]` is installed once per entry in `repos[]`: expand it per
     repo, replacing `{{REPO_DIR}}` with that repo's path and
     `{{REPO_STACK_FAMILY}}` with its gate family. A single-repo project expands
     it once. Do not collapse the two back into fixed backend/frontend slots —
     that is what left a third repo's gate with no manifest entry at all, so
     `/framework-upgrade` skipped it in silence.
   - This is the one record of where each installed file came from. The install
     *renames* most of what it copies (`stacks/nextjs-trpc/` → `docs/stacks/<frontend>/`,
     `tooling/gate/gate-node.sh` → `gate.sh`), and without this file
     `/framework-upgrade` cannot resolve those paths back upstream — it silently
     skips layer 2, the review templates, the gate scripts and CI, which is where
     all the editable content lives. Five minutes here is what makes the project
     upgradable at all.
8. **Spec scaffold:**
   - If using GitHub Spec Kit, run `specify init` and adopt its
     `specs/feature/NNN-<name>/` layout; copy `process/templates/` review checklists into
     `specs/_templates/`. Otherwise create `specs/` manually with the same shape.
9. **Verify the install:**
   - Run `/framework-doctor`. It checks the things that fail silently: unfilled
     `{{…}}` placeholders, a gate script that never runs, a package guard that
     does not block, a receipt that is not gitignored. Fix every FAIL before
     feature work — an install that half-works is the worst state to build on.
10. **Baseline commit:**
   - Commit everything as `chore: adopt sdlc-framework vX.Y.Z` before starting
     feature work, so the first `git diff --stat` against a feature is clean.

## After Setup — the Two Habits That Keep It Working

1. **Upstream-first:** any improvement to a layer-1/2 file gets ported back to the
   framework repo and `VERSION` bumped. Project copies never diverge silently.
2. **Layer discipline:** if you are about to write a product name into a
   `docs/process/` or `docs/stacks/*/` file — stop; it belongs in `docs/project/`.
