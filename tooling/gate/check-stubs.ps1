# Stub ratchet -- refuses to let unimplemented code grow.
#
#     ./check-stubs.ps1              check against the baseline
#     ./check-stubs.ps1 -Baseline    write the current count as the new baseline
#     ./check-stubs.ps1 -Count       print the count and nothing else
#     ./check-stubs.ps1 -Classify a,b  print `source`/`skip` per path
#
# The last two exist so tests/framework-checks.sh can compare this script's answers
# against check-stubs.sh's on the same inputs. The two implementations used to be
# compared by diffing their MARKER STRINGS, which passed while they returned
# different counts on the same tree: Select-String and -notmatch are
# case-INSENSITIVE by default, so `// todo: later` counted here and not on macOS,
# and the two file filters disagreed about any path with `test` in a directory
# name. A rule implemented twice needs its ANSWERS compared, not its constants.
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
param([switch]$Baseline, [switch]$Count, [string[]]$Classify, [string[]]$Scan)

$BaselineFile = ".gate-stubs-baseline"

# Markers that mean "not implemented". `approved-stub: <reason>` on the same line
# exempts it, so a deliberate, reviewed placeholder is declared rather than hidden.
$Markers = 'TODO|FIXME|HACK|XXX|NotImplementedException|NotImplementedError|UnimplementedError|unimplemented!|todo!\(\)'

# The exemption needs a REASON after the colon. `// TODO: everything
# approved-stub:` was accepted for three releases and exempted the line while
# saying nothing at all -- an escape hatch whose entire cost was typing eleven
# characters is not an escape hatch, it is a delete key with extra steps.
$Exempt = 'approved-stub:\s*\S'

# Source files only. Tests are excluded because a TODO in a test is a note about a
# test, not shipped behaviour; docs and specs are excluded because prose about
# future work is the point of a roadmap. Vendored and generated trees are not ours.
#
# Every rule below is duplicated, EXACTLY, in check-stubs.sh's is_source, and
# tests/framework-checks.sh feeds both the same path list and diffs the answers.
# The previous pair did not agree: the .sh matched `*[Tt]est*` against the WHOLE
# path and this one matched it against the filename only, so `src/latest/run.ts`
# was source here and not there.
#
# The case-sensitivity of each rule is deliberate and matched to the .sh:
# extensions are case-INSENSITIVE (`-match`), everything else is case-SENSITIVE
# (`-cmatch`, `-clike`, `-ceq`, and .NET's ordinal `.Contains`).
function Test-IsSource([string]$Path) {
    $p = ($Path -replace '\\', '/').TrimEnd('/')
    $b = $p.Substring($p.LastIndexOf('/') + 1)
    # The checker itself names every marker it hunts for, in its own regex and its
    # own comments. Left in, it would count several of its own lines on a clean
    # repo -- a number nobody can explain and everybody learns to ignore.
    if ($b -ceq 'check-stubs.sh' -or $b -ceq 'check-stubs.ps1') { return $false }
    if ($b -match '\.(md|txt|json|yml|yaml|csv|svg|lock|sum)$') { return $false }
    if ($b -clike '*.min.js') { return $false }
    if ($b -cmatch '[Tt]est') { return $false }
    if ($b -cmatch '[Ss]pec\.') { return $false }
    $segments = '/' + $p
    foreach ($d in @('node_modules', 'vendor', 'dist', 'build',
                     'test', 'tests', 'Test', 'Tests', '__tests__', 'spec', 'specs')) {
        if ($segments.Contains("/$d/")) { return $false }
    }
    if ($p -clike 'docs/*' -or $p -clike 'specs/*') { return $false }
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
        # -CaseSensitive and -cnotmatch, both deliberately: without them `// todo:`
        # counted here and not in check-stubs.sh, and a line reading
        # `Approved-Stub:` exempted itself here alone.
        $m = Select-String -LiteralPath $f -Pattern $Markers -CaseSensitive -ErrorAction SilentlyContinue |
             Where-Object { $_.Line -cnotmatch $Exempt }
        if ($m) { $hits += $m }
    }
    return $hits
}

# --- test-support modes -----------------------------------------------------
if ($Classify) {
    # Split on commas as well as taking multiple values. `pwsh -File script.ps1
    # -Classify a,b,c` hands the whole thing over as ONE string -- -File does not
    # split an array argument -- so a caller that joined the list got one verdict
    # for one enormous "path" and the parity diff was a wall of noise rather than
    # a disagreement.
    $paths = @()
    foreach ($c in $Classify) { $paths += ($c -split ',' | Where-Object { $_ -ne '' }) }
    foreach ($p in $paths) {
        if (Test-IsSource $p) { Write-Host "source $p" } else { Write-Host "skip $p" }
    }
    exit 0
}

# Which LINES of a given file count, ignoring Test-IsSource. The marker regex and
# the exemption are the other half of the rule, and the tree this script normally
# walks does not happen to contain a lower-case `todo:` or an unjustified
# `approved-stub:` -- so a count over the real repo cannot see either.
if ($Scan) {
    foreach ($p in $Scan) {
        Select-String -LiteralPath $p -Pattern $Markers -CaseSensitive -ErrorAction SilentlyContinue |
            Where-Object { $_.Line -cnotmatch $Exempt } |
            ForEach-Object { Write-Host ("{0}:{1}:{2}" -f $p, $_.LineNumber, $_.Line) }
    }
    exit 0
}

$hits = @(Get-StubLines)
$current = $hits.Count

if ($Count) {
    Write-Host $current
    exit 0
}

if ($Baseline) {
    Set-Content -LiteralPath $BaselineFile -Value $current -NoNewline
    Write-Host "STUBS: baseline set to $current -- commit $BaselineFile."
    Write-Host "  Pin it too, in the same commit:  sha256sum gate.sh check-stubs.sh $BaselineFile > .gate-sha256"
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
    Write-Host "  deferral is reviewable rather than invisible. The reason is required:"
    Write-Host "  a bare 'approved-stub:' with nothing after it does not exempt anything."
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
