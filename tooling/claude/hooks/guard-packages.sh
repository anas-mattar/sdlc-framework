#!/usr/bin/env sh
# PreToolUse hook: blocks edits to package manifests/lockfiles unless package
# changes have been approved for the current feature.
#
# Approval = the file .claude/allow-package-changes exists (create it when the
# feature's plan.md approves new packages; delete it after the phase commits).
#
# Exit 2 blocks the tool call and shows stderr to Claude; exit 0 allows it.

input=$(cat)

# Extract the target file path from the tool input JSON.
file_path=$(printf '%s' "$input" | tr -d '\n' | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

case "$file_path" in
    *package.json|*yarn.lock|*package-lock.json|*pnpm-lock.yaml|*.csproj|*packages.config|*Directory.Packages.props)
        if [ -f ".claude/allow-package-changes" ]; then
            exit 0
        fi
        echo "BLOCKED: '$file_path' is a package manifest/lockfile. Adding or changing packages requires approval in the feature's plan.md. If the plan approves it, ask the user to create .claude/allow-package-changes and retry." >&2
        exit 2
        ;;
esac
exit 0
