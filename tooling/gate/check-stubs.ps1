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

# Is this basename a TEST file? Split into TOKENS at `.`, `_` and `-`, and ask
# whether any token IS the word test/tests/spec/specs -- or ends with it in
# CamelCase, which is how .NET, Java and Scala name theirs.
#
# The rule used to be the substring `[Tt]est`, and a substring is not a word:
# `git mv src/ledger.ts src/latest-ledger.ts` took the count from 1 to 0 on both
# implementations, and `protest.go`, `contest.rb`, `Greatest.cs` and
# `attestation.ts` were invisible to the ratchet for as long as they existed.
#
# Erring the other way is deliberate: `Testing.cs` and `TestHelpers.cs` are now
# SOURCE, so their markers count. A ratchet that counts too much fails loudly and
# gets fixed; one that counts too little reports a floor nobody is standing on.
#
# Mirrored token for token in check-stubs.sh's is_test_name.
function Test-IsTestName([string]$Name) {
    foreach ($t in ($Name -split '[._-]')) {
        if ($t -ceq 'test' -or $t -ceq 'tests' -or $t -ceq 'Test' -or $t -ceq 'Tests' -or
            $t -ceq 'spec' -or $t -ceq 'specs' -or $t -ceq 'Spec' -or $t -ceq 'Specs') { return $true }
        # CamelCase: `OrderTests`, `UserSpec`. A lower-case letter or digit before
        # the capital is what keeps `Greatest` out -- its `test` is lower case and
        # so is not a word boundary.
        if ($t -cmatch '[a-z0-9](Test|Tests|Spec|Specs)$') { return $true }
    }
    return $false
}

function Test-IsSource([string]$Path) {
    $p = ($Path -replace '\\', '/').TrimEnd('/')
    $b = $p.Substring($p.LastIndexOf('/') + 1)
    # The checker itself names every marker it hunts for, in its own regex and its
    # own comments. Left in, it would count several of its own lines on a clean
    # repo -- a number nobody can explain and everybody learns to ignore.
    if ($b -ceq 'check-stubs.sh' -or $b -ceq 'check-stubs.ps1') { return $false }
    # THE FRAMEWORK'S OWN INSTALLED TOOLING IS NOT PROJECT SOURCE. The first real
    # v2.2.0 -> v2.3.0 upgrade rehearsal caught this: a fresh multi-repo install
    # with ZERO application code baselined at 1, because the word TODO appears in a
    # COMMENT inside tooling/ci/gate-ci.sh. Appending one more explanatory `# TODO:`
    # line to that script then made the ratchet FAIL on a project whose own code had
    # not changed -- so any framework release that edits a comment in its own
    # tooling would break every consuming project's ratchet. Kept in step with
    # is_source in check-stubs.sh.
    if ($b -ceq 'gate.sh' -or $b -ceq 'gate.ps1' -or $b -ceq 'gate-ci.sh') { return $false }
    # A leading-dot file with no further extension is configuration, not code.
    # `.gitignore` counted as source while README.md did not, purely because the
    # deny-list happened to name one and not the other. A dotfile WITH a code
    # extension (.eslintrc.js) is still source, which is what the next test allows.
    #
    # This side was never wrong, and the reason is worth recording: these are
    # sequential `if`s, each returning only on its own match, so the dotfile test
    # sitting BEFORE the extension test costs nothing -- `.foo.md` falls through to
    # the `\.md$` rule below. The .sh twin expressed the same rules as arms of one
    # `case`, which stops at its first match, so there the dotfile arm swallowed
    # every dotfile before any extension was tested and `.foo.md` came back SOURCE
    # while `README.md` did not. Same rules, same order, different construct, and
    # only one of them had the bug. The fixture rows for `.foo.md`, `.bar.json`,
    # `.baz.yaml`, `.notes.txt`, `.data.csv` and `.lock.sum` pin the agreement.
    if ($b.StartsWith('.') -and $b.IndexOf('.', 1) -lt 0) { return $false }
    if ($b -match '\.(md|txt|json|yml|yaml|csv|svg|lock|sum)$') { return $false }
    if ($b -clike '*.min.js') { return $false }
    if (Test-IsTestName $b) { return $false }
    $segments = '/' + $p
    foreach ($d in @('node_modules', 'vendor', 'dist', 'build',
                     'test', 'tests', 'Test', 'Tests', '__tests__', 'spec', 'specs')) {
        if ($segments.Contains("/$d/")) { return $false }
    }
    # Framework-owned directories, matched on the path so a project's own
    # `app/github/webhook.go` stays source.
    foreach ($d in @('.claude', '.github')) {
        if ($segments.Contains("/$d/")) { return $false }
    }
    # No per-platform CI wrapper filename rule: every one of them (.gitlab-ci.yml,
    # azure-pipelines.yml, bitbucket-pipelines.yml) ends in .yml and is already
    # excluded by the extension test above. The .sh twin carried such a rule
    # and it was masking a shadowed-`case` bug rather than doing work; both
    # sides dropped it with that fix.
    if ($p -clike 'docs/*' -or $p -clike 'specs/*') { return $false }
    return $true
}

function Get-StubLines {
    # Tracked files plus untracked-but-not-ignored ones: the gate runs on a dirty
    # tree, and a stub added in an uncommitted file is exactly what this catches.
    #
    # `-c core.quotePath=false` is not cosmetic. git's DEFAULT renders any
    # non-ASCII path as a quoted C string -- `src/caf\303\251.ts` comes back as
    # `"src/caf\303\251.ts"`, which is not the name of any file, so Test-Path
    # failed and the file was skipped in silence. `mv ledger.ts ledger.ts` with any
    # accented character in the new name therefore removed its markers from the
    # count with no message, on this side and on the .sh side both.
    # ...and the encoding is the other half of the same bug. PowerShell decodes a
    # native command's stdout with [Console]::OutputEncoding, which on Windows is
    # the OEM code page, so git's UTF-8 bytes for `src/cafe.ts` (with an accent)
    # arrived as mojibake and Test-Path returned False on a file that is right
    # there. Both halves have to be fixed or the file is still invisible.
    $prevEnc = [Console]::OutputEncoding
    try {
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        $files = @(git -c core.quotePath=false ls-files --cached --others --exclude-standard 2>$null)
    } finally { [Console]::OutputEncoding = $prevEnc }

    # A FAILED ENUMERATION MUST NOT READ AS A CLEAN TREE. git listing nothing means
    # either "not a repository" or "a repository with nothing in it", and those are
    # not the same answer -- but both used to produce a count of 0, which the ratchet
    # reports as "improved" while inviting you to write 0 into the PINNED baseline.
    # After that no marker anywhere can ever fail it again. The .sh twin exits 4
    # here; so does this one, because a verdict the two implementations disagree on
    # is worse than either verdict alone.
    if ($files.Count -eq 0) {
        Write-Host "check-stubs: git listed no files in this directory."
        Write-Host "  Either this is not a git repository, or the working tree is empty."
        Write-Host "  Refusing to report 0 markers: a scan that saw nothing and a tree"
        Write-Host "  with nothing in it are not the same answer."
        exit 4
    }

    $hits = @()
    $wide = @()
    foreach ($f in $files) {
        if (-not (Test-IsSource $f)) { continue }
        if (-not (Test-Path -LiteralPath $f -PathType Leaf)) { continue }

        # UTF-16 IS REFUSED, NOT DECODED. Select-String would happily read a BOM'd
        # UTF-16 file and count its markers -- and the .sh twin cannot, because
        # `TODO` is stored there as T\0O\0D\0O\0 and a byte-oriented grep can never
        # match it. So the two implementations returned DIFFERENT counts for the
        # same tree: sh saw 1 where this saw 7. Refusing on both sides is the only
        # answer that keeps them in agreement, and it is the honest one -- a marker
        # a Windows editor has made invisible to the POSIX gate is a marker that
        # would leave the ratchet the moment CI ran.
        # Resolve-Path first, and not for tidiness: [System.IO.File] uses the .NET
        # process working directory, which is NOT PowerShell's current location.
        # Handed a relative path it looks in whatever directory the process started
        # in, throws FileNotFound, and the catch below would then treat every source
        # file as "not UTF-16" -- a check that silently passes on everything.
        $bom = New-Object byte[] 2
        try {
            $fs = [System.IO.File]::OpenRead((Resolve-Path -LiteralPath $f).Path)
            try { $null = $fs.Read($bom, 0, 2) } finally { $fs.Dispose() }
            if (($bom[0] -eq 0xFF -and $bom[1] -eq 0xFE) -or
                ($bom[0] -eq 0xFE -and $bom[1] -eq 0xFF)) { $wide += $f; continue }
        } catch { }

        # -CaseSensitive and -cnotmatch, both deliberately: without them `// todo:`
        # counted here and not in check-stubs.sh, and a line reading
        # `Approved-Stub:` exempted itself here alone.
        $m = Select-String -LiteralPath $f -Pattern $Markers -CaseSensitive -ErrorAction SilentlyContinue |
             Where-Object { $_.Line -cnotmatch $Exempt }
        if ($m) { $hits += $m }
    }

    if ($wide.Count -gt 0) {
        Write-Host "check-stubs: these source files are UTF-16 and cannot be scanned for markers:"
        foreach ($w in $wide) { Write-Host ("  " + $w) }
        Write-Host "  A UTF-16 file stores TODO as T\0O\0D\0O\0, so every marker in it is"
        Write-Host "  invisible to the POSIX gate and would silently leave the ratchet."
        Write-Host "  Convert them to UTF-8 (git can do it: 'working-tree-encoding=UTF-16'"
        Write-Host "  in .gitattributes keeps the editor happy and the repository readable)."
        exit 4
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
    # The trailing newline is REQUIRED, and `-NoNewline` with an explicit "`n" is
    # how PowerShell writes exactly one. `echo` on the .sh side writes "1\n"; this
    # wrote "1" with no newline, so the same count produced a different SHA-256 --
    # and .gate-stubs-baseline is pinned. A Windows developer re-baselining at an
    # unchanged count therefore tripped "CHANGED: a pinned file does not match ...
    # the gate has been weakened -- find out by whom", and a control that cries
    # wolf on a no-op is one people learn to regenerate reflexively.
    Set-Content -LiteralPath $BaselineFile -Value "$current`n" -NoNewline -Encoding ASCII
    Write-Host "STUBS: baseline set to $current -- commit $BaselineFile."
    Write-Host "  Pin it too, in the same commit:  sha256sum gate.sh gate.ps1 check-stubs.sh check-stubs.ps1 $BaselineFile > .gate-sha256"
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
