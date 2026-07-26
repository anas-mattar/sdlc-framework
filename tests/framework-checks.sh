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
#
# Strip CR first. .ps1 files are checked out CRLF by design (see .gitattributes),
# and `\r` is outside the printable-ASCII range, so without this the check reports
# a line-ending STYLE as an encoding defect -- flagging files whose actual content
# is clean, on every Windows clone. Conflating the two makes the check cry wolf,
# and a check that cries wolf gets ignored along with the ones that matter.
echo "PowerShell encoding"
enc_bad=""
for f in $(find tooling tests -name "*.ps1"); do
    if LC_ALL=C tr -d '\r' < "$f" | LC_ALL=C grep -q '[^ -~	]'; then enc_bad="$enc_bad $f"; fi
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
    # With no tags the loop below is vacuous, so PASS would be a lie. Locally a
    # shallow or partial clone is a plausible cause, so this is a SKIP. In CI it
    # is not: selftest.yml fetches with depth 0, so no tags means they were never
    # pushed -- and /framework-upgrade diffs a project's copy against the tagged
    # upstream tree, so an untagged release is unreachable for every consumer.
    # A skipped check in CI is a check that is not running.
    if [ -n "${CI:-}" ]; then
        bad "no git tags found in CI -- release tags were never pushed (git push --tags); /framework-upgrade cannot reach any release"
    else
        meh "CHANGELOG tag coverage (no tags found -- were they pushed?)"
    fi
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

# --- 6. Internal file references resolve ------------------------------------
# This check used to look for markdown links -- `](some/file.md)`. The repository
# contains ZERO of those and several hundred BACKTICKED path references, so it
# iterated an empty set and printed PASS having examined nothing: the framework's
# own named worst failure mode ("a guard that quietly ignores go.mod is worse than
# no guard, because it reports itself as verified"), running inside its own suite.
#
# Docs are written from the INSTALLED project's point of view, so a reference to
# `docs/process/definition-of-done.md` has to be resolved back to its upstream
# home at process/definition-of-done.md. That mapping is the whole check.
echo "Cross-references"

# Sets $CAND rather than echoing it. `for c in $(resolve_ref ...)` forks a subshell
# per reference, and 216 forks cost forty seconds on Windows -- slow enough that
# the suite stops being run, which is the same outcome as not having the check.
# Where a mapping lands in a directory whose name the install rewrites, resolve to
# the basename: the glob would only ever span one level anyway.
#
# Write referenced paths plainly. `docs/process/../ADOPTION.md` is not normalised
# here on purpose -- a path that walks back out of the directory it names is
# harder to read than the file it points at, and it should be written as such.
resolve_ref() {  # resolve_ref <referenced path>, sets CAND
    case "$1" in
        docs/process/*)        CAND="process/${1#docs/process/}" ;;
        docs/stack-*/*)        CAND="${1##*/}" ;;
        docs/stacks/*/*)       CAND="${1##*/}" ;;
        docs/project/*)        CAND="tooling/project-docs/${1##*/}" ;;
        docs/contracts/*)      CAND="modules/contracts/${1##*/}" ;;
        docs/business/*)       CAND="${1##*/}" ;;
        .claude/commands/*)    CAND="tooling/claude/commands/${1#.claude/commands/}" ;;
        .claude/hooks/*)       CAND="tooling/claude/hooks/${1#.claude/hooks/}" ;;
        .claude/settings.json) CAND="tooling/claude/settings.json" ;;
        gate.sh)               CAND="tooling/gate/gate-node.sh" ;;
        gate.ps1)              CAND="tooling/gate/gate-node.ps1" ;;
        *)                     CAND="$1" ;;
    esac
}

# References that legitimately do not resolve to a file in THIS repository.
# Enumerated by name, never by wildcard: every entry is a reference the check
# stops verifying, so a loose pattern here quietly re-creates the hole this check
# was rewritten to close. Two kinds only --
#
#   1. artifacts an installed project creates per feature or per install
#   2. files belonging to other tools, named in prose as examples
#
# If a reference is neither, it must resolve. `rollback.md` sat in category 3 --
# "named by a mandatory checklist and shipped nowhere" -- until the reference was
# made explicit, which is exactly the class of defect this check exists to find.
is_expected_unresolvable() {
    case "$1" in
        # 1. per-feature and per-install artifacts
        specs/*|docs/roadmap/*|docs/prototypes/*|docs/architecture.md|\
        .gate-result.json|.claude/allow-package-changes|CLAUDE.md|\
        spec.md|plan.md|tasks.md|status.md|research.md|notes.md|rollback.md|\
        ai-code-review.md|human-pr-review.md) return 0 ;;
        # 2. other tools' files, named as examples. Listed case-sensitively:
        # `Package.json` appears in prose about the case-insensitive guard bug,
        # and spelling it out is clearer than folding case for every lookup.
        package.json|Package.json|package-lock.json|appsettings.json|\
        settings.local.json|AGENTS.md|docs/notes-package.json) return 0 ;;
    esac
    return 1
}

# Index the tree ONCE. Resolving each reference with its own `find` took about a
# minute on Windows -- and a self-test slow enough to skip is a self-test that
# does not run. Two newline-delimited strings, matched with `case`, cost nothing
# per lookup and no subprocesses at all.
NL='
'
PATHS=$(find . -type f -not -path './.git/*' | sed 's|^\./||')
PATHS="$NL$PATHS$NL"
BASES=$(printf '%s' "$PATHS" | sed 's|.*/||')
BASES="$NL$BASES$NL"

exists() {  # exists <upstream path or bare basename>
    case "$1" in
        */*) case "$PATHS" in *"$NL$1$NL"*) return 0 ;; esac ;;
        *)   case "$BASES" in *"$NL$1$NL"*) return 0 ;; esac ;;
    esac
    return 1
}

TAB=$(printf '\t')

# Extract every backticked reference that looks like a path -- a known extension,
# no spaces, no globs, no unfilled placeholders -- in ONE grep pass. Running grep
# per file cost a fork per file; on Windows that is most of the check's runtime.
reffile=$(mktemp)
checked=0
find . -name "*.md" -not -path "./.git/*" -not -path "./examples/*" -print0 2>/dev/null \
    | xargs -0 grep -oHE '`[A-Za-z0-9_][A-Za-z0-9_./-]*\.(md|sh|ps1|json|yml|yaml)`' 2>/dev/null \
    | tr -d '`' | sed "s/:/$TAB/" | sort -u > "$reffile"

missing=""
# IFS is assigned OUTSIDE the loop. Written as `while IFS="$(printf '\t')" read`,
# the substitution re-runs on every iteration -- a fork per reference, and fifteen
# seconds of the check's runtime for a value that never changes.
while IFS="$TAB" read -r src ref; do
    case "$ref" in *'{{'*|*'*'*) continue ;; esac
    [ -n "$ref" ] || continue
    checked=$((checked + 1))
    is_expected_unresolvable "$ref" && continue
    found=""
    resolve_ref "$ref"
    exists "$CAND" && found=1
    # A bare filename may legitimately live anywhere in the tree.
    if [ -z "$found" ]; then
        case "$ref" in
            */*) : ;;
            *) exists "$ref" && found=1 ;;
        esac
    fi
    [ -n "$found" ] || missing="$missing
$src -> $ref"
done < "$reffile"

# Ratcheted, like the layer-discipline check: the remaining unresolvable
# references are real and tracked below, and this number must only ever fall.
REF_BASELINE=0
# grep -c prints 0 and exits 1 when nothing matches; the printed value is what we
# want, so do not add a `|| echo 0` fallback -- it appends a second line and the
# arithmetic below then fails on "0\n0".
miss_count=$(printf '%s\n' "$missing" | grep -c ' -> ')
if [ "$miss_count" -le "$REF_BASELINE" ]; then
    ok "internal file references resolve ($checked checked, $miss_count unresolved, baseline $REF_BASELINE)"
else
    bad "unresolvable file references: $miss_count (baseline $REF_BASELINE)"
    printf '%s\n' "$missing" | grep ' -> ' | sort -u | sed 's/^/          /'
fi
rm -f "$reffile"

# NOTE: there is deliberately no "unfilled {{placeholder}}" check here.
# {{BACKEND_DIR}} and friends are legitimate throughout this repo -- the review
# templates, branch-strategy.md and the gate scripts all ship placeholders that a
# project fills at install. An unfilled placeholder is only a defect in an
# *installed* project, which is where the check lives: /framework-doctor check 2.

# --- 7a. Layer discipline, structurally -------------------------------------
# README claims "nothing in process/ names a language or framework, and the
# self-tests enforce that". What the self-tests used to do was grep five strings
# from one former codebase's vocabulary -- a regression test against a specific
# past mistake, unable to detect a NEW product name, a new language or a new tool.
# The claim and the check were not the same statement.
#
# These two assertions are. They hold for any vocabulary, including words nobody
# has thought of yet, because they test the SHAPE of layer 1 rather than its words:
#
#   1. no layer-1 document points at a stack's rules -- dependencies run downward,
#      from stack rules to process, never back up
#   2. no code fence in layer 1 carries a language identifier -- a ```csharp block
#      in process/ is stack-specific guidance wearing a stack-neutral filename
#
# `text`, `json`, `yaml` and `diff` fences are allowed -- they describe directory
# layouts and data shapes. Shell fences are allowed too, because layer 1 does
# legitimately show git commands and git is universal tooling, not a stack. The
# loophole that opens (a shell fence quietly carrying `yarn build`) is closed by
# 7a-iii below rather than by banning the fence.
echo "Layer discipline"

stack_refs=$(grep -rnE '`[^`]*stacks/' process/ 2>/dev/null | wc -l | tr -d ' ')
if [ "$stack_refs" -eq 0 ]; then
    ok "no layer-1 document references a stacks/ path"
else
    bad "layer 1 references stack-specific paths ($stack_refs)"
    grep -rnE '`[^`]*stacks/' process/ 2>/dev/null | sed 's/^/          /'
fi

lang_fences=$(grep -rnE '^```[a-zA-Z]' process/ 2>/dev/null \
    | grep -vE '^[^:]*:[0-9]+:```(text|json|yaml|yml|diff|bash|sh|shell|console)$' | wc -l | tr -d ' ')
if [ "$lang_fences" -eq 0 ]; then
    ok "no layer-1 code fence names a language"
else
    bad "layer 1 contains language-tagged code fences ($lang_fences)"
    grep -rnE '^```[a-zA-Z]' process/ 2>/dev/null \
        | grep -vE '^[^:]*:[0-9]+:```(text|json|yaml|yml|diff|bash|sh|shell|console)$' | sed 's/^/          /'
fi

# 7a-iii. No layer-1 document names a stack toolchain. This is what makes the
# shell fences above safe to allow, and it is the assertion the README's claim
# actually makes: process/ describes what a gate IS, never which command runs it.
# gate-command.md is exempt -- the gate script is its subject.
tc_pat='yarn|npm|pnpm|bun|dotnet|cargo|poetry|mvn|gradle|composer|nuget'
toolchain=$(grep -rnwE "$tc_pat" process/ 2>/dev/null \
    | grep -v '^process/gate-command.md:' | wc -l | tr -d ' ')
if [ "$toolchain" -eq 0 ]; then
    ok "no layer-1 document names a stack toolchain"
else
    bad "layer 1 names stack toolchains ($toolchain)"
    grep -rnwE "$tc_pat" process/ 2>/dev/null \
        | grep -v '^process/gate-command.md:' | sed 's/^/          /'
fi

# --- 7b. Named third-party products in layer 1 (ratchet) --------------------
# Layer 1 is clean of STACK names. It is not clean of named products: a section
# about how one third-party spec tool resolves directories is delivered as
# authoritative process to every project that will never use that tool. These are
# real and are being driven out, so the baseline is measured, not aspirational --
# it must only ever fall. Lower it as references are removed; never raise it.
PRODUCT_BASELINE=13
prod_count=$(grep -rniE '\bspec kit\b|\bspec-kit\b|\bfigma\b|\bnotion\b|\bjira\b|\bplaywright\b|\bgithub\b|\bgitlab\b' \
    process/ 2>/dev/null | wc -l | tr -d ' ')
if [ "$prod_count" -le "$PRODUCT_BASELINE" ]; then
    ok "layer 1 named-product references: $prod_count (baseline $PRODUCT_BASELINE)"
    [ "$prod_count" -lt "$PRODUCT_BASELINE" ] && \
        printf '        note: improved -- lower PRODUCT_BASELINE in %s to %s\n' "$0" "$prod_count"
else
    bad "layer 1 named-product references rose to $prod_count (baseline $PRODUCT_BASELINE)"
    grep -rniE '\bspec kit\b|\bspec-kit\b|\bfigma\b|\bnotion\b|\bjira\b|\bplaywright\b|\bgithub\b|\bgitlab\b' \
        process/ 2>/dev/null | sed 's/^/          /'
fi

# --- 7c. Extracted-project vocabulary (ratchet) -----------------------------
# Layers 1 and 2 were extracted from a warehouse system and carried its vocabulary
# for twelve releases. This is a regression test against that specific history, and
# it is kept for exactly that -- not mistaken for the layer-discipline check above.
# tooling/ is scanned too: it was omitted, and `purshase-order` survives in a
# shipped example there while `purshase` is literally one of the terms below.
# Extend the pattern with your own product's terms when you fork this.
VOCAB_BASELINE=0
vocab_pat='\bwms\b|dpointernational|featcher|purshase|\bpoms\b'
count=$(grep -rniE "$vocab_pat" process/ stacks/ modules/ tooling/ 2>/dev/null | wc -l | tr -d ' ')
if [ "$count" -le "$VOCAB_BASELINE" ]; then
    ok "extracted-project vocabulary: $count (baseline $VOCAB_BASELINE)"
    [ "$count" -lt "$VOCAB_BASELINE" ] && \
        printf '        note: improved -- lower VOCAB_BASELINE in %s to %s\n' "$0" "$count"
else
    bad "extracted-project vocabulary rose to $count (baseline $VOCAB_BASELINE)"
    grep -rniE "$vocab_pat" process/ stacks/ modules/ tooling/ 2>/dev/null | sed 's/^/          /'
fi

# --- 7d. The gate is certified by the receipt, never by an exit code --------
# v2.0.0 replaced "confirmed exit code 0" with the receipt, because an exit code is
# a number an agent can type. One copy was missed -- in a MANDATORY stack checklist
# walked item-by-item by /phase-review -- and the loophole v2.0.0 existed to close
# shipped for two more releases, telling an AI in writing that a pasted exit code
# satisfies the gate. That is the cost of stating one fact in seven places.
#
# gate-command.md is exempt: it is the file that defines what the exit codes MEAN.
echo "Gate evidence"
exitcode_pat='exit code (0|zero)|confirmed exit code'
ec_count=$(grep -rniE "$exitcode_pat" process/ stacks/ modules/ tooling/claude/ 2>/dev/null \
    | grep -v '^process/gate-command.md:' | wc -l | tr -d ' ')
if [ "$ec_count" -eq 0 ]; then
    ok "no document offers an exit code as gate evidence"
else
    bad "an exit code is offered as gate evidence in $ec_count place(s) -- the receipt is the evidence"
    grep -rniE "$exitcode_pat" process/ stacks/ modules/ tooling/claude/ 2>/dev/null \
        | grep -v '^process/gate-command.md:' | sed 's/^/          /'
fi

# --- 7e. One spec-folder layout, not two ------------------------------------
# Two incompatible layouts shipped simultaneously for three releases:
# `specs/<feature>/` in the README, CLAUDE.md.template, source-artifacts.md and
# both slash commands, against `specs/feature/NNN-<name>/` in branch-strategy.md
# -- which calls itself authoritative -- both review templates, and the example.
#
# The receipt machinery survived that by luck rather than design. Git pathspecs
# are matched with fnmatch WITHOUT FNM_PATHNAME, so `*` crosses `/` and
# `specs/*/status.md` happens to match both shapes. A maintainer "correcting" the
# pattern to match a comment written in the other layout would silently un-exclude
# every status file and make every receipt go stale at /phase-done.
#
# CHANGELOG.md is exempt: it records what past releases said, and rewriting a
# released entry to match a later convention is falsification, not consistency.
#
# This file is excluded from its own scan: the comment above has to name the wrong
# form in order to explain it, and a rule that cannot state the thing it forbids is
# a rule nobody can maintain.
echo "Spec layout"
layout_scan() {
    grep -rnE 'specs/<[a-z]|specs/feature/<[a-z]' \
        process/ stacks/ modules/ tooling/ tests/ examples/ \
        README.md SETUP.md ADOPTION.md CONTRIBUTING.md CLAUDE.md.template 2>/dev/null \
        | grep -v '^tests/framework-checks.sh:'
}
layout_bad=$(layout_scan | wc -l | tr -d ' ')
if [ "$layout_bad" -eq 0 ]; then
    ok "every spec path uses the canonical specs/feature/NNN-<name>/ layout"
else
    bad "documents disagree on the spec-folder layout ($layout_bad) -- branch-strategy.md is authoritative"
    layout_scan | sed 's/^/          /'
fi

# --- 7f. The install manifest template stays honest -------------------------
# The manifest is what lets /framework-upgrade resolve an installed file back to
# the upstream file it came from -- the install renames most of what it copies, so
# without it the upgrade could only handle docs/process/, the one 1:1 mapping, and
# silently skipped layer 2, the review templates, the gate scripts and CI.
#
# That only holds while every `upstream` path in the template actually exists here.
# A template naming a moved or deleted file sends the upgrade looking for something
# upstream does not have, which is precisely the silent skip it was written to end.
echo "Install manifest"
MANIFEST=tooling/claude/framework-manifest.template.json
if [ ! -f "$MANIFEST" ]; then
    bad "$MANIFEST is missing -- /framework-upgrade has nothing to resolve paths with"
elif [ -n "$PY" ]; then
    if $PY -c "import json; json.load(open('$MANIFEST'))" 2>/dev/null
    then ok "framework-manifest.template.json is valid JSON"
    else bad "framework-manifest.template.json is not valid JSON -- an install would copy a broken file"; fi

    # Resolve each upstream path, substituting the stack placeholders with the
    # stacks this repo actually ships. A path is satisfied if any substitution
    # resolves: {{BACKEND_STACK}} is filled per project, not here.
    man_bad=$($PY - "$MANIFEST" <<'PYEOF'
import json, os, sys, glob
entries = json.load(open(sys.argv[1]))["files"]
stacks = [os.path.basename(p) for p in glob.glob("stacks/*") if os.path.isdir(p)]
missing = []
for e in entries:
    up = e["upstream"]
    cands = [up]
    if "{{" in up:
        cands = []
        for s in stacks:
            c = up
            for ph in ("{{BACKEND_STACK}}", "{{FRONTEND_STACK}}"):
                c = c.replace(ph, s)
            # gate scripts are named by family (node/dotnet), not by stack folder
            for ph in ("{{BACKEND_STACK_FAMILY}}", "{{FRONTEND_STACK_FAMILY}}"):
                for fam in ("node", "dotnet"):
                    cands.append(c.replace(ph, fam))
            cands.append(c)
    if not any(os.path.exists(c) for c in cands):
        missing.append(up)
for m in missing:
    print(m)
PYEOF
)
    if [ -z "$man_bad" ]; then
        ok "every manifest upstream path exists ($($PY -c "import json;print(len(json.load(open('$MANIFEST'))['files']))" 2>/dev/null) entries)"
    else
        bad "manifest names upstream paths that do not exist:"
        printf '%s\n' "$man_bad" | sed 's/^/          /'
    fi
else
    meh "install manifest checks (no working python found)"
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

sh_inst=$(sed -n '/INSTALL-COMMANDS-BEGIN/,/INSTALL-COMMANDS-END/p' tooling/claude/hooks/guard-installs.sh \
    | sed '1d;$d' | tr -d '"' | sed 's/^INSTALL_COMMANDS=//' | grep -v '^$' | sort -u)
ps_inst=$(sed -n '/INSTALL-COMMANDS-BEGIN/,/INSTALL-COMMANDS-END/p' tooling/claude/hooks/guard-installs.ps1 \
    | grep -oE "'[^']+'" | tr -d "'" | sort -u)

if [ -z "$sh_inst" ] || [ -z "$ps_inst" ]; then
    bad "could not extract the install-command list from one or both guard-installs hooks"
elif [ "$sh_inst" = "$ps_inst" ]; then
    ok "guard-installs.sh and .ps1 block the same $(echo "$sh_inst" | wc -l | tr -d ' ') commands"
else
    bad "guard-installs.sh and .ps1 block different commands:"
    printf '%s\n' "$sh_inst" > "${TMPDIR:-/tmp}/gi-sh.$$"
    printf '%s\n' "$ps_inst" > "${TMPDIR:-/tmp}/gi-ps.$$"
    diff "${TMPDIR:-/tmp}/gi-sh.$$" "${TMPDIR:-/tmp}/gi-ps.$$" | sed 's/^/          /'
    rm -f "${TMPDIR:-/tmp}/gi-sh.$$" "${TMPDIR:-/tmp}/gi-ps.$$"
fi

# The stub ratchet is implemented twice, and the two must count the same thing. A
# marker guarded on Windows but not on macOS is the worst kind of bug: it works for
# whoever wrote it. (The per-line exemption semantics are not comparable
# mechanically -- they are covered by the behavioural check that both report the
# same count on the same tree.)
sh_mark=$(grep -E "^MARKERS=" tooling/gate/check-stubs.sh | sed "s/^MARKERS='//; s/'$//" \
    | tr '|' '\n' | grep -v '^$' | sort -u)
ps_mark=$(grep -E "^\\\$Markers = " tooling/gate/check-stubs.ps1 | sed "s/^\\\$Markers = '//; s/'$//" \
    | tr '|' '\n' | grep -v '^$' | sort -u)
if [ -z "$sh_mark" ] || [ -z "$ps_mark" ]; then
    bad "could not extract the stub-marker list from one or both check-stubs scripts"
elif [ "$sh_mark" = "$ps_mark" ]; then
    ok "check-stubs.sh and .ps1 hunt the same $(echo "$sh_mark" | wc -l | tr -d ' ') markers"
else
    bad "check-stubs.sh and .ps1 hunt different markers:"
    printf '%s\n' "$sh_mark" > "${TMPDIR:-/tmp}/cs-sh.$$"
    printf '%s\n' "$ps_mark" > "${TMPDIR:-/tmp}/cs-ps.$$"
    diff "${TMPDIR:-/tmp}/cs-sh.$$" "${TMPDIR:-/tmp}/cs-ps.$$" | sed 's/^/          /'
    rm -f "${TMPDIR:-/tmp}/cs-sh.$$" "${TMPDIR:-/tmp}/cs-ps.$$"
fi

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
g_n=0
# The guard's own configuration is guarded too: without those cases an agent that
# is blocked simply writes the approval marker whose name the block message gave
# it. And the match must be case-INSENSITIVE, because macOS -- where this
# framework directs users to the .sh hook -- has a case-insensitive filesystem,
# so `Package.json` writes the real manifest.
for c in "package.json:2" "src/Api/Api.csproj:2" "pyproject.toml:2" "go.mod:2" \
         "Cargo.toml:2" "Gemfile:2" "requirements-dev.txt:2" \
         "Package.json:2" "GEMFILE:2" "src/Api/Api.CSPROJ:2" \
         ".claude/allow-package-changes:2" ".claude/settings.json:2" \
         ".claude/settings.local.json:2" ".claude/hooks/guard-packages.sh:2" \
         "C:\\\\proj\\\\.claude\\\\settings.json:2" \
         "src/app.ts:0" "docs/notes-package.json:0" "vendor/Gemfile/readme.md:0" \
         "src/claude/notes.md:0"; do
    g_n=$((g_n + 1))
    guard_case "${c%:*}" "${c##*:}" || g_bad="$g_bad ${c%:*}"
done
if [ -z "$g_bad" ]; then ok "guard blocks manifests and its own config, allows ordinary files ($g_n cases)"
else bad "guard gave the wrong answer for:$g_bad"; fi

# The install guard covers the paths the file guard cannot see. `npm install` is a
# Bash call: before this hook existed every real way of adding a dependency was
# invisible to the framework while it reported GUARD: verified.
install_case() {  # install_case <command> <expected_exit>
    printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$1" \
        | sh tooling/claude/hooks/guard-installs.sh >/dev/null 2>&1
    [ "$?" = "$2" ]
}
i_bad=""
i_n=0
for c in "npm install left-pad|2" "npm i left-pad|2" "yarn add zod|2" \
         "cd app && pnpm add react|2" "dotnet add package Serilog|2" \
         "pip install requests|2" "go get github.com/x/y|2" "cargo add serde|2" \
         "composer require x/y|2" "gem install rails|2" \
         "npm run build|0" "npm info left-pad|0" "yarn test|0" \
         "git status|0" "dotnet build app.sln|0"; do
    i_n=$((i_n + 1))
    install_case "${c%|*}" "${c##*|}" || i_bad="$i_bad [${c%|*}]"
done
if [ -z "$i_bad" ]; then ok "install guard blocks dependency commands and allows build commands ($i_n cases)"
else bad "install guard gave the wrong answer for:$i_bad"; fi

# --- 12. All four gate scripts exclude the same paths ----------------------
# The receipt machinery is copied into four scripts (node/dotnet x sh/ps1) and
# each says "identical in every gate script -- do not let it diverge". Nothing
# enforced that. A path excluded in gate-node.sh but not gate-dotnet.ps1 means a
# receipt means something different per repo, which is worse than either rule
# applied consistently. receipt-contract.sh only ever exercises gate-node.sh.
echo "Gate exclusion parity"
sh_ex() { grep '^RECEIPT_EXCLUDES=' "$1" | sed 's/^[^"]*"//; s/"$//' | tr ' ' '\n' | grep -v '^$' | sort -u; }
ps_ex() { sed -n '/\$ReceiptExcludes = @(/,/^)/p' "$1" | grep -oE '"[^"]+"' | tr -d '"' | sort -u; }

ref=$(sh_ex tooling/gate/gate-node.sh)
ex_bad=""
for f in tooling/gate/gate-dotnet.sh; do
    [ "$(sh_ex "$f")" = "$ref" ] || ex_bad="$ex_bad $f"
done
for f in tooling/gate/gate-node.ps1 tooling/gate/gate-dotnet.ps1; do
    [ "$(ps_ex "$f")" = "$ref" ] || ex_bad="$ex_bad $f"
done

if [ -z "$ref" ]; then
    bad "could not extract RECEIPT_EXCLUDES from tooling/gate/gate-node.sh"
elif [ -z "$ex_bad" ]; then
    ok "all 4 gate scripts exclude the same $(echo "$ref" | wc -l | tr -d ' ') paths"
else
    bad "gate scripts disagree with gate-node.sh on what the receipt excludes:$ex_bad"
fi

# The exclusion list must never name a whole requirements artifact. Excluding
# tasks.md or docs/roadmap wholesale (as v2.0-2.1 did) lets requirements be
# rewritten after the gate while the receipt still reports valid.
case "$ref" in
    *"specs/*/tasks.md"*|*"docs/roadmap"[!/]*|*"docs/roadmap")
        bad "the exclusion list covers a requirements artifact, not just status" ;;
    *)  ok "exclusions name status files only, no requirements artifacts" ;;
esac

echo
echo "passed=$pass failed=$fail skipped=$skip"
[ "$fail" -eq 0 ] || exit 1
