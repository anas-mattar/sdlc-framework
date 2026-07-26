# /framework-doctor — check that this project's framework install is intact

Run after setup, after `/framework-upgrade`, and any time the framework seems not
to be doing its job. Every check is mechanical: run the command, report what you
observe, do not infer.

The failure this exists to catch is **silent half-adoption** — the docs land, the
tooling doesn't, and nobody notices because prose does not announce that it stopped
being enforced (`ADOPTION.md` → *Anti-Patterns*).

## Checks

Report each as PASS / FAIL / N/A with the evidence that decided it.

### 1. Version stamped

`CLAUDE.md` contains a `Framework: sdlc-framework vX.Y.Z` line. Without it,
`/framework-upgrade` cannot tell what to upgrade from.

### 1a. Scope tier and team size recorded

`CLAUDE.md` contains a `Scope tier:` line (`Small` / `Medium` / `Large`) and a
`Developers:` line (`solo` / `team`). `process/project-rules.md`,
`process/definition-of-done.md`, and `/phase-done` all read these to decide which
spec artifacts a feature requires and whether human review means peer review or
the developer's own acceptance review. Missing or unfilled is a FAIL: the rules
then have no way to resolve, and every check falls back to the strictest reading.

### 2. No unfilled placeholders

Search `CLAUDE.md` and every gate script for `{{`:

```sh
grep -rn "{{" CLAUDE.md gate.ps1 gate.sh 2>/dev/null
```

Any hit is a FAIL — `{{SOLUTION}}` and `{{TEST_PROJECT}}` in a gate script are the
usual survivors, and they make the gate silently meaningless.

### 3. Gate script present and runnable per repo

Each repo root has `gate.ps1` and/or `gate.sh`. Multi-repo projects: check every
sub-repo, not just the wrapper. Run `./gate.ps1 -Verify` (or `./gate.sh --verify`)
and report what it prints — `RECEIPT: missing` is fine here and simply means the
gate has not been run yet; a *parse error* or "command not found" is a FAIL.

### 4. Receipt is gitignored

```sh
git check-ignore -q .gate-result.json && echo ignored || echo NOT-ignored
```

A committed receipt is one that can be forged in a pull request.

### 5. Both package guards actually block

Run the self-test from the project root:

```
powershell -NoProfile -File .claude/hooks/verify-guard.ps1
```
(or `sh .claude/hooks/verify-guard.sh` on macOS/Linux)

Only `GUARD: verified` is a PASS, and it now covers **two** hooks: the file guard
on `Edit|MultiEdit|Write|NotebookEdit`, and the install guard on `Bash`. A project
upgraded from before v2.3.0 will most often fail here with *no PreToolUse hook
matches Bash* — the file guard alone never sees `npm i`, `dotnet add package`,
`pip install` or `go get`, so every real way of adding a dependency is open. The
fix is a second `PreToolUse` entry running `guard-installs`.

The verifier also checks the **matcher**, not just the command. A hook pointed at
a tool that edits nothing (`"matcher": "Read"`) used to verify clean; it now
reports `GUARD: BROKEN`.

`INCONCLUSIVE` means `.claude/allow-package-changes` is present — report it as a
FAIL-to-verify and note that leaving that marker in place after a phase commits
disables the guard permanently.

### 6. CI gate present

`.github/workflows/gate.yml` exists, invokes the repo's own gate script, and has
no `continue-on-error`. Report whether the check is required on `main` as
**unverifiable locally** — the user must confirm it in branch protection. Applies
to solo projects too (`SETUP.md` Q5).

### 7. Installed layout matches the manifest

Read `.claude/framework-manifest.json` and check every `files[]` entry's
`installed` path actually exists. This is a real check rather than a guess: before
the manifest existed this step could only assert that a fixed list of directories
was present, and had no way to know which of the optional ones a given project was
supposed to have — so absence was always ambiguous and always reported N/A.

- **Manifest missing** — FAIL for any install stamped v2.3.0 or later; for an
  older one, report that `/framework-upgrade` will offer to reconstruct it. Say
  which, and do not treat a missing manifest as "nothing to check".
- **Entry present in the manifest, path absent on disk** — FAIL, naming the file.
  Something was deleted, or an upgrade was interrupted partway.
- **Path present on disk, absent from the manifest** — report it. Usually a stack
  or module installed later without recording it, which means every future upgrade
  will skip that file silently.
- **`stacks` values** — confirm each names a folder that exists in the framework
  repo when the user supplied its path. A stack recorded as `nextjs-trpc` that
  upstream no longer ships is an upgrade that will fail at Step 3.

Cross-check `scope_tier` and `developers` against the matching lines in
`CLAUDE.md`. They drive `process/project-rules.md`, `definition-of-done.md` and
`/phase-done`, and if the two records disagree, the rules being applied depend on
which file gets read first.

### 8. Layer discipline

Layer 3 content must not have leaked into layer 1/2. Scan `docs/process/` and
`docs/stack-*/` for this project's product, domain, and system names (take them
from `docs/project/domain-rules.md`). Any hit belongs in `docs/project/`.

Report findings as advisory rather than FAIL — this check is heuristic, and a
false positive should not block anyone.

### 9. Commands installed

`.claude/commands/` contains `phase-review.md`, `phase-done.md`, and — on team
projects — `claim-feature.md`.

## Verdict

- All PASS → "Framework install verified, vX.Y.Z."
- Otherwise → list the FAILs with the exact command that produced each, and the
  one-line fix. Do not soften a FAIL into a warning; an install that half-works is
  the condition this command exists to surface.
