# Self-test for the package guard. Run from the PROJECT ROOT after install:
#     powershell -NoProfile -File .claude/hooks/verify-guard.ps1
#
# Why this exists: a misconfigured PreToolUse hook fails OPEN. If the command is
# missing or unrunnable the hook exits non-2, which Claude Code treats as a hook
# error rather than a block -- so the guard silently stops guarding and nothing
# tells you. This script reads the command actually configured in settings.json
# (not a hardcoded path) and proves it blocks.
#
# Exit 0 = guard verified. Exit 1 = guard broken or untestable.
#
# Keep this file ASCII-only. Windows PowerShell 5.1 reads UTF-8-without-BOM as ANSI,
# so a stray em dash becomes three bytes -- one of which is a quote -- and the script
# dies with "string is missing the terminator". Use `--`, never an em dash.

$settings = ".claude/settings.json"
if (-not (Test-Path $settings)) {
    Write-Host "FAIL: $settings not found -- run this from the project root."; exit 1
}

$cmd = (Get-Content $settings -Raw | ConvertFrom-Json).hooks.PreToolUse.hooks.command | Select-Object -First 1
if (-not $cmd) {
    Write-Host "FAIL: no hook command in $settings -- the package guard is not installed."; exit 1
}
Write-Host "hook command: $cmd"

if (Test-Path ".claude/allow-package-changes") {
    Write-Host "INCONCLUSIVE: .claude/allow-package-changes exists, so the guard is"
    Write-Host "  intentionally open. Delete it and re-run to test that blocking works."
    exit 1
}

$fail = $false

# Invoke the configured command directly. Do NOT wrap it in `powershell -Command`:
# that swallows the child's exit code and reports 1, so a working guard looks broken.
$parts = $cmd -split '\s+'
$exe   = $parts[0]
$argv  = @($parts[1..($parts.Length - 1)])

function Invoke-Hook([string]$FilePath) {
    $payload = @{ tool_name = "Edit"; tool_input = @{ file_path = $FilePath } } | ConvertTo-Json -Compress
    try {
        $payload | & $script:exe @script:argv *> $null
        return $LASTEXITCODE
    } catch {
        return $null   # command could not be run at all
    }
}

# Pre-flight: if the hook cannot run, say so once instead of repeating it per case.
if ($null -eq (Invoke-Hook "src/app.ts")) {
    Write-Host "FAIL: the hook command cannot be run: '$exe'"
    Write-Host "  The hook is installed but inert -- Claude Code treats an unrunnable"
    Write-Host "  hook as an error, not a block, so package edits go through unguarded."
    Write-Host "  On Windows use: powershell -NoProfile -File .claude/hooks/guard-packages.ps1"
    Write-Host "  On macOS/Linux use: sh .claude/hooks/guard-packages.sh"
    exit 1
}

function Test-Guard([string]$Label, [string]$FilePath, [int]$Expected) {
    $rc = Invoke-Hook $FilePath
    if ($rc -eq $Expected) {
        Write-Host "  PASS  $Label (exit $rc)"
    } else {
        Write-Host "  FAIL  $Label -- expected exit $Expected, got $rc"
        $script:fail = $true
    }
}

Write-Host "guarded paths must be BLOCKED (exit 2):"
Test-Guard "package.json"             "package.json"             2
Test-Guard "yarn.lock"                "yarn.lock"                2
Test-Guard "Api.csproj"               "src/Api/Api.csproj"       2
Test-Guard "Directory.Packages.props" "Directory.Packages.props" 2
# Ecosystems the framework ships no stack rules for. The guard covers them
# anyway: a project whose manifests are unguarded gets no warning that the rule
# is not being enforced, it just silently is not.
Test-Guard "pyproject.toml"           "pyproject.toml"           2
Test-Guard "requirements-dev.txt"     "requirements-dev.txt"     2
Test-Guard "go.mod"                   "go.mod"                   2
Test-Guard "Cargo.toml"               "Cargo.toml"               2
Test-Guard "Gemfile"                  "Gemfile"                  2
Test-Guard "pom.xml"                  "pom.xml"                  2
Test-Guard "composer.json"            "composer.json"            2

Write-Host "ordinary paths must be ALLOWED (exit 0):"
Test-Guard "src/app.ts"               "src/app.ts"               0
Test-Guard "docs/process/notes.md"    "docs/process/notes.md"    0
# Near-misses: the guard matches the basename, so neither a manifest name buried
# in a longer filename nor a directory named after one may block.
Test-Guard "docs/notes-package.json"  "docs/notes-package.json"  0
Test-Guard "vendor/Gemfile/readme.md" "vendor/Gemfile/readme.md" 0

if (-not $fail) {
    Write-Host "GUARD: verified -- package manifests are blocked without approval."
    exit 0
}
Write-Host "GUARD: BROKEN -- the hook is not enforcing. Fix .claude/settings.json before"
Write-Host "  trusting the package rule; on Windows the command should be:"
Write-Host "  powershell -NoProfile -File .claude/hooks/guard-packages.ps1"
exit 1
