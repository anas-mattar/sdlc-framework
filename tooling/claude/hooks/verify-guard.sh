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
    echo "install commands must be BLOCKED (exit 2):"
    cmd_case "$inst_cmd" "npm install"        "npm install left-pad"       2
    cmd_case "$inst_cmd" "yarn add"           "yarn add zod"               2
    cmd_case "$inst_cmd" "dotnet add package" "dotnet add package Serilog" 2
    cmd_case "$inst_cmd" "pip install"        "pip install requests"       2
    cmd_case "$inst_cmd" "go get"             "go get github.com/x/y"      2

    echo "build commands must be ALLOWED (exit 0):"
    cmd_case "$inst_cmd" "npm run build"      "npm run build"              0
    cmd_case "$inst_cmd" "git status"         "git status"                 0
fi

if [ $fail -eq 0 ]; then
    echo "GUARD: verified — manifest edits and install commands are both blocked without approval."
    exit 0
fi
echo "GUARD: BROKEN — a guard is not enforcing. Fix .claude/settings.json before"
echo "  trusting the package rule; on macOS/Linux the two commands should be:"
echo "  sh .claude/hooks/guard-packages.sh    (matcher: Edit|MultiEdit|Write|NotebookEdit)"
echo "  sh .claude/hooks/guard-installs.sh    (matcher: Bash)"
exit 1
