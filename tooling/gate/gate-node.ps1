# Gate script — Node/Next.js frontend. Copy to the frontend repo root as `gate.ps1`.
# Adjust the STEPS list to the project's package.json scripts. This file is the ONLY
# definition of the gate; docs and CLAUDE.md must point here, never restate commands.
#
# If the project pins yarn via `packageManager`, run `corepack enable` once first.
#
# Usage: ./gate.ps1          full gate
#        ./gate.ps1 -Min     minimum gate (build only)
param([switch]$Min)

$Steps = @(
    @("yarn", "build"),
    @("yarn", "check"),   # lint + typecheck — replace with the project's scripts
    @("yarn", "test")
)
if ($Min) { $Steps = @(, $Steps[0]) }

foreach ($step in $Steps) {
    & $step[0] $step[1..($step.Length - 1)]
    if ($LASTEXITCODE -ne 0) { break }
}

Write-Host "EXIT: $LASTEXITCODE"
exit $LASTEXITCODE
