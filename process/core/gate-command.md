# Gate Command

The gate for each repository is a script at that repository's root: `gate.ps1`
(PowerShell) or `gate.sh` (bash/zsh). The scripts come from the framework's
`tooling/gate/` templates; each runs the full verification chain and prints
`EXIT: <code>` when it finishes.

## Contract

1. The **user** runs the gate locally: `./gate.ps1` or `./gate.sh`.
2. The gate writes a **receipt** — `.gate-result.json` — recording the exit code,
   the mode (`full`/`min`), and a fingerprint of the exact working tree that was
   verified.
3. AI MUST NOT claim success without a **valid receipt**: `./gate.ps1 -Verify`
   (or `./gate.sh --verify`) printing `RECEIPT: valid`.

## The Receipt

The receipt exists because the gate is the framework's central control and prose
cannot enforce it. A pasted `EXIT: 0` line proves nothing: it can be fabricated,
skimmed past, or copied from a run that predates the code being reviewed.

`-Verify` re-fingerprints the working tree and compares it to the receipt. It runs
**no build** — it only inspects evidence, so an AI may run it freely. It reports:

| Output | Meaning |
|---|---|
| `RECEIPT: valid` | Full gate, `EXIT: 0`, and the tree is unchanged since it ran |
| `RECEIPT: stale` | The tree changed after the gate ran — re-run the gate |
| `RECEIPT: min` | Only the minimum gate ran — a full gate is required |
| `RECEIPT: failed` | The recorded exit code was non-zero |
| `RECEIPT: missing` | The gate has not been run in this repo |

The fingerprint covers uncommitted **and** untracked files, because the gate
legitimately runs on a dirty tree — phase work is gated *before* it is committed.
It is computed against a throwaway git index, so the developer's staged changes
are never disturbed.

### What the fingerprint excludes, and why

Five paths are deliberately outside the fingerprint:

```
.gate-result.json          the receipt itself
specs/*/status.md          phase progress, written by /phase-done
specs/*/ai-code-review.md  written by /phase-review
specs/*/human-pr-review.md written by the human reviewer
docs/roadmap/status.md     the delivery board
```

These are written *around* the gate rather than built by it — `/phase-review` and
`/phase-done` necessarily run after the gate, so fingerprinting their output would
make a receipt go stale the instant a phase was written up.

**The line is status versus requirements, not paperwork versus code.** Everything
that defines *what the work is* stays in the fingerprint, including files that are
themselves process artifacts:

| In the fingerprint | Why |
|---|---|
| `spec.md`, `plan.md` | A changed spec means the gate verified something other than what was asked for |
| `tasks.md` | It defines what each phase must do. If it were excluded, a phase's requirements could be rewritten after the gate to match whatever was built, and the receipt would still read `valid` |
| `docs/roadmap/` (except `status.md`) | The roadmap owns scope and sequencing — descoping an item after the gate is a change to the delivery record, not a status tick |
| `specs/*/contracts/` | A contract can generate code |

This is why status lives in its own file rather than as ticks inside `tasks.md`.
Mixing mutable status into a requirements document forces a choice between a
receipt that goes stale on every status update and an exclusion that hides
requirement changes. Separating them costs one small file and removes the choice.

`tests/receipt-contract.sh` asserts both directions — that status does not
invalidate a receipt, and that `spec.md`, `plan.md`, `tasks.md`, roadmap
definitions, and contracts do. `tests/framework-checks.sh` additionally fails the
build if any gate script excludes a whole requirements artifact, or if the four
gate scripts stop agreeing on the list.

> A receipt promises: *the code the gate compiled and tested is the code in front
> of you, and the requirements it was measured against have not moved since.* It
> does not promise the status boards are unchanged.

Add `.gate-result.json` to `.gitignore`. The receipt is local evidence of a local
run; a committed receipt is a receipt someone can forge in a pull request. CI does
not read receipts — it runs the gate itself (`docs/process/team-workflow.md` §3).

> The receipt records *that a verification happened and on what*. Trusting the
> user to run the gate is deliberate; trusting a transcribed number is not.

## Minimum Gate

For a fast build-only check, use the minimum variant: `./gate.ps1 -Min` or
`./gate.sh --min`. The full gate is still required before a phase is Done, and a
`min` receipt never satisfies the Definition of Done.

> The gate scripts are the **only** place gate commands are defined. Documentation
> and `CLAUDE.md` must point to the scripts — never restate the command chains.
