# Gate script — .NET backend. Copy to the backend repo root as `gate.ps1`,
# fill in SOLUTION and TEST_PROJECT. This file is the ONLY definition of the gate;
# docs and CLAUDE.md must point here, never restate the commands.
#
# Usage: ./gate.ps1          full gate (build + test)
#        ./gate.ps1 -Min     minimum gate (build only)
param([switch]$Min)

$Solution    = "{{SOLUTION}}"       # e.g. wms-v3.sln
$TestProject = "{{TEST_PROJECT}}"   # e.g. WMS.API.Tests — the authoritative test project

dotnet build $Solution
if (-not $Min -and $LASTEXITCODE -eq 0) {
    dotnet test $TestProject
}

Write-Host "EXIT: $LASTEXITCODE"
exit $LASTEXITCODE
