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

# Pair each matcher with the command configured under it, inside hooks.PreToolUse
# and nowhere else. This is a line-oriented read rather than a JSON parse: an
# installed project has no guaranteed interpreter, and settings.json ships one key
# per line. Minified JSON collapses to a single line and is reported, not misread.
#
# BRACE DEPTH, NOT A BOOLEAN. The previous version set a flag on any line matching
# /"PreToolUse"/ and cleared it on any line naming another hook event. It had no
# idea where in the document it was, so matcher/command pairs found ANYWHERE after
# such a line counted -- including inside a decoy object the JSON parser never
# reads. settings.json already carries a top-level "$comment", so an "$examples"
# sibling holding a well-formed PreToolUse block is idiomatic rather than
# suspicious, and this file certified it:
#
#     "$examples": { "PreToolUse": { "file guard": {
#         "matcher": "Edit|MultiEdit|Write|NotebookEdit",
#         "command": "sh .claude/hooks/guard-packages.sh" } } },
#     "hooks": { "PreToolUse": [ { "matcher": "Read", "hooks": [ ... ] } ] }
#
# What Claude Code installs there is one hook on `Read`, which edits nothing, and
# no Bash matcher at all -- every manifest edit and every install command
# unguarded, reported as `GUARD: verified`, with CI green behind it. The matcher IS
# checked now; it was being checked against a matcher that does not exist.
#
# So: find `"hooks"`, then `"PreToolUse"` beneath it, and accept pairs only while
# still inside that subtree. Depth is counted by braces and brackets on each line,
# which is sound for one-key-per-line JSON and is why minified input is refused
# rather than read.
pairs=$(awk '
    # Depth BEFORE this line is the running total; the key on a line belongs to the
    # object that encloses it, so test membership first, then update.
    {
        inhooks = (hooks_depth >= 0 && depth > hooks_depth)
        inpre   = (pre_depth   >= 0 && depth > pre_depth   && inhooks)
    }
    NR == 1 { hooks_depth = -1; pre_depth = -1 }
    /"hooks"[[:space:]]*:/ && hooks_depth < 0 { hooks_depth = depth }
    /"PreToolUse"[[:space:]]*:/ {
        if (inhooks && pre_depth < 0) pre_depth = depth
        else if (!inhooks) stray_event = NR
    }
    # A nested "hooks": [ ... ] array inside an entry is part of the subtree, so it
    # must not reset hooks_depth -- guarded by the `< 0` test above.
    inpre && /"matcher"[[:space:]]*:/   { m = $0; sub(/.*"matcher"[^"]*"/, "", m); sub(/".*/, "", m) }
    inpre && /"command"[[:space:]]*:/   { c = $0; sub(/.*"command"[^"]*"/, "", c); sub(/".*/, "", c)
                                          if (m != "") print m "\t" c }
    # Any matcher or command OUTSIDE the real hooks subtree is the decoy shape.
    # Report it rather than ignoring it: a settings.json carrying a second,
    # plausible-looking hook block is either an attack or a copy-paste that someone
    # believes is live, and both are worth stopping on.
    !inpre && /"(matcher|command)"[[:space:]]*:/ { stray_pair = NR }
    { n = gsub(/[{[]/, "&"); m2 = gsub(/[}\]]/, "&"); depth += n - m2 }
    END {
        if (stray_pair) printf "STRAY\t%d\n", stray_pair
        if (stray_event) printf "STRAYEVENT\t%d\n", stray_event
    }
' "$settings")

# Minified JSON is depth-counted on a single line, so every key looks like it sits
# outside the subtree and the stray-pair message below would be technically true
# and useless. Name the real problem instead; this is a plausible accident (a
# formatter, a `jq -c`), not an attack.
if [ "$(grep -c '' "$settings")" -le 2 ] && grep -q '"PreToolUse"' "$settings"; then
    echo "FAIL: $settings is minified onto one line, and this script reads it line by line."
    echo "  It cannot tell which keys are inside hooks.PreToolUse and which are not,"
    echo "  so it refuses to guess. Reformat it one key per line and re-run."
    exit 1
fi

stray=$(printf '%s\n' "$pairs" | sed -n 's/^STRAY\(EVENT\)\?	//p' | head -1)
if [ -n "$stray" ]; then
    echo "FAIL: $settings has \"matcher\"/\"command\" keys outside hooks.PreToolUse"
    echo "  (first at line $stray). Claude Code reads only hooks.PreToolUse, so a"
    echo "  hook block anywhere else is not installed no matter how correct it looks."
    echo "  This script used to read those keys and certify them. Delete the block,"
    echo "  or move it under \"hooks\" if it was meant to be live."
    exit 1
fi
pairs=$(printf '%s\n' "$pairs" | grep -v '^STRAY')

if [ -z "$pairs" ]; then
    echo "FAIL: no PreToolUse hook found in $settings — the package guards are not installed."
    echo "  (If your settings.json is minified onto one line, reformat it one key per line.)"
    exit 1
fi

TAB=$(printf '\t')
fail=0
substituted=0   # a DIFFERENT script was run than the one configured
unpinned=0      # the lists could only be counted, not pinned by digest

# --- the lists must still be the lists that shipped --------------------------
# Behavioural cases can only ever sample. Cutting INSTALL_COMMANDS down to exactly
# the handful this script exercises left it printing GUARD: verified while
# `npx cowsay`, `pnpm add react`, `cargo add serde`, `bun install`, `gem install
# rails` and `composer require` all returned 0 -- an 85% cut, certified. The
# framework's 99-case fixture would catch that, but that fixture lives in the
# framework repository, not in an installed project, where THIS script is the only
# mechanical check there is.
#
# A COUNT WAS NOT ENOUGH, and the fix for that finding is the finding one layer
# down. The previous version asserted a floor -- 86 manifest patterns, 56 install
# commands -- which detects DELETION and not SUBSTITUTION. Keeping the twelve
# commands this script exercises, replacing the other forty-four with `zzjunk00`
# and leaving the line count at 56, produced:
#
#     PASS  manifest list has 86 entries (floor 86)
#     PASS  install-command list has 56 entries (floor 56)
#     GUARD: verified
#
# while `npm ci`, `yarn install`, `uv add`, `poetry add`, `bundle add`, `conda
# install`, `pipx install`, `go install`, `yarn upgrade` and `pnpm dlx` were all
# open. So the lists are pinned by DIGEST, not by length: changing one means
# changing a hash here, in the same diff, where a reviewer sees it. That is the
# same argument .gate-sha256 makes about the gate script.
#
# FOUR digests, not two. The configured command may name either twin -- and on the
# shipped default it names the .ps1, because that is the platform where the POSIX
# form fails open. Pinning only the .sh lists made the shipped Windows wiring
# report BROKEN on a healthy install, which is the cry-wolf failure that gets a
# verifier deleted. Each twin's list block is pinned on its own terms, so the .ps1
# lists are now covered too -- they never were.
#
# Regenerate after a legitimate list change with:
#     sh .claude/hooks/verify-guard.sh --print-digests
GUARDED_DIGEST_SH=c68dc68623405006f36b034cf73dcc70282b0442ec9af1eaed1e5b6f3c0980a7
INSTALL_DIGEST_SH=704bb73f2bf79e6ed895603f7a46718ec1900b33d0a1129d4d198e404617875d
GUARDED_DIGEST_PS1=04617cf3a9f4d77f189fc678f38dab71890c74897cde76a2e7bd608c4a3a5aff
INSTALL_DIGEST_PS1=ece8b32bc36ed29552439b3865cace270d469fddb5cc63e7486ec848e331f0c9
# Kept as a floor of last resort for the no-digest-tool case below. These are not
# the assertion any more; they are what is left when there is nothing to hash with.
GUARDED_FLOOR=86
INSTALL_FLOOR=63

# No digest tool is guaranteed. coreutils gives sha256sum, macOS gives
# `shasum -a 256`, and openssl is usually somewhere. If none of the three exists we
# do NOT silently fall back to the count and call it verified -- that is the exact
# move this whole file exists to argue against. We fall back, say so, and exit 3.
digest_tool=""
if   command -v sha256sum >/dev/null 2>&1; then digest_tool="sha256sum"
elif command -v shasum    >/dev/null 2>&1; then digest_tool="shasum -a 256"
elif command -v openssl   >/dev/null 2>&1; then digest_tool="openssl dgst -sha256"
fi

# The list body, normalised so a digest survives the things that legitimately
# differ between checkouts: CR line endings, trailing whitespace, blank lines, and
# comment lines (which are prose and may be re-wrapped without changing behaviour).
list_body() {  # list_body <hook script> <begin marker> <end marker>
    [ -f "$1" ] || return 0
    sed -n "/$2/,/$3/p" "$1" | sed '1d;$d' \
        | tr -d '\r' \
        | grep -v '^[[:space:]]*#' \
        | sed 's/[[:space:]]*$//' \
        | grep -v '^[[:space:]]*$'
}

list_digest() {  # list_digest <hook script> <begin> <end>
    [ -n "$digest_tool" ] || return 1
    list_body "$1" "$2" "$3" | $digest_tool 2>/dev/null | tr -d ' *-' | cut -c1-64
}

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

check_list_size() {  # check_list_size <cmd> <begin> <end> <digest var prefix> <label> <words|lines> <floor>
    # The script is the last word of the configured command -- the same
    # assumption runnable_or_twin makes.
    script=${1##* }
    n=$(list_size "$script" "$2" "$3" "$6")
    # Pick the digest belonging to the twin actually configured.
    case "$script" in
        *.ps1) eval "want=\$${4}_PS1" ;;
        *)     eval "want=\$${4}_SH"  ;;
    esac
    set -- "$1" "$2" "$3" "$want" "$5" "$6" "$7"

    if [ -z "$digest_tool" ]; then
        # Honest degradation: the count still catches wholesale deletion, and the
        # exit status says the strong check did not run.
        if [ "$n" -ge "$7" ]; then
            echo "  WARN  $5 list has $n entries (floor $7) -- counted, NOT pinned:"
            echo "        no sha256sum, shasum or openssl on this machine, so a list"
            echo "        whose entries were REPLACED rather than removed would pass."
            unpinned=1
        else
            echo "  FAIL  $5 list has $n entries, expected at least $7 -- $script has been cut down."
            fail=1
        fi
        return
    fi

    actual=$(list_digest "$script" "$2" "$3")
    if [ "$actual" = "$4" ]; then
        echo "  PASS  $5 list matches the digest it shipped with ($n entries)"
    else
        echo "  FAIL  $5 list does not match the digest it shipped with."
        echo "        expected $4"
        echo "        actual   $actual   ($n entries)"
        echo "        $script has been edited. A count would not have caught this:"
        echo "        entries can be REPLACED without changing how many there are,"
        echo "        and the behavioural cases below only sample the list."
        echo "        If the change is intended, regenerate with:"
        echo "            sh .claude/hooks/verify-guard.sh --print-digests"
        fail=1
    fi
}

# Regenerating the constants has to be one command, or it becomes a thing people
# work around by deleting the check.
if [ "${1:-}" = "--print-digests" ]; then
    if [ -z "$digest_tool" ]; then
        echo "No sha256sum, shasum or openssl on this machine — cannot compute digests."
        exit 1
    fi
    echo "Paste these into verify-guard.sh (and verify-guard.ps1):"
    echo "GUARDED_DIGEST_SH=$(list_digest .claude/hooks/guard-packages.sh GUARDED-MANIFESTS-BEGIN GUARDED-MANIFESTS-END)"
    echo "INSTALL_DIGEST_SH=$(list_digest .claude/hooks/guard-installs.sh INSTALL-COMMANDS-BEGIN INSTALL-COMMANDS-END)"
    echo "GUARDED_DIGEST_PS1=$(list_digest .claude/hooks/guard-packages.ps1 GUARDED-MANIFESTS-BEGIN GUARDED-MANIFESTS-END)"
    echo "INSTALL_DIGEST_PS1=$(list_digest .claude/hooks/guard-installs.ps1 INSTALL-COMMANDS-BEGIN INSTALL-COMMANDS-END)"
    exit 0
fi

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
        GUARDED_DIGEST "manifest" words "$GUARDED_FLOOR"
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
        INSTALL_DIGEST "install-command" lines "$INSTALL_FLOOR"
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

if [ $fail -eq 0 ] && [ $substituted -eq 0 ] && [ $unpinned -eq 0 ]; then
    echo "GUARD: verified — manifest edits and install commands are both blocked without approval."
    exit 0
fi
if [ $fail -eq 0 ] && [ $substituted -eq 0 ] && [ $unpinned -eq 1 ]; then
    # Behaviour passed and the wiring is right, but the lists were counted rather
    # than pinned, so a substitution would have gone unnoticed. Name THAT, rather
    # than reusing the interpreter message below: a diagnosis that misidentifies
    # the problem sends the reader to fix the wrong thing, and this script's whole
    # purpose is to be believed.
    echo "GUARD: partially verified (the guard lists could not be pinned — this"
    echo "  machine has no sha256sum, shasum or openssl). The behavioural cases"
    echo "  passed and the wiring is correct, but the lists were only COUNTED, and"
    echo "  a count cannot tell a replaced entry from an original one. Install"
    echo "  coreutils (or openssl) and re-run before trusting the guard lists."
    exit 3
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
