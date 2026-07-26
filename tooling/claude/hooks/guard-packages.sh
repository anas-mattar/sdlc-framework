#!/usr/bin/env sh
# PreToolUse hook: blocks edits to package manifests/lockfiles unless package
# changes have been approved for the current feature.
#
# Approval = the file .claude/allow-package-changes exists (create it when the
# feature's plan.md approves new packages; delete it after the phase commits).
#
# Exit 2 blocks the tool call and shows stderr to Claude; exit 0 allows it.
#
# The pattern list below is DELIBERATELY broader than the stacks this framework
# ships rules for. A guard that only knows package.json and *.csproj installs
# cleanly on a Python or Go project, reports GUARD: verified, and then permits
# every dependency change silently -- an enforcement gap that looks like
# enforcement. Guarding a manifest costs nothing on a project that has none.
#
# The identical list lives in guard-packages.ps1; tests/framework-checks.sh fails
# the build if the two drift apart.

input=$(cat)

# Extract the target file path from the tool input JSON.
file_path=$(printf '%s' "$input" | tr -d '\n' | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
[ -n "$file_path" ] || exit 0

# Match on the basename, not the whole path: a directory called `vendor/Gemfile/`
# is not a manifest, and `docs/notes-package.json` should not slip through a
# suffix match. Strip both separators -- Claude Code reports Windows paths with
# backslashes.
name=${file_path##*/}
name=${name##*\\}

# --- the guard guards itself ------------------------------------------------
# Everything this control depends on lives inside the perimeter the agent
# controls: the approval marker, the hook configuration, and the hook script. None
# of them is a package manifest, so without this block a blocked agent can simply
# Write `.claude/allow-package-changes` -- whose exact filename the block message
# below helpfully supplies -- and the guard is permanently open in one tool call.
# /framework-doctor check 5 finds the residue afterwards, but it runs after setup
# and after upgrade, never during phase work, and the marker can be deleted once
# the edit has landed. So the block has to be here, at the moment of the write.
# Claude Code reports Windows paths with backslashes, and they arrive JSON-escaped
# as `\\`, so folding them one-for-one yields `C://proj//.claude//settings.json`.
# Squeeze the repeats or none of the patterns below match on Windows -- the
# platform this guard is shipped configured for.
#
# Fold and squeeze in ONE sed rather than two `tr` calls. This hook runs on every
# Edit and Write, so each avoided process is paid back thousands of times -- and on
# Windows/MSYS, where fork is expensive, a chain of small helpers is what makes a
# long verify-guard run stall partway through.
norm=$(printf '%s' "$file_path" | sed 's|\\|/|g; s|//*|/|g')
case "$norm" in
    *.claude/allow-package-changes|*.claude/settings*.json|*.claude/hooks/*)
        echo "BLOCKED: '$file_path' is part of the package guard itself (its approval marker, its configuration, or its hook script). Only a human creates or edits these. If package changes are genuinely approved in the feature's plan.md (or spec.md at Small tier), ask the user to create the marker -- do not create it yourself." >&2
        exit 2
        ;;
esac

# GUARDED-MANIFESTS-BEGIN
GUARDED="package.json package-lock.json npm-shrinkwrap.json yarn.lock
pnpm-lock.yaml pnpm-workspace.yaml bun.lockb bun.lock deno.json deno.jsonc
deno.lock *.csproj *.fsproj *.vbproj *.nuspec packages.config
Directory.Packages.props Directory.Build.props paket.dependencies paket.lock
pyproject.toml requirements*.txt *-requirements.txt Pipfile Pipfile.lock
poetry.lock uv.lock setup.py setup.cfg environment.yml go.mod go.sum
Cargo.toml Cargo.lock pom.xml build.gradle build.gradle.kts settings.gradle
settings.gradle.kts libs.versions.toml build.sbt composer.json composer.lock
Gemfile Gemfile.lock *.gemspec Package.swift Package.resolved Podfile
Podfile.lock Cartfile Cartfile.resolved pubspec.yaml pubspec.lock mix.exs
mix.lock"
# GUARDED-MANIFESTS-END

# Match case-insensitively, by folding both sides once. `case` is case-sensitive
# and PowerShell's `-like` is not, so the two guards used to disagree: `Package.json`
# was blocked on Windows and allowed on macOS/Linux. On case-insensitive macOS --
# which is exactly where this framework directs users to the .sh hook -- that wrote
# the real manifest straight past the guard. The parity self-test compares the
# pattern STRINGS, so it passed throughout. Fold once, not once per pattern: this
# hook runs on every Edit and Write.
# One `tr` for both, split back apart with parameter expansion -- see the note
# above about process count. The blank separator line cannot appear inside either
# value, so the split is unambiguous.
folded=$(printf '%s\n\n%s' "$name" "$GUARDED" | tr 'A-Z' 'a-z')
lname=${folded%%"

"*}
lguarded=${folded#*"

"}

# `set -f` is required: without it the `for` list undergoes pathname expansion,
# so `*.csproj` silently becomes whatever .csproj files happen to be in the
# working directory -- and the pattern itself is lost.
set -f
for pat in $lguarded; do
    case "$lname" in
        $pat)
            [ -f ".claude/allow-package-changes" ] && exit 0
            echo "BLOCKED: '$file_path' is a package manifest/lockfile. Adding or changing packages requires approval in the feature's plan.md (or spec.md on Small-tier projects, which have no plan.md). If the approved spec covers it, ask the user to create .claude/allow-package-changes and retry." >&2
            exit 2
            ;;
    esac
done
set +f

exit 0
