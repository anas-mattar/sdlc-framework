# Setting Up a New Project

> **Existing project?** Read `ADOPTION.md` instead — it wraps these install
> steps in a brownfield path (baseline gate first, tribal-knowledge capture,
> compliance-as-you-touch, no spec backfilling).

Answer the 6 questions, then follow the install steps. Total time: ~15 minutes.
(You can also hand this file to Claude Code and say "set up this project with the
sdlc-framework at <path>" — it will interview you and do the steps.)

## The 6 Questions

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
`specs/<feature>/screenshots/` folder with provenance in `notes.md` — per the
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
skipping CI removes the last mechanical enforcement in the framework. Copy
`tooling/ci/gate.yml` and require the check on `main`. Two or more: it applies — roadmap
items carry an Owner column (one feature = one owner = one branch), spec numbers
are allocated via the claim commit or tracker issue IDs (pick one scheme, never
computed by scanning folders), CI runs the same gate scripts on every PR, human
review means reviewer ≠ owner, and shared surfaces are contract-first.
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
(`Developers:`). These two lines are not decoration: `process/project-rules.md`,
`process/definition-of-done.md`, and the `/phase-done` command all read them to
decide which artifacts a feature needs and what "human review" means here. An
unfilled tier line means every rule falls back to the strictest reading.

## Install Steps

1. **Copy layer 1 (always):**
   - `process/` → `<project>/docs/process/`
2. **Copy layer 2 (per Q1):**
   - `stacks/<backend>/` → `docs/stack-backend/`
   - `stacks/<frontend>/` → `docs/stack-frontend/`
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
   - Copy `tooling/claude/` content into `<project>/.claude/` (settings, hooks,
     and the `/claim-feature`, `/phase-review`, `/phase-done`,
     `/framework-doctor`, `/framework-upgrade` commands). Review the permissions
     allowlist. The hook command ships in its Windows form — on macOS/Linux swap
     it for `sh .claude/hooks/guard-packages.sh`.
   - **Prove the package guard actually blocks**: run
     `powershell -NoProfile -File .claude/hooks/verify-guard.ps1` (or
     `sh .claude/hooks/verify-guard.sh`) from the project root. It must print
     `GUARD: verified`. A misconfigured hook fails **open** — Claude Code treats
     an unrunnable hook as an error rather than a block — so an unverified guard
     is an absent guard.
   - Copy `tooling/ci/gate.yml` to `<repo>/.github/workflows/gate.yml`, uncomment
     your toolchain, and require the check on `main`. Do this on solo projects
     too (see Q5).
6. **Generate CLAUDE.md:**
   - Copy `CLAUDE.md.template` → `<project>/CLAUDE.md`, fill every `{{…}}`
     placeholder (including `{{SCOPE_TIER}}` and `{{TEAM_SIZE}}` from Q6 and Q5),
     delete sections your tier/answers exclude, and stamp the framework version
     from `VERSION`. `examples/minimal-node/CLAUDE.md` is a finished one to
     compare against.
7. **Spec scaffold:**
   - If using GitHub Spec Kit, run `specify init` and adopt its
     `specs/<feature>/` layout; copy `process/templates/` review checklists into
     `specs/_templates/`. Otherwise create `specs/` manually with the same shape.
8. **Verify the install:**
   - Run `/framework-doctor`. It checks the things that fail silently: unfilled
     `{{…}}` placeholders, a gate script that never runs, a package guard that
     does not block, a receipt that is not gitignored. Fix every FAIL before
     feature work — an install that half-works is the worst state to build on.
9. **Baseline commit:**
   - Commit everything as `chore: adopt sdlc-framework vX.Y.Z` before starting
     feature work, so the first `git diff --stat` against a feature is clean.

## After Setup — the Two Habits That Keep It Working

1. **Upstream-first:** any improvement to a layer-1/2 file gets ported back to the
   framework repo and `VERSION` bumped. Project copies never diverge silently.
2. **Layer discipline:** if you are about to write a product name into a
   `docs/process/` or `docs/stack-*/` file — stop; it belongs in `docs/project/`.
