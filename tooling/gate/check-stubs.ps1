# Stub ratchet -- refuses to let unimplemented code grow.
#
#     ./check-stubs.ps1             check against the baseline
#     ./check-stubs.ps1 -Baseline   write the current count as the new baseline
#
# WHY THIS EXISTS. Nothing else in the framework requires the implementation to be
# REAL. The word "coverage" appears nowhere as a requirement, and the two review
# checkboxes that gesture at it do not close the gap: "tests accompany the behavior
# introduced in this phase" is a co-location predicate that an assertion-free test
# satisfies, and "no tests weakened, skipped, or deleted" constrains changes to
# EXISTING tests while saying nothing about the strength of new ones.
#
# So a phase can persist a value, leave an empty TODO block where the core
# invariant belongs, write three tests asserting a status code and the presence of
# a field, pass the build, earn a GENUINE valid receipt with no forgery involved,
# tick every box in the AI review, and reach "Done pending human review" -- with
# the feature's stated core invariant unimplemented.
#
# This is a ratchet, not a threshold. A brownfield repo may legitimately have two
# hundred TODOs on day one; demanding zero would be ignored within a week, and a
# rule that gets ignored trains people to ignore the others. What it forbids is the
# number going UP: this phase may not add unimplemented code.
#
# Keep this file ASCII-only. Windows PowerShell 5.1 reads UTF-8-without-BOM as ANSI,
# so a stray em dash becomes three bytes -- one of which is a quote -- and the script
# dies with "string is missing the terminator". Use `--`, never an em dash.
param([switch]$Baseline)

$BaselineFile = ".gate-stubs-baseline"

# Markers that mean "not implemented". `approved-stub:` on the same line exempts it,
# so a deliberate, reviewed placeholder is declared rather than hidden -- write
# `// approved-stub: spec.md section 4.2, deferred to phase 3` and it stops counting.
$Markers = 'TODO|FIXME|HACK|XXX|NotImplementedException|NotImplementedError|UnimplementedError|unimplemented!|todo!\(\)'

# Source files only. Tests are excluded because a TODO in a test is a note about a
# test, not shipped behaviour; docs and specs are excluded because prose about
# future work is the point of a roadmap. Vendored and generated trees are not ours.
function Test-IsSource([string]$Path) {
    $p = $Path -replace '\\', '/'
    # The checker itself names every marker it hunts for, in its own regex and its
    # own comments. Left in, it would count several of its own lines on a clean
    # repo -- a number nobody can explain and everybody learns to ignore.
    if ($p -match '(^|/)check-stubs\.(sh|ps1)$') { return $false }
    foreach ($x in @('node_modules/', '/vendor/', '/dist/', '/build/')) {
        if ($p -like "*$x*") { return $false }
    }
    if ($p -like 'vendor/*' -or $p -like 'dist/*' -or $p -like 'build/*') { return $false }
    if ($p -like 'docs/*' -or $p -like 'specs/*') { return $false }
    if ($p -match '\.(md|txt|json|yml|yaml|csv|svg|lock|sum)$') { return $false }
    if ($p -like '*.min.js') { return $false }
    if ($p -match '(^|/)[^/]*[Tt]est[^/]*$' -or $p -match '\.spec\.' -or $p -match '_test\.') { return $false }
    if ($p -match '(^|/)(tests?|__tests__|Tests)/') { return $false }
    return $true
}

function Get-StubLines {
    # Tracked files plus untracked-but-not-ignored ones: the gate runs on a dirty
    # tree, and a stub added in an uncommitted file is exactly what this catches.
    $files = @(git ls-files --cached --others --exclude-standard 2>$null)
    $hits = @()
    foreach ($f in $files) {
        if (-not (Test-IsSource $f)) { continue }
        if (-not (Test-Path -LiteralPath $f -PathType Leaf)) { continue }
        $m = Select-String -LiteralPath $f -Pattern $Markers -ErrorAction SilentlyContinue |
             Where-Object { $_.Line -notmatch 'approved-stub:' }
        if ($m) { $hits += $m }
    }
    return $hits
}

$hits = @(Get-StubLines)
$current = $hits.Count

if ($Baseline) {
    Set-Content -LiteralPath $BaselineFile -Value $current -NoNewline
    Write-Host "STUBS: baseline set to $current -- commit $BaselineFile."
    exit 0
}

if (-not (Test-Path $BaselineFile)) {
    # Fail closed, loudly, with the fix on screen. A control that quietly does
    # nothing when its configuration is absent is the failure mode this framework
    # exists to argue against -- and the fix is one command.
    Write-Host "STUBS: no $BaselineFile -- the stub ratchet has never been baselined."
    Write-Host "  Current count: $current. To adopt the ratchet as it stands, run:"
    Write-Host "    ./check-stubs.ps1 -Baseline"
    Write-Host "  and commit the file. Lower it deliberately as stubs are implemented."
    exit 1
}

$raw = (Get-Content $BaselineFile -Raw).Trim()
if ($raw -notmatch '^\d+$') {
    Write-Host "STUBS: $BaselineFile does not contain a number -- refusing to guess."
    exit 1
}
$baselineCount = [int]$raw

if ($current -gt $baselineCount) {
    Write-Host "STUBS: unimplemented markers rose to $current (baseline $baselineCount)."
    Write-Host "  This phase added code that says it is not finished. Implement it, or"
    Write-Host "  mark the line 'approved-stub: <where the spec defers it>' so the"
    Write-Host "  deferral is reviewable rather than invisible."
    Write-Host ""
    foreach ($h in $hits) {
        Write-Host ("  {0}:{1}:{2}" -f $h.Path, $h.LineNumber, $h.Line.Trim())
    }
    exit 1
}

if ($current -lt $baselineCount) {
    Write-Host "STUBS: $current (baseline $baselineCount) -- improved. Lower the baseline:"
    Write-Host "    ./check-stubs.ps1 -Baseline"
    exit 0
}

Write-Host "STUBS: $current (baseline $baselineCount)"
exit 0
