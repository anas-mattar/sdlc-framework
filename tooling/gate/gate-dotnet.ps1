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

$Solution    = "{{SOLUTION}}"       # e.g. wms-v3.sln
$TestProject = "{{TEST_PROJECT}}"   # e.g. WMS.API.Tests -- the authoritative test project

# --- receipt machinery (identical in every gate script -- do not let it diverge) ---
# Fingerprints the working tree, including uncommitted and untracked files, using a
# throwaway index so the developer's real index is untouched. The gate legitimately
# runs on a dirty tree (phase work is gated before it is committed), so freshness is
# content-based, not HEAD-based. The receipt itself is excluded so it never alters
# the fingerprint it is stored in.
#
# Process artifacts are excluded. These are written AROUND the gate, not built by
# it: phase/roadmap status and review output are produced by /phase-review and
# /phase-done, which necessarily run after the gate. Fingerprinting them would make
# the receipt go stale the moment a phase is written up. They are never build
# inputs. Everything else stays in -- including spec.md, plan.md and
# specs/*/contracts/, which CAN affect a build and must invalidate the receipt.
$ReceiptExcludes = @(
    ".gate-result.json",
    "specs/*/tasks.md",
    "specs/*/ai-code-review.md",
    "specs/*/human-pr-review.md",
    "docs/roadmap"
)

function Get-GateFingerprint {
    $idx = Join-Path ([IO.Path]::GetTempPath()) ("gate-index-" + [guid]::NewGuid().ToString('N'))
    $previous = $env:GIT_INDEX_FILE
    $env:GIT_INDEX_FILE = $idx
    git read-tree HEAD 2>$null | Out-Null
    git add -A 2>$null | Out-Null
    # -r is required: docs/roadmap is a directory, and without it git aborts the
    # whole call, silently applying NO exclusions at all.
    git rm --cached -q -r --ignore-unmatch @script:ReceiptExcludes 2>$null | Out-Null
    $tree = git write-tree 2>$null | Select-Object -First 1
    $env:GIT_INDEX_FILE = $previous
    Remove-Item $idx -Force -ErrorAction SilentlyContinue
    if (-not $tree) { return "unknown" }
    return $tree.Trim()
}

function Write-GateReceipt([int]$Code, [string]$Mode) {
    $tree = Get-GateFingerprint
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

dotnet build $Solution
$code = $LASTEXITCODE
if (-not $Min -and $code -eq 0) {
    dotnet test $TestProject
    $code = $LASTEXITCODE
}

Write-GateReceipt -Code $code -Mode $(if ($Min) { "min" } else { "full" })

Write-Host "EXIT: $code"
exit $code
