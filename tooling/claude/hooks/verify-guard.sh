#!/usr/bin/env sh
# Self-test for the package guards. Run from the PROJECT ROOT after install:
#     sh .claude/hooks/verify-guard.sh
#
# Why this exists: a misconfigured PreToolUse hook fails OPEN. If the command is
# missing or unrunnable the hook exits non-2, which Claude Code treats as a hook
# error rather than a block — so the guard silently stops guarding and nothing
# tells you. This script reads what is actually configured in settings.json (not a
# hardcoded path) and proves it blocks.
#
# It checks the WIRING as well as the command. Reading only the first `"command"`
# string, as this script used to, meant two things it could not see:
#
#   - a second hook that is missing entirely. The install guard covers `npm i` and
#     friends; without it every real way of adding a dependency is unguarded while
#     this script still prints GUARD: verified.
#   - the matcher. Rewiring the hook to `"matcher": "Read"` — a tool that edits
#     nothing — left the command intact and still verified. /framework-doctor
#     trusts this script, so it reported a completely inert guard as healthy.
#
# Exit 0 = both guards verified. Exit 1 = a guard is broken, missing, or untestable.
#
# On Windows, run verify-guard.ps1 instead — not because this script is wrong, but
# because it spawns a shell per case and MSYS fork-and-pipe is slow enough that a
# full run intermittently stalls partway through. A verifier that hangs teaches you
# to stop running it, which costs more than the check is worth. The .ps1 verifier
# parses settings.json natively and makes the same assertions.

settings=".claude/settings.json"
[ -f "$settings" ] || { echo "FAIL: $settings not found — run this from the project root."; exit 1; }

if [ -f .claude/allow-package-changes ]; then
    echo "INCONCLUSIVE: .claude/allow-package-changes exists, so the guards are"
    echo "  intentionally open. Delete it and re-run to test that blocking works."
    exit 1
fi

# Pair each matcher with the command configured under it, within PreToolUse only.
# This is a line-oriented read rather than a JSON parse: an installed project has
# no guaranteed interpreter, and settings.json ships one key per line. Minified
# JSON collapses to a single line and is reported rather than misread.
pairs=$(awk '
    /"PreToolUse"/                    { pre = 1 }
    /"(PostToolUse|Stop|SubagentStop|SessionStart|UserPromptSubmit|Notification|PreCompact)"/ { pre = 0 }
    pre && /"matcher"[[:space:]]*:/   { m = $0; sub(/.*"matcher"[^"]*"/, "", m); sub(/".*/, "", m) }
    pre && /"command"[[:space:]]*:/   { c = $0; sub(/.*"command"[^"]*"/, "", c); sub(/".*/, "", c)
                                        if (m != "") print m "\t" c }
' "$settings")

if [ -z "$pairs" ]; then
    echo "FAIL: no PreToolUse hook found in $settings — the package guards are not installed."
    echo "  (If your settings.json is minified onto one line, reformat it one key per line.)"
    exit 1
fi

TAB=$(printf '\t')
fail=0
substituted=0

# --- the lists must still be the size they shipped --------------------------
# Behavioural cases can only ever sample. Cutting INSTALL_COMMANDS down to exactly
# the handful this script exercises left it printing GUARD: verified while
# `npx cowsay`, `pnpm add react`, `cargo add serde`, `bun install`, `gem install
# rails` and `composer require` all returned 0 -- an 85% cut, certified. The
# framework's 99-case fixture would catch that, but that fixture lives in the
# framework repository, not in an installed project, where THIS script is the only
# mechanical check there is.
#
# So the size is asserted as well as the behaviour: a floor, ratcheted the same way
# the rest of the framework ratchets. Adding patterns is free; removing one means
# lowering a number here, in the same diff, where a reviewer sees it.
GUARDED_FLOOR=86
INSTALL_FLOOR=56

# The two .sh lists are shaped differently and must be counted differently: the
# manifest patterns are whitespace-separated across lines, the install patterns are
# one PER LINE because they contain spaces (`dotnet add package`). Counting words
# in the install list reported 117 for 56 entries, and a floor that a half-emptied
# list still clears is not a floor. In the .ps1 hooks both lists are quoted
# strings, so one rule covers them.
list_size() {  # list_size <hook script> <begin marker> <end marker> <words|lines>
    [ -f "$1" ] || { echo 0; return; }
    case "$1" in
        *.ps1) sed -n "/$2/,/$3/p" "$1" | grep -oE "'[^']+'" | grep -c . ;;
        *)
            body=$(sed -n "/$2/,/$3/p" "$1" | sed '1d;$d' | tr -d '"' | sed 's/^[A-Z_]*=//')
            case "$4" in
                lines) printf '%s\n' "$body" | grep -c '[^[:space:]]' ;;
                *)     printf '%s\n' "$body" | tr ' \t' '\n\n' | grep -c . ;;
            esac ;;
    esac
}

check_list_size() {  # check_list_size <configured command> <begin> <end> <floor> <label> <words|lines>
    # The script is the last word of the configured command -- the same
    # assumption runnable_or_twin makes.
    script=${1##* }
    n=$(list_size "$script" "$2" "$3" "$6")
    if [ "$n" -ge "$4" ]; then
        echo "  PASS  $5 list has $n entries (floor $4)"
    else
        echo "  FAIL  $5 list has $n entries, expected at least $4 -- $script has been"
        echo "        cut down. Patterns removed from the list are silently unguarded;"
        echo "        the behavioural cases below only sample it."
        fail=1
    fi
}

# The WIRING is checked as configured; the BEHAVIOUR needs a command this machine
# can actually run. settings.json ships the PowerShell commands, because that is
# the platform where the POSIX form fails open -- so on Linux (which is where CI
# runs this) the configured command is `powershell -NoProfile -File ...ps1` and
# there is no powershell. Running it would report GUARD: BROKEN on a guard that is
# fine, and a verifier that cries wolf is one people stop running.
#
# So: if the configured command's interpreter is not on this machine, fall back to
# the sibling .sh hook and SAY SO. That keeps the behavioural assertions running in
# CI. It does not weaken anything -- the matcher and the presence of both hooks are
# still checked against what is really configured, and a configured command that
# names a hook script which does not exist still fails.
#
# When it fires, this script may NOT report `GUARD: verified`. It tested a
# different file from the one Claude Code will run, and on Linux and macOS that is
# not a rare case -- it is the SHIPPED DEFAULT, because settings.json ships the
# PowerShell commands. Replacing both .ps1 hooks with `exit 0` and running this
# script produced `GUARD: verified`, rc=0, and a green CI step, which is precisely
# the failure the header says this file exists to detect. It now exits 3, and the
# CI step treats anything non-zero as a failure.
runnable_or_twin() {  # runnable_or_twin <configured command>, sets RUN_CMD
    RUN_CMD="$1"
    interp=${1%% *}
    command -v "$interp" >/dev/null 2>&1 && return 0
    case "$RUN_CMD" in
        *.ps1*)
            twin=${RUN_CMD##* }          # the script path is the last word
            twin=${twin%.ps1}.sh
            if [ -f "$twin" ] && command -v sh >/dev/null 2>&1; then
                echo "  NOTE  '$interp' is not on this machine; testing $twin instead."
                echo "        The wiring above is what is really configured, and the"
                echo "        configured hook is NOT what the cases below exercise."
                RUN_CMD="sh $twin"
                substituted=1
                return 0
            fi ;;
    esac
    echo "  FAIL  the configured command cannot run here and has no runnable POSIX twin: $RUN_CMD"
    fail=1
    return 1
}

# Find the command wired to a matcher that covers a given tool name. Sets a
# variable rather than echoing into a command substitution, and reads via a
# here-doc rather than a pipe: both keep this in the current shell. `$(f)` around
# a `while` in a pipeline puts the loop two subshells deep, which is slow, and on
# Windows/MSYS the fork-and-pipe churn stalls outright partway through a run.
#
# Padding both the matcher and the pattern with `|` means one glob covers a tool
# name wherever it sits in `Edit|MultiEdit|Write|NotebookEdit`, including alone.
FOUND_CMD=""
command_for() {  # command_for <tool name>, sets FOUND_CMD
    FOUND_CMD=""
    while IFS="$TAB" read -r m c; do
        [ -n "$m" ] || continue
        case "|$m|" in
            *"|$1|"*) FOUND_CMD="$c"; return 0 ;;
        esac
    done <<EOF
$pairs
EOF
    return 1
}

check() {  # check <command> <label> <json payload> <expected exit>
    printf '%s' "$3" | sh -c "$1" >/dev/null 2>&1
    rc=$?
    if [ "$rc" = "$4" ]; then
        echo "  PASS  $2 (exit $rc)"
    else
        echo "  FAIL  $2 — expected exit $4, got $rc"
        fail=1
    fi
}

file_case() { check "$1" "$2" "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$3\"}}" "$4"; }
cmd_case()  { check "$1" "$2" "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$3\"}}" "$4"; }

# --- guard 1: manifest FILE edits ------------------------------------------
command_for Edit; file_cmd="$FOUND_CMD"
if [ -z "$file_cmd" ]; then
    echo "FAIL: no PreToolUse hook matches Edit — manifest files are unguarded."
    echo "  Expected a matcher like \"Edit|MultiEdit|Write|NotebookEdit\"."
    fail=1
else
    echo "file guard: $file_cmd"
    command_for Write; write_cmd="$FOUND_CMD"
    if [ "$write_cmd" != "$file_cmd" ]; then
        echo "  FAIL  the matcher covers Edit but not Write — an agent can create a manifest."
        fail=1
    fi
    check_list_size "$file_cmd" GUARDED-MANIFESTS-BEGIN GUARDED-MANIFESTS-END \
        "$GUARDED_FLOOR" "manifest" words
    runnable_or_twin "$file_cmd" && file_cmd="$RUN_CMD"

    echo "guarded paths must be BLOCKED (exit 2):"
    file_case "$file_cmd" "package.json"             "package.json"              2
    file_case "$file_cmd" "yarn.lock"                "yarn.lock"                 2
    file_case "$file_cmd" "Api.csproj"               "src/Api/Api.csproj"        2
    file_case "$file_cmd" "Directory.Packages.props" "Directory.Packages.props"  2
    # Ecosystems the framework ships no stack rules for. The guard covers them
    # anyway: a project whose manifests are unguarded gets no warning that the
    # rule is not being enforced, it just silently is not.
    file_case "$file_cmd" "pyproject.toml"           "pyproject.toml"            2
    file_case "$file_cmd" "requirements-dev.txt"     "requirements-dev.txt"      2
    file_case "$file_cmd" "go.mod"                   "go.mod"                    2
    file_case "$file_cmd" "Cargo.toml"               "Cargo.toml"                2
    file_case "$file_cmd" "Gemfile"                  "Gemfile"                   2
    file_case "$file_cmd" "pom.xml"                  "pom.xml"                   2
    file_case "$file_cmd" "composer.json"            "composer.json"             2
    # One from each part of the list, not five from the front of it: these are the
    # entries a gutted list loses first, and they were all allowed by a list cut
    # down to exactly what this script used to test.
    file_case "$file_cmd" "package-lock.json"        "package-lock.json"         2
    file_case "$file_cmd" ".npmrc"                   ".npmrc"                    2
    file_case "$file_cmd" "go.sum"                   "go.sum"                    2
    file_case "$file_cmd" "global.json"              "global.json"               2
    file_case "$file_cmd" "Dockerfile"               "Dockerfile"                2
    file_case "$file_cmd" ".cargo/config.toml"       ".cargo/config.toml"        2
    # Case-insensitive filesystems: on macOS this writes the real manifest.
    file_case "$file_cmd" "Package.json (case)"      "Package.json"              2
    # The guard's own configuration. Without these an agent that is blocked
    # simply writes the approval marker the block message just named.
    file_case "$file_cmd" "the approval marker"      ".claude/allow-package-changes" 2
    file_case "$file_cmd" "settings.json"            ".claude/settings.json"     2
    file_case "$file_cmd" "the guard script"         ".claude/hooks/guard-packages.sh" 2

    echo "ordinary paths must be ALLOWED (exit 0):"
    file_case "$file_cmd" "src/app.ts"               "src/app.ts"                0
    file_case "$file_cmd" "docs/process/notes.md"    "docs/process/notes.md"     0
    # Near-misses: the guard matches the basename, so neither a manifest name
    # buried in a longer filename nor a directory named after one may block.
    file_case "$file_cmd" "docs/notes-package.json"  "docs/notes-package.json"   0
    file_case "$file_cmd" "vendor/Gemfile/readme.md" "vendor/Gemfile/readme.md"  0
fi

# --- guard 2: install COMMANDS ---------------------------------------------
command_for Bash; inst_cmd="$FOUND_CMD"
if [ -z "$inst_cmd" ]; then
    echo "FAIL: no PreToolUse hook matches Bash — every install path is unguarded."
    echo "  The file guard above only sees Edit/Write against manifest files."
    # Single quotes, not backticks: inside double quotes a backtick is command
    # substitution, and this script would have run 'npm i' while telling you the
    # install guard is missing -- installing a package to report an unguarded
    # install path.
    echo '  npm i, dotnet add package, pip install and go get bypass it entirely.'
    echo "  Add a second PreToolUse entry with matcher \"Bash\" running guard-installs."
    fail=1
else
    echo "install guard: $inst_cmd"
    check_list_size "$inst_cmd" INSTALL-COMMANDS-BEGIN INSTALL-COMMANDS-END \
        "$INSTALL_FLOOR" "install-command" lines
    runnable_or_twin "$inst_cmd" && inst_cmd="$RUN_CMD"
    echo "install commands must be BLOCKED (exit 2):"
    cmd_case "$inst_cmd" "npm install"        "npm install left-pad"       2
    cmd_case "$inst_cmd" "yarn add"           "yarn add zod"               2
    cmd_case "$inst_cmd" "dotnet add package" "dotnet add package Serilog" 2
    cmd_case "$inst_cmd" "pip install"        "pip install requests"       2
    cmd_case "$inst_cmd" "go get"             "go get github.com/x/y"      2
    # Spread across the list rather than clustered at its front, for the reason
    # given above the manifest cases.
    cmd_case "$inst_cmd" "npx"                "npx cowsay hi"              2
    cmd_case "$inst_cmd" "pnpm add"           "pnpm add react"             2
    cmd_case "$inst_cmd" "cargo add"          "cargo add serde"            2
    cmd_case "$inst_cmd" "bun install"        "bun install"                2
    cmd_case "$inst_cmd" "gem install"        "gem install rails"          2
    cmd_case "$inst_cmd" "composer require"   "composer require monolog"   2
    # An option between the tool and its subcommand is a documented invocation,
    # and both implementations allowed it for three releases.
    cmd_case "$inst_cmd" "npm --silent install" "npm --silent install x"   2

    echo "build commands must be ALLOWED (exit 0):"
    cmd_case "$inst_cmd" "npm run build"      "npm run build"              0
    cmd_case "$inst_cmd" "git status"         "git status"                 0

    # --- the install guard's OWN perimeter -----------------------------------
    # This block did not exist. The file guard's self-protection was tested and
    # the install guard's -- roughly ninety lines of it -- was not, so deleting
    # the entire perimeter block from guard-installs and changing nothing else
    # produced `GUARD: verified`, rc=0, while `rm .claude/hooks/guard-packages.sh`
    # and `touch .claude/allow-package-changes` both returned 0. What CI asserts
    # is what stays true; everything else is a comment.
    echo "the guard's own perimeter must be BLOCKED (exit 2):"
    cmd_case "$inst_cmd" "creating the approval marker" \
        "touch .claude/allow-package-changes"                              2
    cmd_case "$inst_cmd" "deleting a hook script" \
        "rm .claude/hooks/guard-packages.sh"                               2
    cmd_case "$inst_cmd" "editing the hook configuration in place" \
        "sed -i s/a/b/ .claude/settings.json"                              2
    cmd_case "$inst_cmd" "overwriting the configuration by redirection" \
        "printf {} > .claude/settings.json"                                2
    # A read earlier in the same command used to move the inspected window off
    # the write that followed it.
    cmd_case "$inst_cmd" "a read before the write does not shelter it" \
        "ls .claude/settings.json && printf {} > .claude/settings.json"    2
    cmd_case "$inst_cmd" "removing the whole directory" \
        "rm -rf .claude"                                                   2

    echo "reading the guard's own files must be ALLOWED (exit 0):"
    cmd_case "$inst_cmd" "reading the configuration" \
        "cat .claude/settings.json"                                        0
    cmd_case "$inst_cmd" "running a hook -- this script does it" \
        "sh .claude/hooks/verify-guard.sh"                                 0
fi

if [ $fail -eq 0 ] && [ $substituted -eq 0 ]; then
    echo "GUARD: verified — manifest edits and install commands are both blocked without approval."
    exit 0
fi
if [ $fail -eq 0 ]; then
    # Everything passed, but not on the hook Claude Code will invoke. Saying
    # "verified" here is the lie this script exists to prevent someone else from
    # telling. Exit 3 rather than 0 or 1: it is not a broken guard, and it is not
    # a verified one either, and CI must not go green on it.
    echo "GUARD: partially verified (configured interpreter absent — the twin was tested,"
    echo "  not the configured hook). The hook Claude Code actually runs is UNTESTED here,"
    echo "  and an unrunnable hook command fails OPEN: Claude Code treats it as a hook"
    echo "  error, not a block. Point settings.json at the interpreter this machine has:"
    echo "    macOS/Linux:  sh .claude/hooks/guard-packages.sh    (matcher: Edit|MultiEdit|Write|NotebookEdit)"
    echo "                  sh .claude/hooks/guard-installs.sh    (matcher: Bash)"
    echo "    Windows:      powershell -NoProfile -File .claude/hooks/guard-packages.ps1"
    echo "                  powershell -NoProfile -File .claude/hooks/guard-installs.ps1"
    exit 3
fi
echo "GUARD: BROKEN — a guard is not enforcing. Fix .claude/settings.json before"
echo "  trusting the package rule; on macOS/Linux the two commands should be:"
echo "  sh .claude/hooks/guard-packages.sh    (matcher: Edit|MultiEdit|Write|NotebookEdit)"
echo "  sh .claude/hooks/guard-installs.sh    (matcher: Bash)"
exit 1
