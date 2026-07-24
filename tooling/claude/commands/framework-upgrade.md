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

## Step 2 — establish the version delta

- **Current:** read `Framework: sdlc-framework vX.Y.Z` from this project's
  `CLAUDE.md`. If that line is missing, the install predates version stamping —
  say so and ask the user which version they installed; do not guess.
- **Available:** `cat <framework>/VERSION`.
- Equal → report "already current" and stop.
- Current is *newer* than upstream → the project diverged or the framework repo is
  stale. Report it; do not "upgrade" backwards.

## Step 3 — detect local drift BEFORE proposing anything

This is the step that earns the command. For every installed layer 1/2 file,
compare the project's copy against the upstream file **as it was at the recorded
version** — not against the new version, which would flag every legitimate change
as drift:

```sh
git -C <framework> show v<CURRENT>:process/<file>.md > /tmp/upstream-orig.md
diff --strip-trailing-cr /tmp/upstream-orig.md docs/process/<file>.md
```

**`--strip-trailing-cr` is not optional.** `git show` emits LF; a Windows working
copy has CRLF. Without it every single file reports as drifted and the check is
worse than useless — it trains you to ignore it. (`git diff --no-index
--ignore-cr-at-eol` works equally well if you prefer.)

Cover `docs/process/`, `docs/stack-*/`, `docs/contracts/`, `.claude/commands/`,
and `.claude/hooks/`. Any difference means someone edited a layer 1/2 file locally,
which the upstream-first rule forbids (`README.md` → *Versioning & Upstream-First
Rule*).

Report drift as its own section, per file. For each, the user chooses:

1. **Port it upstream first** — the correct answer if the edit is a genuine
   improvement. Stop the upgrade, make the change in the framework repo, bump its
   `VERSION`, then re-run.
2. **Discard it** — the edit was project-specific and belongs in `docs/project/`
   (layer 3). Move the content there, then let the upgrade overwrite.

Never silently overwrite a drifted file.

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

1. Perform the Copy/Install operations.
2. Report the Merge and Action items again as remaining manual work — the upgrade
   is **not** complete until the user confirms them.
3. Update the `Framework: sdlc-framework vX.Y.Z` line in `CLAUDE.md`.
4. Run `/framework-doctor` and report its output.
5. Ask the user to run the full gate and confirm `RECEIPT: valid` before
   committing — an upgrade that breaks the build must not land.

Commit as `chore: upgrade sdlc-framework to vX.Y.Z`, on its own branch, nothing
else bundled in.

## Verdict

- Report what was copied, what still needs merging by hand, and what the user must
  do. Do not describe the upgrade as complete while Merge or Action items remain
  outstanding — say exactly which ones are pending.
