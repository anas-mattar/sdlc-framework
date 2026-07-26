# Gate script -- .NET backend. Copy to the backend repo root as `gate.ps1`,
# fill in SOLUTION and TEST_PROJECT. This file is the ONLY definition of the gate;
# docs and CLAUDE.md must point here, never restate the commands.
#
# Usage: ./gate.ps1          full gate (build + test)
#        ./gate.ps1 -Min     minimum gate (build only)
#        ./gate.ps1 -Verify  no build -- check the existing receipt is fresh and green
#
# On completion the gate writes `.gate-result.json` -- the receipt recording WHICH
# working tree passed. -Verify re-fingerprints the tree and reports whether the
# receipt still applies, so a stale pass cannot satisfy the Definition of Done.
# Add `.gate-result.json` to .gitignore: it is local evidence, never committed.
#
# Keep this file ASCII-only. Windows PowerShell 5.1 reads UTF-8-without-BOM as ANSI,
# so a stray em dash becomes three bytes -- one of which is a quote -- and the script
# dies with "string is missing the terminator". Use `--`, never an em dash.
param([switch]$Min, [switch]$Verify)

$Solution    = "{{SOLUTION}}"       # e.g. app.sln
$TestProject = "{{TEST_PROJECT}}"   # e.g. App.API.Tests -- the authoritative test project

$Steps = @(
    @("dotnet", "build", $Solution),
    @("dotnet", "test", $TestProject)
)

# --- receipt machinery (identical in every gate script -- do not let it diverge) ---
# Fingerprints the working tree, including uncommitted and untracked files, using a
# throwaway index so the developer's real index is untouched. The gate legitimately
# runs on a dirty tree (phase work is gated before it is committed), so freshness is
# content-based, not HEAD-based. The receipt itself is excluded so it never alters
# the fingerprint it is stored in.
#
# Process artifacts are excluded -- but only the ones carrying STATUS, never the
# ones carrying requirements. /phase-review and /phase-done necessarily run after
# the gate, so fingerprinting their output would make a receipt go stale the moment
# a phase is written up. Status therefore lives in files of its own:
#
#   specs/<feature>/status.md   phase progress
#   docs/roadmap/status.md      delivery board
#
# NOT tasks.md, and NOT the roadmap itself. Those define what the work IS -- the
# task list is the requirement for the phase, the roadmap owns scope and
# sequencing. If they were excluded, requirements could be rewritten after the
# gate to match whatever was built, and the receipt would still report valid.
#
# Everything else stays in, including spec.md, plan.md, tasks.md, the roadmap
# definitions, and specs/*/contracts/.
$ReceiptExcludes = @(
    ".gate-result.json",
    "specs/*/status.md",
    "specs/*/ai-code-review.md",
    "specs/*/human-pr-review.md",
    "docs/roadmap/status.md"
)

function Get-GateFingerprint {
    $idx = Join-Path ([IO.Path]::GetTempPath()) ("gate-index-" + [guid]::NewGuid().ToString('N'))
    $previous = $env:GIT_INDEX_FILE
    $env:GIT_INDEX_FILE = $idx
    git read-tree HEAD 2>$null | Out-Null
    git add -A 2>$null | Out-Null
    # -r is kept even though every pattern now names a file: if any pattern ever
    # resolves to a directory, git aborts the WHOLE call without it, silently
    # applying no exclusions at all.
    git rm --cached -q -r --ignore-unmatch @script:ReceiptExcludes 2>$null | Out-Null
    $tree = git write-tree 2>$null | Select-Object -First 1
    $env:GIT_INDEX_FILE = $previous
    Remove-Item $idx -Force -ErrorAction SilentlyContinue
    if (-not $tree) { return "unknown" }
    return $tree.Trim()
}

function Write-GateReceipt([int]$Code, [string]$Mode) {
    $tree = Get-GateFingerprint
    # A receipt naming a tree that could not be read is not evidence -- it is a
    # permanently-valid pass, because "unknown" -eq "unknown" on every later
    # -Verify. Refuse to write one, and fail the gate.
    if ($tree -eq "unknown") {
        Write-Host "GATE: the working tree could not be fingerprinted -- no receipt written."
        Write-Host "  Run 'git status': 'detected dubious ownership' is the usual cause in Docker, WSL and CI containers."
        Write-Host "EXIT: 1"
        exit 1
    }
    $head = git rev-parse HEAD 2>$null | Select-Object -First 1
    if (-not $head) { $head = "unknown" }
    $utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $json = @"
{
  "exit": $Code,
  "mode": "$Mode",
  "tree": "$($tree.Trim())",
  "head": "$($head.Trim())",
  "utc": "$utc"
}
"@
    $path = Join-Path (Get-Location).Path ".gate-result.json"
    [IO.File]::WriteAllText($path, $json, (New-Object System.Text.UTF8Encoding($false)))

    git check-ignore -q .gate-result.json 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "WARNING: add .gate-result.json to .gitignore -- the receipt is local evidence, never committed."
    }
}

if ($Verify) {
    if (-not (Test-Path ".gate-result.json")) { Write-Host "RECEIPT: missing -- run ./gate.ps1"; exit 1 }
    $r = Get-Content ".gate-result.json" -Raw | ConvertFrom-Json
    $current = Get-GateFingerprint
    # Fail closed on an unfingerprintable tree -- see the note in Write-GateReceipt.
    # An unverifiable tree is a failure, never a pass.
    if ($current -eq "unknown" -or $r.tree -eq "unknown") {
        Write-Host "RECEIPT: unverifiable -- the working tree could not be fingerprinted."
        Write-Host "  Run 'git status': 'detected dubious ownership' is the usual cause in Docker, WSL and CI containers."
        exit 1
    }
    if ($r.tree -ne $current) {
        Write-Host "RECEIPT: stale -- the working tree changed after the gate ran; re-run ./gate.ps1"; exit 1
    }
    if ($r.mode -ne "full") {
        Write-Host "RECEIPT: min -- only the minimum gate ran; a full gate is required"; exit 1
    }
    if ($r.exit -ne 0) {
        Write-Host "RECEIPT: failed -- recorded EXIT: $($r.exit)"; exit 1
    }
    Write-Host "RECEIPT: valid -- full gate, EXIT: 0, tree $current"
    Write-Host "  not fingerprinted (process artifacts, never build inputs): $($ReceiptExcludes -join ' ')"
    exit 0
}

if ($Min) { $Steps = @(, $Steps[0]) }

# PowerShell flattens @( @("dotnet", "build") ) to @("dotnet", "build"), so a
# project that trims its gate to ONE step gets an array of strings rather than an
# array of steps -- and the loop below would iterate over the characters of its own
# command name and report 127. If the first element is a string, the whole list is
# one step. (The -Min line above already uses the unary comma for the same reason.)
if ($Steps.Count -gt 0 -and $Steps[0] -is [string]) { $Steps = @(, $Steps) }

# --- step runner (identical in both .ps1 gates -- do not let it diverge) ---
# $LASTEXITCODE is set ONLY by a native executable. If `dotnet` cannot be resolved,
# PowerShell raises a CommandNotFoundException, the loop carries on, and
# $LASTEXITCODE is still $null. $null -ne 0 is true so it breaks; [int]$null is 0;
# and `exit $null` exits 0. A gate that ran no steps at all then reports EXIT: 0
# and writes a receipt that -Verify calls valid -- the primary control failing
# OPEN, silently, on the platform settings.json treats as primary. So: reset
# before every step, catch the exception, and treat "no exit code" as 127.
#
# A step that resolves to a cmdlet or function rather than a native executable
# also leaves $LASTEXITCODE $null and is therefore reported as 127. That is
# deliberate -- the gate runs build tools, and guessing is what got us here.
foreach ($step in $Steps) {
    $global:LASTEXITCODE = $null
    try {
        & $step[0] $step[1..($step.Length - 1)]
    } catch {
        Write-Host "GATE: cannot run '$($step[0])' -- $($_.Exception.Message)"
        $global:LASTEXITCODE = 127
    }
    if ($null -eq $LASTEXITCODE) {
        Write-Host "GATE: '$($step[0])' produced no exit code -- treating as failure. Is it installed and on PATH?"
        $global:LASTEXITCODE = 127
    }
    if ($LASTEXITCODE -ne 0) { break }
}
$code = $LASTEXITCODE

Write-GateReceipt -Code $code -Mode $(if ($Min) { "min" } else { "full" })

Write-Host "EXIT: $code"
exit $code
