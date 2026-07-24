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
specs/*/tasks.md           phase status
specs/*/ai-code-review.md  written by /phase-review
specs/*/human-pr-review.md written by the human reviewer
docs/roadmap/              feature status
```

These are process paperwork, written *around* the gate rather than built by it —
`/phase-review` and `/phase-done` necessarily run after the gate, so fingerprinting
their output would make a receipt go stale the instant a phase was written up. None
of them can change what compiles or what tests do.

The exclusion is deliberately narrow. `spec.md`, `plan.md`, and
`specs/*/contracts/` stay **in** the fingerprint: a contract can generate code, and
a changed spec means the gate verified something other than what was asked for.
`tests/receipt-contract.sh` asserts both directions — that paperwork does not
invalidate a receipt and that spec, plan, and contract changes do. Widening the
exclusion list breaks that test, which is the point.

> A receipt promises: *the code the gate compiled and tested is the code in front
> of you.* It does not promise the paperwork is unchanged.

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
