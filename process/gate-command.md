# Gate Command

The gate for each repository is a script at that repository's root: `gate.ps1`
(PowerShell) or `gate.sh` (bash/zsh). The scripts come from the framework's
`tooling/gate/` templates; each runs the full verification chain and prints
`EXIT: <code>` when it finishes.

## Contract

1. The **user** runs the gate locally: `./gate.ps1` or `./gate.sh`.
2. The user reports the printed `EXIT: <code>` line. A passing gate is `EXIT: 0`.
3. AI MUST NOT claim success without a user-reported `EXIT: 0`.

## Minimum Gate

For a fast build-only check, use the minimum variant: `./gate.ps1 -Min` or
`./gate.sh --min`. The full gate is still required before a phase is Done.

> The gate scripts are the **only** place gate commands are defined. Documentation
> and `CLAUDE.md` must point to the scripts — never restate the command chains.
