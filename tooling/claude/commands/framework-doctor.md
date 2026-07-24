# /framework-doctor — check that this project's framework install is intact

Run after setup, after `/framework-upgrade`, and any time the framework seems not
to be doing its job. Every check is mechanical: run the command, report what you
observe, do not infer.

The failure this exists to catch is **silent half-adoption** — the docs land, the
tooling doesn't, and nobody notices because prose does not announce that it stopped
being enforced (`docs/process/../ADOPTION.md` → *Anti-Patterns*).

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

### 5. Package guard actually blocks

Run the self-test from the project root:

```
powershell -NoProfile -File .claude/hooks/verify-guard.ps1
```
(or `sh .claude/hooks/verify-guard.sh` on macOS/Linux)

Only `GUARD: verified` is a PASS. `INCONCLUSIVE` means
`.claude/allow-package-changes` is present — report it as a FAIL-to-verify and
note that leaving that marker in place after a phase commits disables the guard
permanently.

### 6. CI gate present

`.github/workflows/gate.yml` exists, invokes the repo's own gate script, and has
no `continue-on-error`. Report whether the check is required on `main` as
**unverifiable locally** — the user must confirm it in branch protection. Applies
to solo projects too (`SETUP.md` Q5).

### 7. Installed layout

These exist: `docs/process/`, `docs/project/`, `specs/`, `.claude/commands/`,
`.claude/hooks/`. Report `docs/stack-*/`, `docs/contracts/`, `docs/business/`,
`docs/prototypes/`, `docs/roadmap/` as N/A when the project's tier or setup answers
excluded them — absence is only a FAIL if something references them.

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
