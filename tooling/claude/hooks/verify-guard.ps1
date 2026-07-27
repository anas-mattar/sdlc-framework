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

param(
    # Recompute and print the four list digests, for pasting into this file and
    # into verify-guard.sh after a legitimate change to a guard list. Regenerating
    # has to be one command or it becomes a thing people work around by deleting
    # the check.
    [switch]$PrintDigests
)

$settings = ".claude/settings.json"
$fail = $false

# --- the lists must still be the lists that shipped -------------------------
# Behavioural cases can only ever sample. Cutting the install list down to exactly
# the handful this script exercises left it printing GUARD: verified while
# `npx cowsay`, `pnpm add react`, `cargo add serde`, `bun install`, `gem install
# rails` and `composer require` all returned 0 -- an 85% cut, certified. The
# framework's 99-case fixture would catch that, but it lives in the framework
# repository, not in an installed project, where THIS script is the only
# mechanical check there is.
#
# A COUNT WAS NOT ENOUGH, and the fix for that finding is the finding one layer
# down. A floor detects DELETION and not SUBSTITUTION. Keeping the twelve commands
# this script exercises, replacing the other forty-four with `zzjunk00` and leaving
# the count at 56, produced two PASS lines and GUARD: verified while `npm ci`,
# `yarn install`, `uv add`, `poetry add`, `bundle add`, `conda install`,
# `pipx install`, `go install`, `yarn upgrade` and `pnpm dlx` were all open.
#
# So the lists are pinned by DIGEST. Changing one means changing a hash here, in
# the same diff, where a reviewer sees it -- the same argument .gate-sha256 makes
# about the gate script.
#
# FOUR digests, because the configured command may name either twin and the shipped
# default names the .ps1. These constants MUST match verify-guard.sh exactly: the
# framework's own suite asserts that they do, because a divergence here means one
# platform pins its lists and the other does not, which is the failure this whole
# framework's history is made of.
#
# Regenerate after a legitimate list change with:
#     powershell -NoProfile -File .claude/hooks/verify-guard.ps1 -PrintDigests
$GuardedDigestSh  = 'c68dc68623405006f36b034cf73dcc70282b0442ec9af1eaed1e5b6f3c0980a7'
$InstallDigestSh  = '37c9426ef80866a630e7304f8460545140eb3e14fc0108924c1fe42baf37e979'
$GuardedDigestPs1 = '04617cf3a9f4d77f189fc678f38dab71890c74897cde76a2e7bd608c4a3a5aff'
$InstallDigestPs1 = '2e5f65bd2e5bc60e89d126d7f2ca08afcdee72bd3ec27bb8d88d4cd0a3843843'
# Kept as a floor of last resort only. Not the assertion any more.
$GuardedFloor = 86
$InstallFloor = 56

# The list body, normalised so a digest survives what legitimately differs between
# checkouts. This MUST agree byte for byte with list_body() in verify-guard.sh:
# strip CR (the .ps1 files are checked out CRLF by .gitattributes and the .sh files
# LF, so the digest of a given list must not depend on which), drop comment lines
# (prose, re-wrappable without changing behaviour), strip trailing whitespace, drop
# blank lines. Joined with LF, and hashed with no trailing newline -- which is what
# `sed ... | sha256sum` produces on the POSIX side for the same input.
function Get-ListBody([string]$Script, [string]$Begin, [string]$End) {
    if (-not (Test-Path -LiteralPath $Script)) { return $null }
    $lines = @(Get-Content -LiteralPath $Script)
    $in = $false
    # A plain array, not a generic List. `New-Object System.Collections.Generic.
    # List[string]` is a documented idiom and also a parse ambiguity -- the
    # brackets read as an index in some positions -- and this file has to survive
    # Windows PowerShell 5.1 as well as 7. These bodies are ~60 lines; the cost of
    # `+=` is irrelevant and the syntax is unmistakable.
    $keep = @()
    foreach ($l in $lines) {
        if ($in -and ($l -match $End)) { break }
        if ($in) {
            $t = ($l -replace "`r", '') -replace '[ \t]+$', ''
            if ($t -notmatch '^\s*#' -and $t -match '\S') { $keep += $t }
        }
        if ($l -match $Begin) { $in = $true }
    }
    if ($keep.Count -eq 0) { return '' }
    # A trailing newline, because the POSIX side pipes newline-terminated lines
    # into sha256sum. Without it the two digests differ for identical content.
    return (($keep -join "`n") + "`n")
}

function Get-ListDigest([string]$Script, [string]$Begin, [string]$End) {
    $body = Get-ListBody $Script $Begin $End
    if ($null -eq $body) { return $null }
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return (($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join '')
    } finally { $sha.Dispose() }
}

# The two .sh lists are shaped differently and must be counted differently: the
# manifest patterns are whitespace-separated across lines, the install patterns are
# one PER LINE because they contain spaces (`dotnet add package`). Counting words
# in the install list reported 117 for 56 entries, and a floor that a half-emptied
# list still clears is not a floor. In the .ps1 hooks both are quoted strings, so
# one rule covers them. Retained for the entry COUNT shown alongside the digest.
function Get-ListSize([string]$Script, [string]$Begin, [string]$End, [string]$Mode) {
    if (-not (Test-Path -LiteralPath $Script)) { return 0 }
    $lines = @(Get-Content -LiteralPath $Script)
    $in = $false; $n = 0
    foreach ($l in $lines) {
        if ($l -match $End) { break }
        if ($in) {
            if ($Script -like '*.ps1') {
                $n += ([regex]::Matches($l, "'[^']+'")).Count
            } elseif ($Mode -eq 'lines') {
                if ($l -match '\S') { $n++ }
            } else {
                $n += @(($l -replace '"', '') -replace '^[A-Z_]*=', '' -split '\s+' |
                        Where-Object { $_ -ne '' }).Count
            }
        }
        if ($l -match $Begin) { $in = $true }
    }
    return $n
}

# Regenerating the constants is one command. Placed HERE, below the functions it
# calls, because PowerShell executes a script top to bottom: a -PrintDigests block
# above the definitions would fail with "Get-ListDigest is not recognized".
if ($PrintDigests) {
    Write-Host "Paste these into verify-guard.ps1, and the _SH/_PS1 pair into verify-guard.sh:"
    Write-Host ("GuardedDigestSh  = " + (Get-ListDigest '.claude/hooks/guard-packages.sh'  'GUARDED-MANIFESTS-BEGIN' 'GUARDED-MANIFESTS-END'))
    Write-Host ("InstallDigestSh  = " + (Get-ListDigest '.claude/hooks/guard-installs.sh'  'INSTALL-COMMANDS-BEGIN'  'INSTALL-COMMANDS-END'))
    Write-Host ("GuardedDigestPs1 = " + (Get-ListDigest '.claude/hooks/guard-packages.ps1' 'GUARDED-MANIFESTS-BEGIN' 'GUARDED-MANIFESTS-END'))
    Write-Host ("InstallDigestPs1 = " + (Get-ListDigest '.claude/hooks/guard-installs.ps1' 'INSTALL-COMMANDS-BEGIN'  'INSTALL-COMMANDS-END'))
    exit 0
}

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

function Test-ListSize([string]$Command, [string]$Begin, [string]$End, [string]$DigestPrefix, [string]$Label, [string]$Mode, [int]$Floor) {
    # The script is the last word of the configured command.
    $script = ($Command -split '\s+')[-1]
    $n = Get-ListSize $script $Begin $End $Mode
    # Pick the digest belonging to the twin actually configured.
    $want = if ($script -like '*.ps1') {
        Get-Variable -Name ($DigestPrefix + 'Ps1') -ValueOnly
    } else {
        Get-Variable -Name ($DigestPrefix + 'Sh') -ValueOnly
    }
    $actual = Get-ListDigest $script $Begin $End
    if ($actual -eq $want) {
        Write-Host "  PASS  $Label list matches the digest it shipped with ($n entries)"
    } elseif ($n -lt $Floor) {
        # A digest mismatch AND a short list. Report the shorter diagnosis: a list
        # that has been cut down is a different mistake from one that has been
        # edited, and "you removed patterns" is more actionable than two hashes.
        # .NET always has SHA256, so unlike the POSIX twin there is no no-digest
        # fallback here -- the floor exists only to sharpen this message.
        Write-Host "  FAIL  $Label list has $n entries, expected at least $Floor -- $script has"
        Write-Host "        been cut down. Patterns removed from the list are silently"
        Write-Host "        unguarded; the behavioural cases below only sample it."
        $script:fail = $true
    } else {
        Write-Host "  FAIL  $Label list does not match the digest it shipped with."
        Write-Host "        expected $want"
        Write-Host "        actual   $actual   ($n entries)"
        Write-Host "        $script has been edited. A count would not have caught this:"
        Write-Host "        entries can be REPLACED without changing how many there are,"
        Write-Host "        and the behavioural cases below only sample the list."
        Write-Host "        If the change is intended, regenerate with:"
        Write-Host "            powershell -NoProfile -File .claude/hooks/verify-guard.ps1 -PrintDigests"
        $script:fail = $true
    }
}

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
    Test-ListSize $fileCmd 'GUARDED-MANIFESTS-BEGIN' 'GUARDED-MANIFESTS-END' 'GuardedDigest' 'manifest' 'words' $GuardedFloor

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
    # One from each part of the list, not five from the front of it: these are the
    # entries a gutted list loses first, and a list cut down to exactly what this
    # script used to test allowed every one of them.
    Test-Case $fileCmd "package-lock.json"        (FilePayload "package-lock.json")        2
    Test-Case $fileCmd ".npmrc"                   (FilePayload ".npmrc")                   2
    Test-Case $fileCmd "go.sum"                   (FilePayload "go.sum")                   2
    Test-Case $fileCmd "global.json"              (FilePayload "global.json")              2
    Test-Case $fileCmd "Dockerfile"               (FilePayload "Dockerfile")               2
    Test-Case $fileCmd ".cargo/config.toml"       (FilePayload ".cargo/config.toml")       2
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
    Test-ListSize $instCmd 'INSTALL-COMMANDS-BEGIN' 'INSTALL-COMMANDS-END' 'InstallDigest' 'install-command' 'lines' $InstallFloor
    Write-Host "install commands must be BLOCKED (exit 2):"
    Test-Case $instCmd "npm install"        (CmdPayload "npm install left-pad")       2
    Test-Case $instCmd "yarn add"           (CmdPayload "yarn add zod")               2
    Test-Case $instCmd "dotnet add package" (CmdPayload "dotnet add package Serilog") 2
    Test-Case $instCmd "pip install"        (CmdPayload "pip install requests")       2
    Test-Case $instCmd "go get"             (CmdPayload "go get github.com/x/y")      2
    # Spread across the list rather than clustered at its front.
    Test-Case $instCmd "npx"                (CmdPayload "npx cowsay hi")              2
    Test-Case $instCmd "pnpm add"           (CmdPayload "pnpm add react")             2
    Test-Case $instCmd "cargo add"          (CmdPayload "cargo add serde")            2
    Test-Case $instCmd "bun install"        (CmdPayload "bun install")                2
    Test-Case $instCmd "gem install"        (CmdPayload "gem install rails")          2
    Test-Case $instCmd "composer require"   (CmdPayload "composer require monolog")   2
    # An option between the tool and its subcommand is a documented invocation,
    # and both implementations allowed it for three releases.
    Test-Case $instCmd "npm --silent install" (CmdPayload "npm --silent install x")   2

    Write-Host "build commands must be ALLOWED (exit 0):"
    Test-Case $instCmd "npm run build"      (CmdPayload "npm run build")              0
    Test-Case $instCmd "git status"         (CmdPayload "git status")                 0

    # --- the install guard's OWN perimeter -----------------------------------
    # This block did not exist. The file guard's self-protection was tested and
    # the install guard's -- roughly ninety lines of it -- was not, so deleting
    # the entire perimeter block and changing nothing else produced
    # GUARD: verified while `rm .claude/hooks/guard-packages.ps1` and
    # `touch .claude/allow-package-changes` both returned 0.
    Write-Host "the guard's own perimeter must be BLOCKED (exit 2):"
    Test-Case $instCmd "creating the approval marker" `
        (CmdPayload "touch .claude/allow-package-changes")                            2
    Test-Case $instCmd "deleting a hook script" `
        (CmdPayload "rm .claude/hooks/guard-packages.ps1")                            2
    Test-Case $instCmd "editing the hook configuration in place" `
        (CmdPayload "sed -i s/a/b/ .claude/settings.json")                            2
    Test-Case $instCmd "overwriting the configuration by redirection" `
        (CmdPayload "printf {} > .claude/settings.json")                              2
    # A read earlier in the same command used to move the inspected window off
    # the write that followed it.
    Test-Case $instCmd "a read before the write does not shelter it" `
        (CmdPayload "ls .claude/settings.json && printf {} > .claude/settings.json")  2
    Test-Case $instCmd "removing the whole directory" `
        (CmdPayload "rm -rf .claude")                                                 2

    Write-Host "reading the guard's own files must be ALLOWED (exit 0):"
    Test-Case $instCmd "reading the configuration" `
        (CmdPayload "cat .claude/settings.json")                                      0
    Test-Case $instCmd "running a hook -- the doctor does this" `
        (CmdPayload "sh .claude/hooks/verify-guard.sh")                               0
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
