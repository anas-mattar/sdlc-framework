#!/usr/bin/env sh
# Static consistency checks for the framework itself.
#
#     sh tests/framework-checks.sh
#
# The framework ships enforcement to other projects. These checks enforce it here,
# so the repo cannot rot in the ways it warns everyone else about.
#
# Exit 0 = all checks passed (SKIP is not a failure).

set -u
cd "$(dirname "$0")/.." || exit 1

pass=0; fail=0; skip=0
ok()   { pass=$((pass + 1)); printf '  PASS  %s\n' "$1"; }
bad()  { fail=$((fail + 1)); printf '  FAIL  %s\n' "$1"; }
meh()  { skip=$((skip + 1)); printf '  SKIP  %s\n' "$1"; }

# --- 1. PowerShell scripts must be ASCII-only -------------------------------
# Windows PowerShell 5.1 reads UTF-8-without-BOM as ANSI. A single em dash becomes
# three bytes, one of which is a quote, and the script dies with "string is missing
# the terminator". For the package-guard hook that means failing OPEN.
echo "PowerShell encoding"
enc_bad=""
for f in $(find tooling tests -name "*.ps1"); do
    if LC_ALL=C grep -q '[^ -~	]' "$f"; then enc_bad="$enc_bad $f"; fi
done
if [ -z "$enc_bad" ]; then ok "all .ps1 files are ASCII-only"
else bad "non-ASCII in:$enc_bad"; fi

# --- 2. Shell syntax --------------------------------------------------------
echo "Syntax"
sh_bad=""
for f in $(find . -name "*.sh" -not -path "./.git/*"); do
    sh -n "$f" 2>/dev/null || sh_bad="$sh_bad $f"
done
if [ -z "$sh_bad" ]; then ok "all .sh files parse"
else bad "shell syntax errors in:$sh_bad"; fi

# --- 3. PowerShell syntax (only where pwsh exists) --------------------------
if command -v pwsh >/dev/null 2>&1; then
    ps_bad=""
    for f in $(find tooling tests -name "*.ps1"); do
        pwsh -NoProfile -Command "
            \$e = \$null
            [System.Management.Automation.Language.Parser]::ParseFile('$f', [ref]\$null, [ref]\$e) | Out-Null
            if (\$e.Count) { exit 1 }" >/dev/null 2>&1 || ps_bad="$ps_bad $f"
    done
    if [ -z "$ps_bad" ]; then ok "all .ps1 files parse"
    else bad "PowerShell syntax errors in:$ps_bad"; fi
else
    meh "PowerShell syntax (pwsh not installed)"
fi

# --- 4. JSON / YAML validity ------------------------------------------------
echo "Data files"
# Find an interpreter that actually RUNS. On Windows `python3` is usually the
# Microsoft Store app-execution-alias stub: `command -v` finds it, but running it
# prints an ad and exits without being Python. Probe by output, not by existence.
PY=""
for cand in python3 python py; do
    if [ "$("$cand" -c 'print(42)' 2>/dev/null)" = "42" ]; then PY="$cand"; break; fi
done

if [ -n "$PY" ]; then
    if $PY -c "import json; json.load(open('tooling/claude/settings.json'))" 2>/dev/null
    then ok "settings.json is valid JSON"; else bad "settings.json is not valid JSON"; fi

    if $PY -c "import yaml" 2>/dev/null; then
        if $PY -c "import yaml; yaml.safe_load(open('tooling/ci/gate.yml'))" 2>/dev/null
        then ok "gate.yml is valid YAML"; else bad "gate.yml is not valid YAML"; fi
    else
        meh "gate.yml YAML check (pyyaml not installed)"
    fi
else
    meh "JSON/YAML checks (no working python found)"
fi

# --- 5. CHANGELOG covers every release --------------------------------------
echo "Release bookkeeping"
tags=$(git tag 2>/dev/null)
if [ -z "$tags" ]; then
    # Do not report PASS here: with no tags the loop below is vacuous. In CI this
    # means the release tags were never pushed (`git push --tags`), which also
    # breaks /framework-upgrade's drift detection for every clone but the author's.
    meh "CHANGELOG tag coverage (no tags found -- were they pushed?)"
else
    missing=""
    for t in $tags; do
        grep -q "^## ${t#v}\b" CHANGELOG.md || missing="$missing $t"
    done
    if [ -z "$missing" ]; then ok "every git tag has a CHANGELOG entry ($(echo "$tags" | wc -l | tr -d ' ') tags)"
    else bad "no CHANGELOG entry for:$missing"; fi
fi

v=$(tr -d ' \r\n' < VERSION)
if grep -q "^## $v\b" CHANGELOG.md
then ok "VERSION ($v) has a CHANGELOG entry"
else bad "VERSION ($v) has no CHANGELOG entry"; fi

# A VERSION with no matching tag is the failure mode the changelog check cannot
# see: downstream, /framework-upgrade diffs a project's copy against the tagged
# upstream tree, so an untagged release is invisible to every consumer -- the
# version exists in the file and nowhere a tool can reach. Unreleased work in
# progress is legitimate, so mark it: put `## X.Y.Z (unreleased)` in CHANGELOG.md
# and this check stands down until the tag lands.
if [ -n "$tags" ]; then
    if echo "$tags" | grep -qx "v$v"; then
        ok "VERSION ($v) has a git tag (v$v)"
    elif grep -qiE "^## $v\b.*\(unreleased\)" CHANGELOG.md; then
        meh "VERSION ($v) is marked unreleased -- tag it before publishing"
    else
        bad "VERSION ($v) has a CHANGELOG entry but no git tag v$v -- /framework-upgrade cannot reach it"
    fi
fi

# --- 6. Internal markdown links resolve -------------------------------------
echo "Cross-references"
linkfile=$(mktemp)
for f in $(find . -name "*.md" -not -path "./.git/*"); do
    d=$(dirname "$f")
    grep -oE '\]\([^)#]+\.md\)' "$f" 2>/dev/null | sed 's/](\(.*\))/\1/' | while read -r l; do
        case "$l" in http*|/*) continue ;; esac
        [ -e "$d/$l" ] || printf '%s -> %s\n' "$f" "$l" >> "$linkfile"
    done
done
if [ ! -s "$linkfile" ]; then ok "all internal .md links resolve"
else bad "broken links:"; sed 's/^/          /' "$linkfile"; fi
rm -f "$linkfile"

# NOTE: there is deliberately no "unfilled {{placeholder}}" check here.
# {{BACKEND_DIR}} and friends are legitimate throughout this repo -- the review
# templates, branch-strategy.md and the gate scripts all ship placeholders that a
# project fills at install. An unfilled placeholder is only a defect in an
# *installed* project, which is where the check lives: /framework-doctor check 2.

# --- 7. Layer discipline (ratchet) ------------------------------------------
# README: "if a sentence mentions a specific product, domain, or system by name,
# it belongs in layer 3." Layers 1 and 2 were extracted from the WMS project and
# carried its vocabulary for twelve releases; they are now clean, so the baseline
# is 0 and ANY reintroduction fails.
#
# The pattern also covers the project-specific identifiers that used to appear in
# the stack rules (`featcher` -- a misspelling of "fetcher" -- `purshase`, `poms`),
# so a copy-paste from a WMS codebase is caught rather than quietly re-entering
# layer 2. Extend the pattern with your own product's terms when you fork this.
echo "Layer discipline"
BASELINE=0
count=$(grep -rniE '\bwms\b|dpointernational|featcher|purshase|\bpoms\b' process/ stacks/ modules/ 2>/dev/null | wc -l | tr -d ' ')
if [ "$count" -le "$BASELINE" ]; then
    ok "layer 1/2 product references: $count (baseline $BASELINE)"
    [ "$count" -lt "$BASELINE" ] && printf '        note: improved -- lower BASELINE in %s to %s\n' "$0" "$count"
else
    bad "layer 1/2 product references rose to $count (baseline $BASELINE)"
    grep -rniE '\bwms\b|dpointernational|featcher|purshase|\bpoms\b' process/ stacks/ modules/ 2>/dev/null | sed 's/^/          /'
fi

# --- 8. No dependency on an unshipped constitution (ratchet) ----------------
# Layers 1 and 2 used to cite constitution principles (I, X, XVI, XVII) as the
# authority behind the Definition of Done and the review templates -- a document
# this framework never ships and never installs. A consuming project therefore
# received rules deferring to an authority that did not exist, and the DoD said
# that missing document PREVAILED over itself. The rules are now self-contained.
#
# Referring to a project's own governing document as OPTIONAL context is fine;
# citing a principle NUMBER is not, because a number is only meaningful against a
# specific document the framework cannot see. So the pattern targets the numerals.
echo "Self-contained authority"
CONST_BASELINE=0
const_count=$(grep -rnE 'constitution[[:space:]]+\**[IVX]+\b|\bprinciple[[:space:]]+\**[IVX]+\b' \
    process/ stacks/ modules/ tooling/ 2>/dev/null | wc -l | tr -d ' ')
if [ "$const_count" -le "$CONST_BASELINE" ]; then
    ok "citations of unshipped constitution principles: $const_count (baseline $CONST_BASELINE)"
else
    bad "layer 1/2 cites constitution principle numbers ($const_count) -- the framework ships no constitution"
    grep -rnE 'constitution[[:space:]]+\**[IVX]+\b|\bprinciple[[:space:]]+\**[IVX]+\b' \
        process/ stacks/ modules/ tooling/ 2>/dev/null | sed 's/^/          /'
fi

# --- 9. The example install is actually installed ---------------------------
# examples/ exists to show what a finished install looks like. An example with a
# live {{PLACEHOLDER}} in it teaches the single mistake /framework-doctor exists to
# catch (check 2), so the example is held to the standard it demonstrates.
echo "Example install"
if [ -d examples ]; then
    ex_bad=$(grep -rl '{{[A-Z_]*}}' examples/ 2>/dev/null)
    if [ -z "$ex_bad" ]; then ok "no unfilled placeholders in examples/"
    else bad "unfilled placeholders in:"; echo "$ex_bad" | sed 's/^/          /'; fi
else
    meh "example install (examples/ not present)"
fi

# --- 10. The two package guards agree -------------------------------------
# The guard is implemented twice, once per platform. Nothing forces the two
# pattern lists to match, and a manifest guarded on Windows but not on macOS is
# the worst kind of bug: it works for whoever wrote it. Both files delimit their
# list with GUARDED-MANIFESTS-BEGIN/END so it can be compared mechanically.
echo "Package guard parity"
extract_block() { sed -n '/GUARDED-MANIFESTS-BEGIN/,/GUARDED-MANIFESTS-END/p' "$1"; }
sh_pats=$(extract_block tooling/claude/hooks/guard-packages.sh \
    | sed '1d;$d' | tr -d '"' | sed 's/^GUARDED=//' | tr ' \t' '\n\n' | grep -v '^$' | sort -u)
ps_pats=$(extract_block tooling/claude/hooks/guard-packages.ps1 \
    | grep -oE "'[^']+'" | tr -d "'" | sort -u)

if [ -z "$sh_pats" ] || [ -z "$ps_pats" ]; then
    bad "could not extract the guard pattern list from one or both hooks"
elif [ "$sh_pats" = "$ps_pats" ]; then
    ok "guard-packages.sh and .ps1 guard the same $(echo "$sh_pats" | wc -l | tr -d ' ') patterns"
else
    bad "guard-packages.sh and .ps1 guard different patterns:"
    printf '%s\n' "$sh_pats" > "${TMPDIR:-/tmp}/gp-sh.$$"
    printf '%s\n' "$ps_pats" > "${TMPDIR:-/tmp}/gp-ps.$$"
    diff "${TMPDIR:-/tmp}/gp-sh.$$" "${TMPDIR:-/tmp}/gp-ps.$$" | sed 's/^/          /'
    rm -f "${TMPDIR:-/tmp}/gp-sh.$$" "${TMPDIR:-/tmp}/gp-ps.$$"
fi

# --- 11. The shell guard actually blocks ------------------------------------
# verify-guard.* proves the guard works in an INSTALLED project, against the
# command configured there. This proves the shipped script itself blocks and
# allows the right paths, before it is ever installed anywhere. A guard failing
# open is the one defect that hides itself.
echo "Package guard behavior"
guard_case() {  # guard_case <file_path> <expected_exit>
    printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$1" \
        | sh tooling/claude/hooks/guard-packages.sh >/dev/null 2>&1
    [ "$?" = "$2" ]
}
g_bad=""
for c in "package.json:2" "src/Api/Api.csproj:2" "pyproject.toml:2" "go.mod:2" \
         "Cargo.toml:2" "Gemfile:2" "requirements-dev.txt:2" \
         "src/app.ts:0" "docs/notes-package.json:0" "vendor/Gemfile/readme.md:0"; do
    guard_case "${c%:*}" "${c##*:}" || g_bad="$g_bad ${c%:*}"
done
if [ -z "$g_bad" ]; then ok "guard blocks manifests and allows ordinary files (10 cases)"
else bad "guard gave the wrong answer for:$g_bad"; fi

echo
echo "passed=$pass failed=$fail skipped=$skip"
[ "$fail" -eq 0 ] || exit 1
