#!/usr/bin/env sh
# Self-test for the package guard. Run from the PROJECT ROOT after install:
#     sh .claude/hooks/verify-guard.sh
#
# Why this exists: a misconfigured PreToolUse hook fails OPEN. If the command is
# missing or unrunnable the hook exits non-2, which Claude Code treats as a hook
# error rather than a block — so the guard silently stops guarding and nothing
# tells you. This script reads the command actually configured in settings.json
# (not a hardcoded path) and proves it blocks.
#
# Exit 0 = guard verified. Exit 1 = guard broken or untestable.

settings=".claude/settings.json"
[ -f "$settings" ] || { echo "FAIL: $settings not found — run this from the project root."; exit 1; }

cmd=$(grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' "$settings" \
      | head -n 1 | sed 's/^.*:[[:space:]]*"\(.*\)"$/\1/')
[ -n "$cmd" ] || { echo "FAIL: no hook command in $settings — the package guard is not installed."; exit 1; }
echo "hook command: $cmd"

if [ -f .claude/allow-package-changes ]; then
    echo "INCONCLUSIVE: .claude/allow-package-changes exists, so the guard is"
    echo "  intentionally open. Delete it and re-run to test that blocking works."
    exit 1
fi

fail=0

check() {  # check <label> <file_path> <expected_exit>
    payload="{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$2\"}}"
    printf '%s' "$payload" | sh -c "$cmd" >/dev/null 2>&1
    rc=$?
    if [ "$rc" = "$3" ]; then
        echo "  PASS  $1 (exit $rc)"
    else
        echo "  FAIL  $1 — expected exit $3, got $rc"
        fail=1
    fi
}

echo "guarded paths must be BLOCKED (exit 2):"
check "package.json"              "package.json"                2
check "yarn.lock"                 "yarn.lock"                   2
check "Api.csproj"                "src/Api/Api.csproj"          2
check "Directory.Packages.props"  "Directory.Packages.props"    2

echo "ordinary paths must be ALLOWED (exit 0):"
check "src/app.ts"                "src/app.ts"                  0
check "docs/process/notes.md"     "docs/process/notes.md"       0

if [ $fail -eq 0 ]; then
    echo "GUARD: verified — package manifests are blocked without approval."
    exit 0
fi
echo "GUARD: BROKEN — the hook is not enforcing. Fix .claude/settings.json before"
echo "  trusting the package rule; on macOS/Linux the command should be:"
echo "  sh .claude/hooks/guard-packages.sh"
exit 1
