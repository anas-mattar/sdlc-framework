# Runs every payload in tests/fixtures/guard-cases.tsv through the .ps1 guards and
# prints one line per case:  <case-number><TAB><exit-code>
#
# framework-checks.sh runs the .sh guards over the same fixture and compares the
# two answers case by case. This script exists only so that comparison can be
# afforded: spawning `pwsh -File guard-x.ps1` once per case costs a process launch
# each time, and on Windows that turned a two-second check into a two-minute one --
# which is how a self-test stops being run. One process handles the whole fixture.
#
# Two mechanics make that work, and both are worth knowing before editing this:
#
#   * [Console]::SetIn redirects the process's standard input to a string, so each
#     hook's `[Console]::In.ReadToEnd()` reads that case's payload. The hooks are
#     not modified or mocked -- they run their real parsing code.
#   * `& <script.ps1>` invokes a script FILE in a child scope, so `exit 2` inside
#     the hook ends the hook and sets $LASTEXITCODE rather than killing this
#     runner. Dot-sourcing would kill it; do not change the call operator.
#
# Keep this file ASCII-only -- framework-checks.sh check 1 enforces it, for the
# reason documented in the hooks themselves.

$ErrorActionPreference = 'Continue'

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$fixture = Join-Path $root 'tests/fixtures/guard-cases.tsv'
if (-not (Test-Path -LiteralPath $fixture)) {
    [Console]::Error.WriteLine("MISSING: $fixture")
    exit 1
}

$stdin = [Console]::In
$stderr = [Console]::Error
$n = 0
foreach ($line in [IO.File]::ReadAllLines($fixture)) {
    if ($line -match '^\s*#' -or $line.Trim() -eq '') { continue }
    $cols = $line -split "`t"
    if ($cols.Count -lt 3) { continue }
    $hook = $cols[0].Trim()
    $payload = $cols[2]
    if ($payload -eq '') { continue }
    $n++

    $script = Join-Path $root "tooling/claude/hooks/guard-$hook.ps1"
    if (-not (Test-Path -LiteralPath $script)) {
        [Console]::Error.WriteLine("MISSING: $script")
        exit 1
    }

    $global:LASTEXITCODE = 0
    try {
        [Console]::SetIn([IO.StringReader]::new($payload))
        # The block messages go through [Console]::Error, which writes to the
        # process handle directly and so ignores `*> $null`. Only SetError silences
        # them, and they must be silenced: this script's stdout is parsed.
        [Console]::SetError([IO.TextWriter]::Null)
        & $script *> $null
        $rc = $LASTEXITCODE
    } catch {
        # A hook that throws would fail OPEN in production, so report it as a
        # distinct code rather than letting it read as an allow.
        $rc = 99
    } finally {
        [Console]::SetIn($stdin)
        [Console]::SetError($stderr)
    }
    if ($null -eq $rc) { $rc = 0 }
    [Console]::Out.WriteLine("$n`t$rc")
}
exit 0
