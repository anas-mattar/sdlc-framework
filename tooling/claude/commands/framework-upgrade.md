# /framework-upgrade — move this project to a newer framework version

Usage: `/framework-upgrade <path-to-sdlc-framework-repo>`

Consuming projects hold **copies** of the framework's layer 1/2 docs and tooling.
Copies drift. This command reports exactly what changed upstream, what this project
must re-copy, and — crucially — **which local edits an upgrade would destroy**,
then stops for approval before touching anything.

> Never run this in the middle of feature work. An upgrade bundled into a feature
> branch violates single-phase scope and makes `git diff --stat` useless.

## Step 1 — refuse unless it is safe to proceed

Stop and report if any of these is true:

- The working tree is dirty (`git status --porcelain` is non-empty). An upgrade is
  its own change, on its own branch.
- The path argument is missing or is not a git repo containing `VERSION` and
  `CHANGELOG.md`.

## Step 2 — read the install manifest, and establish the version delta

`.claude/framework-manifest.json` records what this project installed and where
each file came from. Read it first: every later step depends on it.

- **Missing manifest** — the install predates v2.3.0. Say so and offer to
  reconstruct one from `tooling/claude/framework-manifest.template.json` by
  inspecting the project (which stack folders exist, which repos have a `gate.sh`,
  which optional modules are present). Get the user to confirm the reconstruction
  *before* using it, and write it out as its own commit. Do not proceed on a guessed
  manifest — a wrong `upstream` path silently upgrades a file from the wrong source.

  **The template describes the CURRENT layout, so do not copy its `installed` paths
  onto an older install.** It says `docs/stacks/<name>/`; a pre-2.3.0 project has
  `docs/stack-backend/` and `docs/stack-frontend/`. It lists
  `<repo>/tooling/ci/gate-ci.sh` and a per-platform wrapper; a pre-2.3.0 project has
  `.github/workflows/gate.yml` and no `gate-ci.sh` at all. Reconstructing straight
  from the template therefore produces wrong `installed` paths for **exactly the
  files a breaking rename moved** — the ones the drift check most needs to read.
  Read the *installed* side off the project's disk and the *upstream* side out of
  that version's own `SETUP.md`, which records the mapping as it was. For 2.2.0:

  | Upstream at v2.2.0 | Installed at v2.2.0 | Where 2.3.0 moved it |
  |---|---|---|
  | `process/` (flat) | `docs/process/` | bucketed into `core/`, `team/`, `optional/` — same flat install target |
  | `stacks/<backend>/` | `docs/stack-backend/` | `docs/stacks/<name>/` |
  | `stacks/<frontend>/` | `docs/stack-frontend/` | `docs/stacks/<name>/` |
  | the single gate.yml under tooling/ci/ | `.github/workflows/gate.yml` | `tooling/ci/<platform>/` wrapper + `tooling/ci/gate-ci.sh`, per repo |
  | *(did not exist)* | — | `check-stubs.{sh,ps1}`, `guard-installs.{sh,ps1}`, `CODEOWNERS`, `.gate-sha256`, `.gate-stubs-baseline`, `process/core/exceptions.md` |
  | a feature folder directly under specs/ | the same | `specs/feature/NNN-<name>/` — a one-time `git mv` per feature |

  The two left-hand cells in the last two rows are deliberately not written as
  backticked path patterns. The suite scans shipped documents for the pre-2.3.0
  spec layout and for file references that no longer resolve, and a migration table
  has to *name* what it is migrating from — so writing those forms literally here
  would trip both checks. Weakening a check to accommodate the prose describing it
  is the trade this framework exists to refuse.
- **Current version:** `framework_version` in the manifest, cross-checked against
  the `Framework: sdlc-framework vX.Y.Z` line in `CLAUDE.md`. If the two disagree,
  stop and report — one of them was updated by hand and you cannot tell which is
  right.
- **Available:** `cat <framework>/VERSION`.
- Equal → report "already current" and stop.
- Current is *newer* than upstream → the project diverged or the framework repo is
  stale. Report it; do not "upgrade" backwards.
- **Tag preflight:** confirm `git -C <framework> rev-parse v<CURRENT>` resolves.
  Step 3 diffs against that tag, and a missing tag makes every file look identical
  to itself — the upgrade would report no drift at all and quietly overwrite real
  local edits. If the tag is absent, stop: the framework repo needs
  `git push --tags`, or the release was never tagged.

## Step 3 — detect local drift BEFORE proposing anything

This is the step that earns the command. Walk **`files[]` and `per_repo_files[]`
from the manifest** — not a hardcoded list of directories. `per_repo_files[]`
entries are expanded once per entry in `repos[]`, substituting `{{REPO_DIR}}` with
that repo's path and `{{REPO_STACK_FAMILY}}` with its gate family; walking only
`files[]` leaves every repo's gate and stub ratchet unexamined, which is the
silent skip this manifest exists to end. For each entry, compare the installed path against
its `upstream` path **as it was at the recorded version**, not against the new
version, which would flag every legitimate upstream change as local drift:

```sh
rm -rf /tmp/up && mkdir -p /tmp/up
git -C <framework> archive v<CURRENT> <entry.upstream> | tar x -C /tmp/up
diff -r --strip-trailing-cr /tmp/up/<entry.upstream> <entry.installed>
```

**`git archive`, not `git show`, and `diff -r`.** Eight of the manifest's twenty-two
entries are DIRECTORIES — `process/core/`, `process/templates/`, both
`stacks/<name>/`, `modules/contracts/`, `tooling/claude/commands/`,
`tooling/claude/hooks/`, `tooling/project-docs/` — which is to say all of layer 2,
the hooks, the slash commands and the layer-3 skeletons. `git show v2.2.0:process/`
does not print those files; it prints a *tree listing*:

```
tree v2.2.0:process/

branch-strategy.md
definition-of-done.md
...
```

`diff` then compares that listing against a directory and exits 2 with
`diff: docs/process/uo: No such file or directory`. It fails loudly rather than
reporting false agreement, which is the only reason this was a nuisance and not a
silent hole — but the step that earns this command had no working recipe for 36% of
the manifest, including every directory where the editable content actually lives.
`git archive | tar x` writes real files for a path of either kind, so one recipe
covers both.

**`--strip-trailing-cr` is not optional.** `git show` emits LF; a Windows working
copy has CRLF. Without it every single file reports as drifted and the check is
worse than useless — it trains you to ignore it. (`git diff --no-index
--ignore-cr-at-eol` works equally well if you prefer.)

Before the manifest existed this step covered `docs/process/` and `.claude/` and
silently skipped everything else, because those were the only paths whose mapping
was 1:1. Layer 2, the review templates, the gate scripts and CI — all renamed by
the install, all where the editable content actually lives — went unchecked. If an
entry's `upstream` path does not resolve at that tag, **report it rather than
skipping it**: either the file is new since that version, or the manifest is wrong,
and both need saying out loud.

What drift means depends on `class`:

- **`copy`** — a layer 1/2 doc the project is not allowed to edit. Any difference
  is a finding. The user chooses:
  1. **Port it upstream first** — the correct answer if the edit is a genuine
     improvement. Stop the upgrade, make the change in the framework repo, bump its
     `VERSION`, then re-run.
  2. **Discard it** — the edit was project-specific and belongs in `docs/project/`
     (layer 3). Move the content there, then let the upgrade overwrite.
  3. **Keep it in a preserved region** — see below. This is the right answer for
     the handful of layer-1 docs that ship `{{PLACEHOLDER}}`s a project *must*
     fill (`repository-strategy.md`, `branch-strategy.md`,
     `deployment-standards.md`). Before this option existed the contract was
     contradictory: fill them and the next upgrade reverts them, leave them and
     layer 1 ships broken text.
- **`merge`** — expected to differ; the project edited it at install. Do not report
  it as drift. Quote the upstream change for the user to apply by hand.
- **`local`** — generated from a template and owned by the project. Report upstream
  template changes as informational; never touch the file.

Never silently overwrite a drifted file.

### Preserved regions

A `copy`-class document may carry exactly one region that an upgrade must not
overwrite:

```markdown
<!-- LOCAL: preserved by /framework-upgrade -->
...project-specific content, including filled placeholders...
<!-- /LOCAL -->
```

When replacing a `copy` file, extract this region from the installed copy and
re-insert it into the new upstream version at the same marker. If the new upstream
version has no markers, stop and ask — do not drop the content. Content outside the
markers is replaced without asking, which is the point: the region is a narrow,
declared exception to layer discipline, not a general licence to edit.

## Step 4 — walk the CHANGELOG

Read `<framework>/CHANGELOG.md` and collect every entry between the current
version (exclusive) and the available version (inclusive). Present them in order,
newest last, and consolidate their upgrade actions into one list grouped by the
CHANGELOG's own action types:

- **Copy** / **Install** — propose the file operations explicitly, source → target.
- **Merge** — list these separately and **never automate them**. These are files
  the project edited at install: `CLAUDE.md` (filled placeholders) and the gate
  scripts (project build/test commands). For each, quote the specific upstream
  change to apply by hand.
- **Action** — one-off steps (gitignore entries, running `verify-guard`, enabling a
  CI check). List them as a checklist for the user.
- **None** — do not mention beyond a count.

Call out any entry marked **Breaking** prominently, with its consequence.

## Step 5 — apply, then verify

After the user approves:

1. Perform the Copy/Install operations, honouring preserved regions.
2. Report the Merge and Action items again as remaining manual work — the upgrade
   is **not** complete until the user confirms them.
3. Update **both** version records: `framework_version` in
   `.claude/framework-manifest.json` and the `Framework: sdlc-framework vX.Y.Z`
   line in `CLAUDE.md`. Add `files[]` (or `per_repo_files[]`) entries for anything newly installed, and
   remove entries for anything the new version deleted — a manifest that is stale
   is worse than none, because the next upgrade trusts it.
4. Run `/framework-doctor` and report its output.
5. Ask the user to run the full gate and confirm `RECEIPT: valid` before
   committing — an upgrade that breaks the build must not land.

Commit as `chore: upgrade sdlc-framework to vX.Y.Z`, on its own branch, nothing
else bundled in.

## Verdict

- Report what was copied, what still needs merging by hand, and what the user must
  do. Do not describe the upgrade as complete while Merge or Action items remain
  outstanding — say exactly which ones are pending.
