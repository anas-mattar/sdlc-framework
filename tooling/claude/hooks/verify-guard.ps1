# Self-test for the package guards. Run from the PROJECT ROOT after install:
#     powershell -NoProfile -File .claude/hooks/verify-guard.ps1
#
# Why this exists: a misconfigured PreToolUse hook fails OPEN. If the command is
# missing or unrunnable the hook exits non-2, which Claude Code treats as a hook
# error rather than a block -- so the guard silently stops guarding and nothing
# tells you. This script reads what is actually configured in settings.json (not a
# hardcoded path) and proves it blocks.
#
# It checks the WIRING as well as the command. Reading only the first "command"
# string, as this script used to, meant two things it could not see:
#
#   - a second hook that is missing entirely. The install guard covers `npm i` and
#     friends; without it every real way of adding a dependency is unguarded while
#     this script still prints GUARD: verified.
#   - the matcher. Rewiring the hook to "matcher": "Read" -- a tool that edits
#     nothing -- left the command intact and still verified. /framework-doctor
#     trusts this script, so it reported a completely inert guard as healthy.
#
# Exit 0 = both guards verified. Exit 1 = a guard is broken, missing, or untestable.
#
# Keep this file ASCII-only. Windows PowerShell 5.1 reads UTF-8-without-BOM as ANSI,
# so a stray em dash becomes three bytes -- one of which is a quote -- and the script
# dies with "string is missing the terminator". Use `--`, never an em dash.

$settings = ".claude/settings.json"
if (-not (Test-Path $settings)) {
    Write-Host "FAIL: $settings not found -- run this from the project root."; exit 1
}

if (Test-Path ".claude/allow-package-changes") {
    Write-Host "INCONCLUSIVE: .claude/allow-package-changes exists, so the guards are"
    Write-Host "  intentionally open. Delete it and re-run to test that blocking works."
    exit 1
}

try { $cfg = Get-Content $settings -Raw | ConvertFrom-Json }
catch { Write-Host "FAIL: $settings is not valid JSON -- Claude Code will ignore the hooks entirely."; exit 1 }

$entries = @($cfg.hooks.PreToolUse)
if (-not $entries -or $entries.Count -eq 0) {
    Write-Host "FAIL: no PreToolUse hook in $settings -- the package guards are not installed."
    exit 1
}

$fail = $false

# Find the command wired to a matcher that COVERS a given tool name. Padding both
# sides with '|' means one comparison handles a tool wherever it sits in
# "Edit|MultiEdit|Write|NotebookEdit", including when it stands alone.
function Get-HookCommand([string]$Tool) {
    foreach ($e in $entries) {
        if (-not $e.matcher) { continue }
        if (("|" + $e.matcher + "|") -like ("*|" + $Tool + "|*")) {
            $c = @($e.hooks.command) | Select-Object -First 1
            if ($c) { return $c }
        }
    }
    return $null
}

# Invoke the configured command directly. Do NOT wrap it in `powershell -Command`:
# that swallows the child's exit code and reports 1, so a working guard looks broken.
function Invoke-Hook([string]$Command, $Payload) {
    $parts = $Command -split '\s+'
    $exe   = $parts[0]
    $argv  = @($parts[1..($parts.Length - 1)])
    $json  = $Payload | ConvertTo-Json -Compress
    try {
        $global:LASTEXITCODE = $null
        $json | & $exe @argv *> $null
        return $LASTEXITCODE
    } catch {
        return $null   # the command could not be run at all
    }
}

function Test-Case([string]$Command, [string]$Label, $Payload, [int]$Expected) {
    $rc = Invoke-Hook $Command $Payload
    if ($rc -eq $Expected) {
        Write-Host "  PASS  $Label (exit $rc)"
    } else {
        Write-Host "  FAIL  $Label -- expected exit $Expected, got $rc"
        $script:fail = $true
    }
}

function FilePayload([string]$Path) { @{ tool_name = "Edit"; tool_input = @{ file_path = $Path } } }
function CmdPayload([string]$Cmd)   { @{ tool_name = "Bash"; tool_input = @{ command   = $Cmd  } } }

# --- guard 1: manifest FILE edits ------------------------------------------
$fileCmd = Get-HookCommand "Edit"
if (-not $fileCmd) {
    Write-Host "FAIL: no PreToolUse hook matches Edit -- manifest files are unguarded."
    Write-Host "  Expected a matcher like ""Edit|MultiEdit|Write|NotebookEdit""."
    $fail = $true
} else {
    Write-Host "file guard: $fileCmd"

    # Pre-flight: if the hook cannot run at all, say so once rather than per case.
    if ($null -eq (Invoke-Hook $fileCmd (FilePayload "src/app.ts"))) {
        Write-Host "FAIL: the hook command cannot be run: '$fileCmd'"
        Write-Host "  The hook is installed but inert -- Claude Code treats an unrunnable"
        Write-Host "  hook as an error, not a block, so package edits go through unguarded."
        Write-Host "  On Windows use: powershell -NoProfile -File .claude/hooks/guard-packages.ps1"
        Write-Host "  On macOS/Linux use: sh .claude/hooks/guard-packages.sh"
        exit 1
    }

    if ((Get-HookCommand "Write") -ne $fileCmd) {
        Write-Host "  FAIL  the matcher covers Edit but not Write -- an agent can create a manifest."
        $fail = $true
    }

    Write-Host "guarded paths must be BLOCKED (exit 2):"
    Test-Case $fileCmd "package.json"             (FilePayload "package.json")             2
    Test-Case $fileCmd "yarn.lock"                (FilePayload "yarn.lock")                2
    Test-Case $fileCmd "Api.csproj"               (FilePayload "src/Api/Api.csproj")       2
    Test-Case $fileCmd "Directory.Packages.props" (FilePayload "Directory.Packages.props") 2
    # Ecosystems the framework ships no stack rules for. The guard covers them
    # anyway: a project whose manifests are unguarded gets no warning that the rule
    # is not being enforced, it just silently is not.
    Test-Case $fileCmd "pyproject.toml"           (FilePayload "pyproject.toml")           2
    Test-Case $fileCmd "requirements-dev.txt"     (FilePayload "requirements-dev.txt")     2
    Test-Case $fileCmd "go.mod"                   (FilePayload "go.mod")                   2
    Test-Case $fileCmd "Cargo.toml"               (FilePayload "Cargo.toml")               2
    Test-Case $fileCmd "Gemfile"                  (FilePayload "Gemfile")                  2
    Test-Case $fileCmd "pom.xml"                  (FilePayload "pom.xml")                  2
    Test-Case $fileCmd "composer.json"            (FilePayload "composer.json")            2
    # The guard's own configuration. Without these an agent that is blocked simply
    # writes the approval marker whose name the block message just supplied.
    Test-Case $fileCmd "the approval marker"      (FilePayload ".claude/allow-package-changes") 2
    Test-Case $fileCmd "settings.json"            (FilePayload ".claude/settings.json")    2
    Test-Case $fileCmd "the guard script"         (FilePayload ".claude/hooks/guard-packages.ps1") 2

    Write-Host "ordinary paths must be ALLOWED (exit 0):"
    Test-Case $fileCmd "src/app.ts"               (FilePayload "src/app.ts")               0
    Test-Case $fileCmd "docs/process/notes.md"    (FilePayload "docs/process/notes.md")    0
    # Near-misses: the guard matches the basename, so neither a manifest name buried
    # in a longer filename nor a directory named after one may block.
    Test-Case $fileCmd "docs/notes-package.json"  (FilePayload "docs/notes-package.json")  0
    Test-Case $fileCmd "vendor/Gemfile/readme.md" (FilePayload "vendor/Gemfile/readme.md") 0
}

# --- guard 2: install COMMANDS ---------------------------------------------
$instCmd = Get-HookCommand "Bash"
if (-not $instCmd) {
    Write-Host "FAIL: no PreToolUse hook matches Bash -- every install path is unguarded."
    Write-Host "  The file guard above only sees Edit/Write against manifest files."
    Write-Host "  'npm i', 'dotnet add package', 'pip install' and 'go get' bypass it entirely."
    Write-Host "  Add a second PreToolUse entry with matcher ""Bash"" running guard-installs."
    $fail = $true
} else {
    Write-Host "install guard: $instCmd"
    Write-Host "install commands must be BLOCKED (exit 2):"
    Test-Case $instCmd "npm install"        (CmdPayload "npm install left-pad")       2
    Test-Case $instCmd "yarn add"           (CmdPayload "yarn add zod")               2
    Test-Case $instCmd "dotnet add package" (CmdPayload "dotnet add package Serilog") 2
    Test-Case $instCmd "pip install"        (CmdPayload "pip install requests")       2
    Test-Case $instCmd "go get"             (CmdPayload "go get github.com/x/y")      2

    Write-Host "build commands must be ALLOWED (exit 0):"
    Test-Case $instCmd "npm run build"      (CmdPayload "npm run build")              0
    Test-Case $instCmd "git status"         (CmdPayload "git status")                 0
}

if (-not $fail) {
    Write-Host "GUARD: verified -- manifest edits and install commands are both blocked without approval."
    exit 0
}
Write-Host "GUARD: BROKEN -- a guard is not enforcing. Fix .claude/settings.json before"
Write-Host "  trusting the package rule; on Windows the two commands should be:"
Write-Host "  powershell -NoProfile -File .claude/hooks/guard-packages.ps1   (matcher: Edit|MultiEdit|Write|NotebookEdit)"
Write-Host "  powershell -NoProfile -File .claude/hooks/guard-installs.ps1   (matcher: Bash)"
exit 1
