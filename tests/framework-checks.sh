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

# --- 3b. The working tree agrees with .gitattributes ------------------------
# This check exists because the suite passed locally and failed in CI on two files
# whose contents were identical. `.gitattributes` pins *.ps1 to eol=crlf; an editor
# had written one of them with LF; and a parity extractor anchored to end-of-line
# therefore saw a trailing quote on a clean checkout and not in the author's tree.
#
# A check whose verdict depends on the machine it runs on is not a check. So assert
# the precondition directly: if the working tree does not have the line endings git
# will produce on a fresh clone, then EVERY other result in this run describes a
# tree nobody else will ever have. That is worth failing on, loudly, before the
# reader trusts the fifty PASSes underneath it.
#
# `git ls-files --eol` is authoritative -- it reports what is in the index (i/),
# what is in the working tree (w/), and the attributes in force -- so this does not
# reimplement git's normalisation rules.
echo "Line endings"
if ! git rev-parse --git-dir >/dev/null 2>&1; then
    meh "working tree vs .gitattributes (not a git repository)"
else
    # The attribute column is `attr/text eol=crlf` -- TWO whitespace-separated
    # tokens, not one. Reading it as a single field yielded "text" and the whole
    # check silently matched nothing, which is the vacuity this file exists to
    # forbid. Match the eol= directive against the whole line instead, and take the
    # working-tree value from the w/ token.
    eol_bad=$(git ls-files --eol 2>/dev/null | awk '
        {
            w = ""
            for (i = 1; i <= NF; i++) if ($i ~ /^w\//) w = substr($i, 3)
            # "none" means git sees no line endings at all (binary, or a single
            # unterminated line); nothing to compare.
            if (w == "" || w == "none") next
            if ($0 ~ /eol=crlf/ && w != "crlf") { print $NF " -- pinned crlf, working tree is " w; next }
            if ($0 ~ /eol=lf/   && w != "lf")   { print $NF " -- pinned lf, working tree is " w }
        }')
    if [ -z "$eol_bad" ]; then
        ok "every tracked file has the line endings .gitattributes pins for it"
    else
        bad "the working tree disagrees with .gitattributes -- this run does not describe a clean checkout:"
        printf '%s\n' "$eol_bad" | sed 's/^/        /'
        printf '        Fix with:  git rm --cached -r . && git reset --hard\n'
        printf '        (or re-checkout the named files). Until then, a green suite here\n'
        printf '        says nothing about what CI will see.\n'
    fi
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
        # Every platform wrapper, not just one. A malformed pipeline file is a
        # pipeline that does not run, and a pipeline that does not run is a gate
        # that is not enforcing -- silently, on the one platform nobody tested.
        yaml_bad=""
        for y in tooling/ci/*/*.yml tooling/ci/*/.gitlab-ci.yml; do
            [ -f "$y" ] || continue
            $PY -c "import yaml,sys; yaml.safe_load(open(sys.argv[1], encoding='utf-8'))" "$y" \
                2>/dev/null || yaml_bad="$yaml_bad $y"
        done
        if [ -z "$yaml_bad" ]
        then ok "every CI wrapper is valid YAML ($(ls tooling/ci/*/*.yml tooling/ci/*/.gitlab-ci.yml 2>/dev/null | wc -l | tr -d ' ') checked)"
        else bad "invalid YAML in CI wrapper(s):$yaml_bad"; fi
    else
        meh "CI wrapper YAML check (pyyaml not installed)"
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
# home at process/core/definition-of-done.md. That mapping is the whole check.
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
        # docs/process/ is FLAT in an installed project, but the source tree splits
        # the same files across process/core|team|optional/ so SETUP can copy only
        # the buckets a project's answers earn (a Small solo install has no business
        # carrying team-workflow.md). Resolve by basename rather than by path, or
        # every layer-1 reference reports as dangling.
        docs/process/*)        CAND="${1##*/}" ;;
        # Bare process/<file>.md names this repository's own layout. Released
        # CHANGELOG entries name the path a file had at the time, and rewriting a
        # released entry to match a later layout is falsification -- so resolve
        # these by basename too, which still catches a file that is genuinely gone.
        process/*)             CAND="${1##*/}" ;;
        docs/stacks/*/*)        CAND="${1##*/}" ;;
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
GUARD_NAMES=" $(sed -n '/GUARDED-MANIFESTS-BEGIN/,/GUARDED-MANIFESTS-END/p' \
    tooling/claude/hooks/guard-packages.sh 2>/dev/null \
    | sed '1d;$d' | tr -d '"' | sed 's/^GUARDED=//' | tr ' \t\n' '   ') "

is_expected_unresolvable() {
    case "$1" in
        # 1. per-feature and per-install artifacts
        specs/*|docs/roadmap/*|docs/prototypes/*|docs/architecture.md|\
        .gate-result.json|.claude/allow-package-changes|CLAUDE.md|\
        spec.md|plan.md|tasks.md|status.md|research.md|notes.md|rollback.md|\
        ai-code-review.md|human-pr-review.md|decisions.md|docs/exceptions.md) return 0 ;;
        # 2. other tools' files, named as examples. Listed case-sensitively:
        # `Package.json` appears in prose about the case-insensitive guard bug,
        # and spelling it out is clearer than folding case for every lookup.
        package.json|Package.json|package-lock.json|appsettings.json|\
        settings.local.json|AGENTS.md|docs/notes-package.json) return 0 ;;
    esac
    # Every manifest the package guard knows about is, by definition, another
    # tool's file that this repository does not contain. Derive them from the
    # guard's own list rather than maintaining a second copy here -- the docs
    # name these constantly when explaining what is guarded and why.
    case "$GUARD_NAMES" in
        *" $1 "*) return 0 ;;
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
#
#
# CHANGELOG.md is excluded, for the same reason the spec-layout scan excludes it:
# it records what PAST releases said. v2.3.0 replaced `tooling/ci/gate.yml` with a
# per-platform layout, so every earlier entry naming the old path is now an
# unresolvable reference -- and editing a released entry to point at a file that
# did not exist when it shipped is falsification, not consistency. The upgrade
# tables are load-bearing precisely because they describe the world as it was.
#
# HANDOVER.md is excluded on the same principle one step further out: it is not
# framework documentation at all but an evaluation record, and it has to QUOTE the
# paths of attacks and of superseded layouts in order to describe them --
# `src/../package.json` is a path-traversal case the guard correctly blocks, not a
# file anyone expects to resolve. This check exists to catch broken links in docs a
# project installs, and a project installs neither of these two files.
reffile=$(mktemp)
checked=0
find . -name "*.md" -not -path "./.git/*" -not -path "./examples/*" \
       -not -name CHANGELOG.md -not -name HANDOVER.md -print0 2>/dev/null \
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

# The assertion is that layer 1 names no SPECIFIC stack -- not that it never says
# the word "stacks". Layer 1 must be able to refer to the slot: the Definition of
# Done has to say "that stack's compliance checklist", and the review templates
# have to point at "the rules for the stack this phase touches". What it may not do
# is name `nextjs-trpc` or `dotnet-api`, because then layer 1 knows which stacks
# exist and stops being stack-neutral.
#
# The names come from the tree rather than a hardcoded list, so this keeps working
# when someone adds a stack -- which a fixed list would not. TEMPLATE is excluded:
# it is the contract for writing a stack, not a stack.
stack_names=$(find stacks -mindepth 1 -maxdepth 1 -type d 2>/dev/null \
    | sed 's|.*/||' | grep -v '^TEMPLATE$')
if [ -z "$stack_names" ]; then
    meh "layer-1 stack-neutrality (no stacks/ folders to check against)"
else
    stack_pat=$(printf '%s' "$stack_names" | tr '\n' '|' | sed 's/|$//')
    stack_refs=$(grep -rnE "$stack_pat" process/ 2>/dev/null | wc -l | tr -d ' ')
    if [ "$stack_refs" -eq 0 ]; then
        ok "no layer-1 document names a specific stack ($(echo "$stack_names" | wc -l | tr -d ' ') checked)"
    else
        bad "layer 1 names specific stacks ($stack_refs) -- it must refer to the slot, not the stack"
        grep -rnE "$stack_pat" process/ 2>/dev/null | sed 's/^/          /'
    fi
fi

lang_fences=$(grep -rnE '^```[a-zA-Z]' process/ 2>/dev/null \
    | grep -vE '^[^:]*:[0-9]+:```(text|json|yaml|yml|diff|bash|sh|shell|console|markdown|md)$' | wc -l | tr -d ' ')
if [ "$lang_fences" -eq 0 ]; then
    ok "no layer-1 code fence names a language"
else
    bad "layer 1 contains language-tagged code fences ($lang_fences)"
    grep -rnE '^```[a-zA-Z]' process/ 2>/dev/null \
        | grep -vE '^[^:]*:[0-9]+:```(text|json|yaml|yml|diff|bash|sh|shell|console|markdown|md)$' | sed 's/^/          /'
fi

# 7a-iii. No layer-1 document names a stack toolchain. This is what makes the
# shell fences above safe to allow, and it is the assertion the README's claim
# actually makes: process/ describes what a gate IS, never which command runs it.
# gate-command.md is exempt -- the gate script is its subject.
tc_pat='yarn|npm|pnpm|bun|dotnet|cargo|poetry|mvn|gradle|composer|nuget'
toolchain=$(grep -rnwE "$tc_pat" process/ 2>/dev/null \
    | grep -v '^process/core/gate-command.md:' | wc -l | tr -d ' ')
if [ "$toolchain" -eq 0 ]; then
    ok "no layer-1 document names a stack toolchain"
else
    bad "layer 1 names stack toolchains ($toolchain)"
    grep -rnwE "$tc_pat" process/ 2>/dev/null \
        | grep -v '^process/core/gate-command.md:' | sed 's/^/          /'
fi

# --- 7b. Named third-party products in layer 1 (ratchet) --------------------
# Layer 1 is clean of STACK names. It is not clean of named products: a section
# about how one third-party spec tool resolves directories is delivered as
# authoritative process to every project that will never use that tool. These are
# real and are being driven out, so the baseline is measured, not aspirational --
# it must only ever fall. Lower it as references are removed; never raise it.
#
# review-process.md is exempt, and only review-process.md. It carries the
# canonical glossary mapping this framework's neutral terms -- change request,
# protected-branch rules, code ownership -- onto what each hosting platform calls
# them. A glossary whose entire job is naming the products cannot be written
# without naming them, and the same argument already exempts gate-command.md from
# the exit-code scan and this file from its own layout scan. The exemption is one
# named file, not a pattern: anywhere else in layer 1, a product name is still a
# finding.
PRODUCT_BASELINE=12
prod_count=$(grep -rniE '\bspec kit\b|\bspec-kit\b|\bfigma\b|\bnotion\b|\bjira\b|\bplaywright\b|\bgithub\b|\bgitlab\b' \
    process/ 2>/dev/null | grep -v '^process/core/review-process.md:' | wc -l | tr -d ' ')
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
    | grep -v '^process/core/gate-command.md:' | wc -l | tr -d ' ')
if [ "$ec_count" -eq 0 ]; then
    ok "no document offers an exit code as gate evidence"
else
    bad "an exit code is offered as gate evidence in $ec_count place(s) -- the receipt is the evidence"
    grep -rniE "$exitcode_pat" process/ stacks/ modules/ tooling/claude/ 2>/dev/null \
        | grep -v '^process/core/gate-command.md:' | sed 's/^/          /'
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
#
# The placeholder BRACKET matters as much as the path. The first version of this
# scan matched only the angle-bracket form `specs/<feature>/`, so two documents
# writing the same wrong layout with SQUARE brackets -- project-rules.md, which is
# core and therefore installed everywhere, and repository-strategy.md -- sat in the
# tree reporting `0` while CHANGELOG.md claimed all 33 occurrences were converted.
# A scan that can only see one way of spelling the mistake certifies the others.
# Every bracket style a placeholder is plausibly written in is matched here.
echo "Spec layout"
layout_scan() {
    grep -rnE 'specs/[<[{(]|specs/feature/[<[{(]' \
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

# --- 7e-ii. Every CI wrapper runs every enforcement step --------------------
# The gate's logic lives in tooling/ci/gate-ci.sh precisely so four platforms
# cannot drift apart, and the wrappers are thin by design. The failure that
# arrangement invites is a wrapper that silently runs five of six steps -- which
# looks green, reports green, and enforces less than the platform next to it.
# gate-ci.sh names its own contract via `steps`, so this asserts against the
# shipped list rather than a copy of it that could go stale here.
echo "CI wrapper parity"
CI_STEPS=$(sh tooling/ci/gate-ci.sh steps 2>/dev/null)
WRAPPERS=$(ls tooling/ci/*/gate.yml tooling/ci/*/.gitlab-ci.yml \
              tooling/ci/*/azure-pipelines.yml tooling/ci/*/bitbucket-pipelines.yml 2>/dev/null)
if [ -z "$CI_STEPS" ]; then
    bad "tooling/ci/gate-ci.sh does not report its steps -- the parity check below cannot run"
elif [ -z "$WRAPPERS" ]; then
    bad "no CI wrappers found under tooling/ci/*/ -- every platform is unguarded"
else
    n_wrap=$(printf '%s\n' "$WRAPPERS" | grep -c .)
    n_step=$(printf '%s\n' $CI_STEPS | grep -c .)
    # Four platforms are supported and named in tooling/ci/README.md. A wrapper
    # deleted rather than fixed is a platform that quietly stops being supported,
    # so the COUNT is asserted too, not just the contents of what happens to exist.
    if [ "$n_wrap" -lt 4 ]; then
        bad "only $n_wrap CI wrapper(s) present, expected 4 (github, gitlab, azure-devops, bitbucket)"
    fi
    wrap_bad=""
    for w in $WRAPPERS; do
        for s in $CI_STEPS; do
            grep -qE "gate-ci\.sh $s( |\$)" "$w" || wrap_bad="$wrap_bad $w:$s"
        done
        # A step that runs but is allowed to fail is a step that does not enforce.
        #
        # Comment lines are stripped first. Every wrapper carries a comment telling
        # the reader NOT to add these keys, and the first version of this check
        # matched those comments -- reporting all three wrappers as broken for
        # correctly warning against the thing being checked. A scan that cannot
        # distinguish a setting from a sentence about the setting is not a scan.
        if grep -v '^[[:space:]]*#' "$w" \
             | grep -qE 'continue-on-error:[[:space:]]*true|continueOnError:[[:space:]]*true|allow_failure:[[:space:]]*true'
        then wrap_bad="$wrap_bad $w:allows-failure"; fi
    done
    if [ -z "$wrap_bad" ]; then
        ok "all $n_wrap CI wrappers invoke all $n_step enforcement steps, none allowing failure"
    else
        bad "a CI wrapper does not enforce what the others do:"
        for m in $wrap_bad; do printf '          %s\n' "$m"; done
    fi
fi

# --- 7e-0. the review-evidence commands survive being put in the manifest ----
# SETUP Q7 tells the installer to record `review_evidence_cmd` in
# .claude/framework-manifest.json. That is a JSON string value, and three of the
# four commands tooling/ci/README.md offers contain double quotes -- so pasting one
# verbatim produced INVALID JSON, and /framework-doctor reads that file. The install
# failed at its last step for a reason nothing warned about, on GitHub, Azure DevOps
# and Bitbucket. Only GitLab's command is quote-free.
#
# The template alone proves nothing: it holds a `{{REVIEW_EVIDENCE_CMD}}` placeholder
# and is therefore always valid. What has to parse is the FILLED instance, so this
# substitutes each escaped form from the README's table and parses the result.
echo "Review-evidence commands"
if [ -z "$PY" ]; then
    meh "review-evidence JSON check (no working python found)"
elif [ ! -f tooling/ci/README.md ] || [ ! -f tooling/claude/framework-manifest.template.json ]; then
    bad "cannot check review-evidence commands -- tooling/ci/README.md or the manifest template is missing"
else
    # The literal path, not $MANIFEST: that variable is assigned further down in this
    # file, so using it here compared against an empty string and the check reported
    # "cannot check" on a repository where both files were present.
    rev_bad=$($PY - tooling/claude/framework-manifest.template.json tooling/ci/README.md <<'PYEOF'
import json, re, sys
tmpl = open(sys.argv[1], encoding="utf-8").read()
readme = open(sys.argv[2], encoding="utf-8").read()
# The escaped table lives under the "ready to paste into the manifest" heading. Take
# the last cell of each row that names a platform, strip the markdown escaping of `|`
# and the surrounding backticks.
sect = readme.split("ready to paste into the manifest")[-1]
rows = re.findall(r'^\|\s*(GitHub|GitLab|Azure DevOps|Bitbucket)\s*\|\s*(.+?)\s*\|\s*$',
                  sect, re.M)
if len(rows) != 4:
    print(f"the escaped review-evidence table has {len(rows)} platform rows, expected 4")
    raise SystemExit
for name, cell in rows:
    cmd = cell.strip().strip('`').replace('\\|', '|')
    doc = tmpl.replace('{{REVIEW_EVIDENCE_CMD}}', cmd)
    # Strip the remaining placeholders so only the command under test can break it.
    doc = re.sub(r'\{\{[A-Z_]+\}\}', 'x', doc)
    try:
        json.loads(doc)
    except Exception as e:
        print(f"{name}: substituting its command makes the manifest invalid JSON ({e})")
PYEOF
)
    if [ -z "$rev_bad" ]; then
        ok "all 4 escaped review-evidence commands keep the manifest valid JSON"
    else
        bad "a review-evidence command breaks the manifest it is meant to be pasted into:"
        printf '%s\n' "$rev_bad" | sed 's/^/          /'
    fi
fi

# --- 7e-iii. the pin covers the script that carries the checks ---------------
# gate-ci.sh pins gate.sh, the ratchet and the baseline. Until the first real
# upgrade rehearsal it did not pin ITSELF -- and the install guard deliberately
# leaves `gate.*` and `check-stubs.*` outside its perimeter *on the stated grounds
# that CI pins them*. So the one file that decides what CI enforces was covered by
# neither the pin nor the perimeter, protected only by CODEOWNERS, which is advisory
# until somebody reads the diff. Same shape as the finding the pin exists to close,
# reintroduced by the refactor that moved the checks into one place.
#
# Asserted three ways, because each catches a different mistake: the PINNED list
# names it, the every-step contract still holds, and the two places that spell the
# regeneration command out for a human agree with the list.
if [ ! -f tooling/ci/gate-ci.sh ]; then
    bad "tooling/ci/gate-ci.sh is missing -- every CI wrapper invokes it"
else
    pin_list=$(sed -n "s/^PINNED='\(.*\)'$/\1/p" tooling/ci/gate-ci.sh)
    pin_bad=""
    case " $pin_list " in
        *" tooling/ci/gate-ci.sh "*) ;;
        *) pin_bad="PINNED does not name tooling/ci/gate-ci.sh" ;;
    esac
    # The human-facing regeneration commands must list the same files, or someone
    # follows the printed command and writes a pin that the step then rejects.
    for src in SETUP.md tooling/gate/check-stubs.sh; do
        grep -q 'sha256sum .*gate-ci\.sh' "$src" 2>/dev/null \
            || pin_bad="$pin_bad; $src prints a sha256sum command that omits gate-ci.sh"
    done
    if [ -z "$pin_bad" ]; then
        ok "the pin covers gate-ci.sh, and both printed regeneration commands agree"
    else
        bad "the pin does not cover the script that carries every check: $pin_bad"
    fi
fi

# Every platform needs its ownership story present -- a file where the platform has
# one, written instructions where it does not. Bitbucket and Azure DevOps have no
# CODEOWNERS equivalent at all, and an install that assumes otherwise believes it
# has a trust anchor outside the perimeter when it has none.
own_bad=""
for expect in github/CODEOWNERS gitlab/CODEOWNERS \
              azure-devops/branch-policy.md bitbucket/default-reviewers.md \
              README.md gate-ci.sh; do
    [ -f "tooling/ci/$expect" ] || own_bad="$own_bad $expect"
done
if [ -z "$own_bad" ]
then ok "every platform ships its code-ownership file or its written substitute"
else bad "tooling/ci is missing:$own_bad"; fi

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
    # BOTH lists. `per_repo_files` is instantiated once per entry in `repos`, and
    # it exists because `files` used to carry the gate under fixed {{BACKEND_DIR}}
    # and {{FRONTEND_DIR}} slots while `repos` was an array -- a third repo got no
    # entry for its gate and the upgrade skipped it silently. A check that reads
    # only `files` would not have noticed the new list at all.
    #
    # Placeholders resolve by SUFFIX rather than by name, so adding a role (a
    # {{ADMIN_STACK}}) or a platform does not require editing this script:
    # `*_STACK_FAMILY` is a gate family, `*_STACK` is a folder under stacks/,
    # `FORGE` is a folder under tooling/ci/, and anything ending `_FILE` is a
    # filename resolved by globbing its own directory. Anything else belongs to the
    # installed side and never appears in an upstream path.
    man_bad=$($PY - "$MANIFEST" <<'PYEOF'
import json, os, re, sys, glob
doc = json.load(open(sys.argv[1]))
entries = list(doc.get("files", [])) + list(doc.get("per_repo_files", []))
if not doc.get("files"):
    print("files[] is missing or empty")
stacks = [os.path.basename(p) for p in glob.glob("stacks/*") if os.path.isdir(p)]
forges = [os.path.basename(p) for p in glob.glob("tooling/ci/*") if os.path.isdir(p)]
FAMILIES = ("node", "dotnet")
def expand(path):
    m = re.search(r"\{\{([A-Z_]+)\}\}", path)
    if not m:
        return [path]
    ph, name = m.group(0), m.group(1)
    if name.endswith("_STACK_FAMILY"):
        values = FAMILIES
    elif name.endswith("_STACK"):
        values = stacks
    elif name == "FORGE":
        values = forges
    elif name.endswith("_FILE"):
        # A filename chosen per platform. Resolve it by glob rather than by a list
        # here: hard-coding the four wrapper names would mean this check goes stale
        # the moment a platform is added, and a stale check reports a phantom
        # problem, which is a check people learn to ignore.
        values = ["*"]
    else:
        values = []
    out = []
    for v in values:
        out.extend(expand(path.replace(ph, v)))
    return out
missing = []
for e in entries:
    up = e["upstream"]
    cands = expand(up)
    if not any(glob.glob(c) if "*" in c else os.path.exists(c) for c in cands):
        missing.append(up)
for m in missing:
    print(m)
PYEOF
)
    if [ -z "$man_bad" ]; then
        ok "every manifest upstream path exists ($($PY -c "import json;d=json.load(open('$MANIFEST'));print(len(d['files'])+len(d.get('per_repo_files',[])))" 2>/dev/null) entries)"
    else
        bad "manifest names upstream paths that do not exist:"
        printf '%s\n' "$man_bad" | sed 's/^/          /'
    fi
else
    meh "install manifest checks (no working python found)"
fi

# --- 7g. Duplicated facts (ratchet) -----------------------------------------
# Design Principle #2 is "one source of truth per fact -- never duplicate a rule in
# two files, link it", and the repo violated it more than any other rule it states.
# The cost is not untidiness. When the gate contract changed in v2.0.0 one copy was
# missed, and a MANDATORY stack checklist went on saying "confirmed exit code 0"
# for two more releases -- telling an AI in writing that a pasted number satisfies
# the gate, the exact loophole v2.0.0 was written to close. A fact stated in seven
# places changes in six.
#
# This counts FILES MENTIONING a fact, not restatements: no grep can tell a pointer
# from a copy, and one that pretended to would be wrong often enough to be ignored.
# Spread is the proxy, the canonical-locations table in CONTRIBUTING.md is the
# judgement, and review is where the two meet. Lower a baseline when you
# consolidate; never raise one to make a red check green.
echo "Duplicated facts"
fact_scan() {  # fact_scan <pattern>
    grep -rlniE "$1" process/ stacks/ modules/ tooling/ examples/ \
        README.md SETUP.md ADOPTION.md CLAUDE.md.template 2>/dev/null | sort -u
}
fact_check() {  # fact_check <label> <baseline> <pattern>
    n=$(fact_scan "$3" | wc -l | tr -d ' ')
    if [ "$n" -le "$2" ]; then
        ok "$1: $n files (baseline $2)"
        [ "$n" -lt "$2" ] && printf '        note: improved -- lower the baseline to %s\n' "$n"
    else
        bad "$1 spread to $n files (baseline $2) -- see CONTRIBUTING.md > Canonical locations"
        fact_scan "$3" | sed 's/^/          /'
    fi
}

# 12 -> 11: the four CI wrappers each carried a copy of the solo-CI rationale when
# they were split out of gate.yml; they now carry a pointer instead. Ratchets only
# ever fall.
fact_check "human review: peer vs solo" 11 'peer review|reviewer .{0,12}(other than|!=)|own acceptance review'
fact_check "CI applies to solo too"     4 'CI .{0,30}(solo|not run by the party)|solo.{0,40}\bCI\b'
fact_check "receipt: status vs reqs"    2 'status.{0,60}requirement|requirement.{0,60}status'
fact_check "scope-tier artifacts"       8 'Small.{0,60}spec\.md|spec\.md.{0,40}Small'

# --- 7h. Every cited rule ID is defined --------------------------------------
# The rule-ID scheme exists so a review can cite `B1` instead of paraphrasing it.
# That only works if the ID resolves. The README's own example was `F12`, which
# appeared exactly once in the whole repository: in the sentence claiming it
# exists. A citation that resolves to nothing is worse than a paraphrase, because
# it looks authoritative.
#
# Definitions are headings (`### Rule B1: ...`); citations are inline (`(Rule F8d)`).
# IDs are append-only, so gaps in a series are expected and not checked -- what is
# checked is that nothing points at an ID nobody wrote.
echo "Rule IDs"
id_defined=$(grep -rhoE '^#+[[:space:]]+Rule[[:space:]]+[A-Z]{1,3}[0-9]+[a-z]?(-[0-9]+)?' stacks/ 2>/dev/null \
    | sed -E 's/.*Rule[[:space:]]+//; s/-[0-9]+$//' | sort -u)
id_cited=$(grep -rhoE 'Rule[[:space:]]+[A-Z]{1,3}[0-9]+[a-z]?' \
    stacks/ process/ tooling/ examples/ README.md CLAUDE.md.template 2>/dev/null \
    | sed -E 's/.*Rule[[:space:]]+//' | sort -u)
if [ -z "$id_defined" ]; then
    meh "rule IDs (none defined in stacks/)"
else
    printf '%s\n' "$id_defined" > "${TMPDIR:-/tmp}/.ids-def.$$"
    printf '%s\n' "$id_cited"   > "${TMPDIR:-/tmp}/.ids-cit.$$"
    id_bad=$(comm -13 "${TMPDIR:-/tmp}/.ids-def.$$" "${TMPDIR:-/tmp}/.ids-cit.$$")
    rm -f "${TMPDIR:-/tmp}/.ids-def.$$" "${TMPDIR:-/tmp}/.ids-cit.$$"
    if [ -z "$id_bad" ]; then
        ok "every cited rule ID resolves ($(echo "$id_defined" | wc -l | tr -d ' ') defined)"
    else
        bad "rule IDs cited but never defined:"
        printf '%s\n' "$id_bad" | sed 's/^/          /'
    fi
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
#
# `tr -d '\r'` FIRST, and this is not defensive padding. `.gitattributes` pins
# *.ps1 to eol=crlf, so a fresh checkout -- which is what CI gets -- ends this line
# `...todo!\(\)'<CR>`. The `s/'$//` below anchors to end of line, the last character
# is the CR rather than the quote, and the trailing quote survives into the
# comparison: sh reported `todo!\(\)` against ps1's `todo!\(\)'` and the suite went
# red on two files whose contents agree perfectly.
#
# The reason this went unnoticed is worth more than the fix. The author's working
# tree holds whatever their editor last wrote -- LF, here -- so the check passed
# locally and could ONLY fail on a clean clone. That is the same shape as every
# other finding in this file: a check whose verdict depends on the machine it runs
# on is not a check. See the working-tree/attribute assertion in section 3.
#
# The guard extractors below and above are immune by accident, not by design: they
# use `grep -oE "'[^']+'"`, which never captures a CR sitting outside the quotes.
sh_mark=$(grep -E "^MARKERS=" tooling/gate/check-stubs.sh | tr -d '\r' \
    | sed "s/^MARKERS='//; s/'$//" | tr '|' '\n' | grep -v '^$' | sort -u)
ps_mark=$(grep -E "^\\\$Markers = " tooling/gate/check-stubs.ps1 | tr -d '\r' \
    | sed "s/^\\\$Markers = '//; s/'$//" | tr '|' '\n' | grep -v '^$' | sort -u)
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
# Both implementations, the same payloads, one fixture. The cases used to be two
# lists of shell strings here, .sh only, formatted with printf -- which meant no
# case could contain a double quote, which is precisely the input that defeated
# the parser, and no case ever ran against the .ps1 hooks at all. Parity was
# certified by diffing the two pattern LISTS as text; that check passed while the
# .sh hook truncated its input at the first quote and its self-guard ignored case.
# Comparing behaviour is the only version of this check that can see the code
# AROUND the list, which is where all of it lived. tests/fixtures/guard-cases.tsv.
GUARD_FIXTURES=tests/fixtures/guard-cases.tsv
if [ ! -f "$GUARD_FIXTURES" ]; then
    bad "missing $GUARD_FIXTURES -- the guards have no behavioural coverage"
else
    # The .ps1 side runs in ONE process, driven by tests/run-guard-cases.ps1, which
    # prints `<case-number><TAB><exit-code>` per case. Spawning pwsh per case cost a
    # process launch each time and took the suite from seconds to minutes on
    # Windows, and a self-test that slow stops being run -- which would leave the
    # .ps1 hooks exactly as unexercised as they were before this check existed.
    have_pwsh=0
    ps_file="${TMPDIR:-/tmp}/sdlc-guard-ps.$$"
    if command -v pwsh >/dev/null 2>&1; then
        have_pwsh=1
        pwsh -NoProfile -File tests/run-guard-cases.ps1 >"$ps_file" 2>/dev/null
        exec 3<"$ps_file"
    fi

    g_bad=""; p_bad=""; c_n=0
    TAB=$(printf '\t')
    CR=$(printf '\r')
    # A file redirect, not a pipe: the loop must run in THIS shell or the counters
    # and the failure lists do not survive it.
    while IFS="$TAB" read -r hook want payload note; do
        case "$hook" in ''|\#*) continue ;; esac
        [ -n "$payload" ] || continue
        c_n=$((c_n + 1))
        printf '%s' "$payload" | sh "tooling/claude/hooks/guard-$hook.sh" >/dev/null 2>&1
        sh_rc=$?
        if [ "$sh_rc" != "$want" ]; then
            g_bad="$g_bad
          guard-$hook.sh returned $sh_rc, expected $want -- $note"
        fi
        [ "$have_pwsh" = 1 ] || continue
        # Read the .ps1 answers in lockstep on fd 3 rather than searching the
        # output per case: that search was two more processes per case, and this
        # loop is already the most fork-heavy thing in the suite. The case number
        # is carried through and checked, so a desync is reported, not hidden.
        if IFS="$TAB" read -r ps_n ps_rc <&3; then
            ps_rc=${ps_rc%$CR}
            [ "$ps_n" = "$c_n" ] || ps_rc="out of step at case $ps_n"
        else
            ps_rc="no answer"
        fi
        if [ "$ps_rc" != "$sh_rc" ]; then
            p_bad="$p_bad
          guard-$hook: sh=$sh_rc ps1=$ps_rc -- $note"
        fi
    done < "$GUARD_FIXTURES"
    if [ "$have_pwsh" = 1 ]; then exec 3<&-; rm -f "$ps_file"; fi

    if [ "$c_n" -eq 0 ]; then
        bad "$GUARD_FIXTURES parsed to zero cases -- is it still TAB-separated?"
    elif [ -z "$g_bad" ]; then
        ok "guards block manifests, installs and their own perimeter ($c_n cases)"
    else
        bad "the .sh guards gave the wrong answer:"; printf '%s\n' "$g_bad"
    fi

    if [ "$have_pwsh" != 1 ]; then
        # "must not skip in CI" was written in the MESSAGE and nowhere in the code,
        # so the suite went green on a runner without pwsh and the entire parity
        # guarantee rested on ubuntu-latest continuing to ship it. Check 5 already
        # had this shape; this is the same `if [ -n "${CI:-}" ]` it uses.
        if [ -n "${CI:-}" ]; then
            bad "the .ps1 guards were not executed in CI (pwsh not installed) -- the parity check is the only thing comparing the two implementations, and a skipped check is a check that is not running"
        else
            meh "the .ps1 guards were not executed (pwsh not installed) -- must not skip in CI"
        fi
    elif [ "$c_n" -eq 0 ]; then
        : # already reported
    elif [ -z "$p_bad" ]; then
        ok "guard-*.sh and guard-*.ps1 agree on all $c_n payloads"
    else
        bad "the two implementations disagree:"; printf '%s\n' "$p_bad"
    fi
fi

# The JSON extractor is duplicated into both .sh hooks rather than sourced from a
# shared file: a hook that cannot find its library dies, and a PreToolUse hook that
# dies fails OPEN. Duplication is the safer failure mode, but only if the copies
# cannot drift -- so they are compared byte for byte, the same convention the
# pattern lists use.
#
# This is a DRIFT check and nothing more. It is a byte diff between the two .sh
# files: breaking both copies identically passes it, and it does not touch the
# .ps1 hooks at all. It used to be labelled "both .sh guards carry the same JSON
# extractor", which reads like a correctness claim -- the correctness claim is the
# fixture two checks up, and the label now says which is which.
je_a=$(sed -n '/JSON-EXTRACT-BEGIN/,/JSON-EXTRACT-END/p' tooling/claude/hooks/guard-installs.sh)
je_b=$(sed -n '/JSON-EXTRACT-BEGIN/,/JSON-EXTRACT-END/p' tooling/claude/hooks/guard-packages.sh)
if [ -z "$je_a" ] || [ -z "$je_b" ]; then
    bad "the JSON-EXTRACT block is missing from one or both .sh guards"
elif [ "$je_a" = "$je_b" ]; then
    ok "the JSON extractor has not drifted between the two .sh guards (text only -- behaviour is the fixture above)"
else
    bad "the JSON extractor has drifted between guard-installs.sh and guard-packages.sh"
fi

# --- 11b. The two stub ratchets return the same answers ---------------------
# The marker-string comparison above is the check that passed while `sh` counted 1
# and `pwsh` counted 3 on the same tree. The regexes were never the problem: the
# file filter next to them disagreed about paths, and PowerShell's Select-String
# and -notmatch are case-INSENSITIVE by default, so `// todo:` counted on one
# platform only. The behavioural-parity machinery built for the guards is exactly
# what this needed; here it is, over the same repository the ratchet would run on.
echo "Stub ratchet behavior"
STUB_PATHS=tests/fixtures/stub-paths.txt
STUB_LINES=tests/fixtures/stub-lines.md

# --- the .sh side against the fixture, WITHOUT requiring pwsh ----------------
# This assertion used to live inside the `else` branch below, which only runs when
# PowerShell is installed. So on every machine without it -- every macOS and Linux
# contributor, and the sandbox this framework is usually evaluated in -- all 80
# fixture paths went unchecked, and the .sh classifier could regress freely. It was
# found by reverting a fresh is_source fix and watching the suite stay green.
#
# Parity needs both implementations; the FIXTURE's verdict needs only one. Assert
# what can be asserted here, and compare the twins below when the twin can run.
if [ ! -f "$STUB_PATHS" ]; then
    bad "missing $STUB_PATHS -- the stub ratchet has no classification coverage"
else
    fx_want="${TMPDIR:-/tmp}/fx-want.$$"
    grep -v '^[[:space:]]*#' "$STUB_PATHS" | grep -v '^[[:space:]]*$' > "$fx_want"
    fx_args=$(awk '{ $1 = ""; sub(/^ /, ""); print }' "$fx_want")
    fx_got="${TMPDIR:-/tmp}/fx-got.$$"
    # shellcheck disable=SC2086
    set -f
    sh tooling/gate/check-stubs.sh --classify $fx_args > "$fx_got" 2>/dev/null
    set +f
    if [ ! -s "$fx_got" ]; then
        bad "check-stubs.sh classified nothing -- is $STUB_PATHS still '<verdict> <path>' per line?"
    elif diff "$fx_want" "$fx_got" >/dev/null 2>&1; then
        ok "check-stubs.sh returns the fixture's verdict for all $(grep -c '' "$fx_want" | tr -d ' ') paths"
    else
        bad "check-stubs.sh disagrees with the verdict written in $STUB_PATHS:"
        diff "$fx_want" "$fx_got" | sed 's/^/          /'
    fi
    rm -f "$fx_want" "$fx_got"
fi

if [ ! -f "$STUB_PATHS" ] || [ ! -f "$STUB_LINES" ]; then
    bad "missing $STUB_PATHS or $STUB_LINES -- the stub ratchet has no behavioural coverage"
elif ! command -v pwsh >/dev/null 2>&1; then
    if [ -n "${CI:-}" ]; then
        bad "check-stubs.ps1 was not executed in CI (pwsh not installed) -- the two ratchets are then compared by their constants only"
    else
        meh "check-stubs.sh vs .ps1 behaviour (pwsh not installed)"
    fi
else
    # 0. THE SAME REFUSAL, on the two trees where a wrong answer is silent.
    #
    # This case exists because of a divergence the rest of this section could not
    # reach. When the .sh ratchet learned to refuse an unreadable tree and a UTF-16
    # source, only the .sh learned it: check-stubs.ps1 returned 0 for the first and
    # happily COUNTED the second, because Select-String decodes UTF-16 and a
    # byte-oriented grep cannot. Same tree, two verdicts -- and neither case is in
    # this repository's own tree or in either fixture, so parity check 1 below
    # compared a tree without them and agreed, and the classification fixtures
    # compare verdicts about PATHS, not about encodings. The bug was reachable only
    # by trees nobody built.
    #
    # Both must REFUSE, and they must refuse together. A count of 0 from either is
    # the failure: it reads as a clean tree, the ratchet reports "improved", and the
    # next step writes 0 into the pinned baseline.
    refusal_case() {  # refusal_case <label> <setup fn>
        rc_dir="${TMPDIR:-/tmp}/sdlc-refuse.$$"
        rm -rf "$rc_dir"; mkdir -p "$rc_dir/src"
        "$2" "$rc_dir" || { meh "$1 (could not build the case)"; rm -rf "$rc_dir"; return 0; }
        r_sh_out=$(cd "$rc_dir" && sh "$REPO_ROOT/tooling/gate/check-stubs.sh" --count 2>&1); r_sh=$?
        r_ps_out=$(cd "$rc_dir" && pwsh -NoProfile -File "$REPO_ROOT/tooling/gate/check-stubs.ps1" -Count 2>&1); r_ps=$?
        sh_ref=0; ps_ref=0
        [ "$r_sh" != 0 ] && ! printf '%s' "$r_sh_out" | grep -qx '0' && sh_ref=1
        [ "$r_ps" != 0 ] && ! printf '%s' "$r_ps_out" | grep -qx '0' && ps_ref=1
        if [ "$sh_ref" = 1 ] && [ "$ps_ref" = 1 ]; then
            ok "$1 -- both ratchets refuse"
        else
            bad "$1 -- sh rc=$r_sh refuse=$sh_ref, ps1 rc=$r_ps refuse=$ps_ref; a count of 0 here reads as a clean tree"
            printf '          sh : %s\n' "$(printf '%s' "$r_sh_out" | head -1)"
            printf '          ps1: %s\n' "$(printf '%s' "$r_ps_out" | head -1)"
        fi
        rm -rf "$rc_dir"
    }
    REPO_ROOT=$(pwd)
    setup_norepo() { printf '// TODO: invisible\n' > "$1/src/a.ts"; }
    setup_utf16() {
        command -v iconv >/dev/null 2>&1 || return 1
        (cd "$1" && git init -q . 2>/dev/null) || return 1
        printf '// TODO: a\n// TODO: b\n' | iconv -f UTF-8 -t UTF-16 > "$1/src/w.ts" 2>/dev/null || return 1
        [ -s "$1/src/w.ts" ] || return 1
    }
    refusal_case "an unreadable tree" setup_norepo
    refusal_case "a UTF-16 source"    setup_utf16

    # 1. the same count on this repository's own tree
    cs_sh=$(sh tooling/gate/check-stubs.sh --count 2>/dev/null)
    cs_ps=$(pwsh -NoProfile -File tooling/gate/check-stubs.ps1 -Count 2>/dev/null | tr -d ' \r\n')
    if [ -z "$cs_sh" ] || [ -z "$cs_ps" ]; then
        bad "one of the stub ratchets produced no count"
    elif [ "$cs_sh" = "$cs_ps" ]; then
        ok "check-stubs.sh and .ps1 count the same $cs_sh markers on this tree"
    else
        bad "the two stub ratchets disagree on this tree: sh=$cs_sh ps1=$cs_ps"
    fi

    # 2. the verdict the FIXTURE demands, on every fixture path -- not merely the
    #    same verdict as each other. Parity is agreement, and two implementations
    #    gutted together agree perfectly about nothing: emptying `is_source` on
    #    both sides left this section fully green. The expected verdict is written
    #    down in tests/fixtures/stub-paths.txt and neither implementation gets a
    #    vote on it.
    cs_want="${TMPDIR:-/tmp}/cs-want.$$"
    grep -v '^[[:space:]]*#' "$STUB_PATHS" | grep -v '^[[:space:]]*$' > "$cs_want"
    cs_args=$(awk '{ $1 = ""; sub(/^ /, ""); print }' "$cs_want")
    cs_sh_out="${TMPDIR:-/tmp}/cs-cls-sh.$$"
    cs_ps_out="${TMPDIR:-/tmp}/cs-cls-ps.$$"
    # shellcheck disable=SC2086
    set -f
    sh tooling/gate/check-stubs.sh --classify $cs_args > "$cs_sh_out" 2>/dev/null
    pwsh -NoProfile -File tooling/gate/check-stubs.ps1 -Classify "$(printf '%s' "$cs_args" | tr '\n' ',')" \
        2>/dev/null | tr -d '\r' > "$cs_ps_out"
    set +f
    if [ ! -s "$cs_sh_out" ] || [ ! -s "$cs_ps_out" ]; then
        bad "one of the stub ratchets classified nothing -- is $STUB_PATHS still '<verdict> <path>' per line?"
    else
        cls_bad=""
        diff "$cs_want" "$cs_sh_out" >/dev/null 2>&1 || cls_bad="check-stubs.sh"
        diff "$cs_want" "$cs_ps_out" >/dev/null 2>&1 || cls_bad="${cls_bad:+$cls_bad and }check-stubs.ps1"
        if [ -z "$cls_bad" ]; then
            ok "both stub ratchets return the fixture's verdict for all $(grep -c '' "$cs_want" | tr -d ' ') paths"
        else
            bad "$cls_bad disagrees with the verdict written in $STUB_PATHS:"
            diff "$cs_want" "$cs_sh_out" | sed 's/^/          sh:  /'
            diff "$cs_want" "$cs_ps_out" | sed 's/^/          ps1: /'
        fi
    fi
    rm -f "$cs_sh_out" "$cs_ps_out" "$cs_want"

    # 3. the same LINES of the same file. Compare `path:lineno` only -- the line
    #    text carries CR on a Windows checkout and that is not a disagreement.
    ln_sh=$(sh tooling/gate/check-stubs.sh --scan "$STUB_LINES" 2>/dev/null | cut -d: -f1,2)
    ln_ps=$(pwsh -NoProfile -File tooling/gate/check-stubs.ps1 -Scan "$STUB_LINES" 2>/dev/null \
        | tr -d '\r' | cut -d: -f1,2)
    if [ -z "$ln_sh" ] || [ -z "$ln_ps" ]; then
        bad "one of the stub ratchets found no markers in $STUB_LINES"
    elif [ "$ln_sh" = "$ln_ps" ]; then
        ok "check-stubs.sh and .ps1 flag the same $(printf '%s\n' "$ln_sh" | grep -c '') lines (case, and the approved-stub reason)"
    else
        bad "the two stub ratchets flag different lines of $STUB_LINES:"
        printf '%s\n' "$ln_sh" > "${TMPDIR:-/tmp}/cs-ln-sh.$$"
        printf '%s\n' "$ln_ps" > "${TMPDIR:-/tmp}/cs-ln-ps.$$"
        diff "${TMPDIR:-/tmp}/cs-ln-sh.$$" "${TMPDIR:-/tmp}/cs-ln-ps.$$" | sed 's/^/          /'
        rm -f "${TMPDIR:-/tmp}/cs-ln-sh.$$" "${TMPDIR:-/tmp}/cs-ln-ps.$$"
    fi
fi

# --- 11b-iii. the two verifiers pin the same lists --------------------------
# This check exists because of a mistake, and the mistake is the one this whole
# framework keeps making. verify-guard.sh was changed to pin its guard lists by
# SHA-256 instead of counting them; verify-guard.ps1 was not, and kept its
# `$GuardedFloor = 86`. So on Windows -- the platform the shipped settings.json
# actually targets, because that is where the POSIX form fails open -- the
# substitution attack the digest exists to stop still certified clean. The fix
# shipped on the twin nobody could execute.
#
# Two assertions, and they are different questions:
#   1. Both files carry FOUR digest constants, and the same four values. A
#      divergence here means one platform pins its lists and the other does not.
#   2. Those values are the digests of the lists as they exist RIGHT NOW. Constants
#      that agree with each other and not with the file are a pin of nothing --
#      parity without an absolute truth, which is exactly what G11 was about.
echo "Guard-list digest pinning"
vg_sh=tooling/claude/hooks/verify-guard.sh
vg_ps=tooling/claude/hooks/verify-guard.ps1
# The .sh spells them GUARDED_DIGEST_SH=<hex>; the .ps1 $GuardedDigestSh = '<hex>'.
# Compared as a set of four values, so a rename on one side does not read as a
# mismatch -- what matters is that both pin the same four things.
dig_sh=$(grep -oE '^(GUARDED|INSTALL)_DIGEST_(SH|PS1)=[0-9a-f]{64}' "$vg_sh" 2>/dev/null \
         | sed 's/.*=//' | sort)
dig_ps=$(grep -oE "^\\\$(Guarded|Install)Digest(Sh|Ps1) *= *'[0-9a-f]{64}'" "$vg_ps" 2>/dev/null \
         | grep -oE "[0-9a-f]{64}" | sort)
n_sh=$(printf '%s\n' "$dig_sh" | grep -c '[0-9a-f]')
n_ps=$(printf '%s\n' "$dig_ps" | grep -c '[0-9a-f]')
if [ "$n_sh" -ne 4 ] || [ "$n_ps" -ne 4 ]; then
    bad "verify-guard should pin 4 list digests per twin, found sh=$n_sh ps1=$n_ps -- a twin that counts instead of pinning does not detect substitution"
elif [ "$dig_sh" != "$dig_ps" ]; then
    bad "verify-guard.sh and .ps1 pin DIFFERENT list digests -- one platform is unprotected:"
    printf '          sh : %s\n' $dig_sh
    printf '          ps1: %s\n' $dig_ps
else
    # And do they describe the lists that are actually here? Recomputed with the
    # same normalisation both scripts use: strip CR, drop comments and blank lines,
    # strip trailing whitespace.
    dig_bad=""
    for spec in \
        "tooling/claude/hooks/guard-packages.sh:GUARDED-MANIFESTS" \
        "tooling/claude/hooks/guard-installs.sh:INSTALL-COMMANDS" \
        "tooling/claude/hooks/guard-packages.ps1:GUARDED-MANIFESTS" \
        "tooling/claude/hooks/guard-installs.ps1:INSTALL-COMMANDS"; do
        gfile=${spec%:*}; gmark=${spec##*:}
        [ -f "$gfile" ] || { dig_bad="$dig_bad $gfile(missing)"; continue; }
        actual=$(sed -n "/$gmark-BEGIN/,/$gmark-END/p" "$gfile" | sed '1d;$d' \
                 | tr -d '\r' | grep -v '^[[:space:]]*#' | sed 's/[[:space:]]*$//' \
                 | grep -v '^[[:space:]]*$' | sha256sum | cut -d' ' -f1)
        printf '%s\n' "$dig_sh" | grep -qx "$actual" || dig_bad="$dig_bad $gfile"
    done
    if [ -z "$dig_bad" ]; then
        ok "both verifiers pin the same 4 list digests, and all 4 match the lists on disk"
    else
        bad "a pinned digest does not match the list it claims to pin:$dig_bad"
        printf '        regenerate with: sh %s --print-digests\n' "$vg_sh"
    fi
fi

# --- 11b-ii. verify-guard's own verdicts ------------------------------------
# The fixture two checks up proves the GUARDS block. Nothing proved that
# verify-guard NOTICES when they stop, and that is the script a consuming project
# is left alone with: the 99-case fixture lives here, not there. Three defects
# lived in exactly that gap --
#
#   * it ran seven cases, none of them the install guard's perimeter, so deleting
#     that entire block and changing nothing else produced GUARD: verified;
#   * it sampled 5 of 56 install commands and 15 of 86 manifest patterns, so the
#     lists could be cut by ~85% and still verify;
#   * on Linux and macOS -- the SHIPPED DEFAULT, because settings.json names
#     PowerShell -- it silently tested the .sh twin and reported the configured
#     .ps1 hooks as verified while they were `exit 0`.
#
# COST. Each run spawns a shell per case: about four seconds on Linux, where CI
# runs, and over a minute under MSYS. That is the same fork-and-pipe tax the
# verifier's own header documents, and it is paid here deliberately -- these three
# assertions are the only thing standing between a future edit and a verifier that
# certifies whatever it is pointed at.
echo "verify-guard verdicts"
vg="${TMPDIR:-/tmp}/sdlc-vg.$$"
rm -rf "$vg"
mkdir -p "$vg/.claude/hooks"
cp tooling/claude/hooks/*.sh tooling/claude/hooks/*.ps1 "$vg/.claude/hooks/" 2>/dev/null
# An install configured for THIS platform: the POSIX hooks, named as SETUP tells
# a macOS/Linux user to name them.
sed 's|powershell -NoProfile -File \(\.claude/hooks/guard-[a-z]*\)\.ps1|sh \1.sh|' \
    tooling/claude/settings.json > "$vg/.claude/settings.json"

vg_run() {  # vg_run -> sets VG_RC and leaves output in $vg/out.txt
    ( cd "$vg" && sh .claude/hooks/verify-guard.sh > out.txt 2>&1 )
    VG_RC=$?
}

if ! grep -q 'sh \.claude/hooks/guard-packages\.sh' "$vg/.claude/settings.json"; then
    bad "could not build a POSIX-configured scratch install -- has settings.json's hook command changed shape?"
else
    vg_run
    if [ "$VG_RC" = 0 ] && grep -q 'GUARD: verified' "$vg/out.txt"; then
        ok "verify-guard verifies a correctly configured install (exit 0)"
    else
        bad "verify-guard rejected a correct install (exit $VG_RC):"
        sed 's/^/          /' "$vg/out.txt"
    fi

    # The configured interpreter is absent and a twin exists. Every case still
    # passes -- against the WRONG SCRIPT -- and that must not read as success.
    sed -i.bak 's|"sh \.claude/hooks/guard-|"nosuchshell .claude/hooks/guard-|g; s|guard-\([a-z]*\)\.sh"|guard-\1.ps1"|g' \
        "$vg/.claude/settings.json" 2>/dev/null || \
        sed 's|"sh \.claude/hooks/guard-|"nosuchshell .claude/hooks/guard-|g; s|guard-\([a-z]*\)\.sh"|guard-\1.ps1"|g' \
            "$vg/.claude/settings.json.bak" > "$vg/.claude/settings.json"
    vg_run
    if [ "$VG_RC" = 3 ] && grep -q 'partially verified' "$vg/out.txt"; then
        ok "verify-guard refuses to say 'verified' when it tested the twin (exit 3)"
    else
        bad "verify-guard reported exit $VG_RC for an install whose configured hooks it never ran:"
        sed 's/^/          /' "$vg/out.txt"
    fi

    # Back to a correct configuration, then break the guard underneath it: the
    # perimeter block neutralised, and the install list cut to five entries.
    cp "$vg/.claude/settings.json.bak" "$vg/.claude/settings.json" 2>/dev/null
    gi="$vg/.claude/hooks/guard-installs.sh"
    awk '
        /^if \[ -n "\$perimeter_hit" \]; then$/ && !done_p { print "perimeter_hit=\"\""; done_p = 1 }
        /^INSTALL_COMMANDS="npm install$/ { print "INSTALL_COMMANDS=\"npm install"; cut = 1; next }
        cut && /^dart pub add"$/ { print "go get\""; cut = 0; next }
        cut { next }
        { print }
    ' "$gi" > "$gi.new" && mv "$gi.new" "$gi"
    vg_run
    if [ "$VG_RC" = 1 ] &&
       grep -q 'FAIL  creating the approval marker' "$vg/out.txt" &&
       grep -q 'FAIL  install-command list' "$vg/out.txt"; then
        ok "verify-guard fails on a gutted perimeter and a gutted list (exit 1)"
    else
        bad "verify-guard reported exit $VG_RC for a guard with no perimeter and a five-entry list:"
        sed 's/^/          /' "$vg/out.txt"
    fi

    # --- the OTHER half of verify-guard ------------------------------------
    # Every assertion above mutates guard-installs. Deleting verify-guard's entire
    # manifest-guard block -- 57 lines, all 21 blocked-path cases, all 4 allowed
    # cases and the manifest list check -- left the three of them passing and the
    # suite totals byte-identical, because assertion 3's mutation and both of its
    # grep strings live in the install half. "Can this assertion be satisfied by
    # deleting the thing it tests?" was yes, for half the file.
    cp "$vg/.claude/settings.json.bak" "$vg/.claude/settings.json" 2>/dev/null
    cp tooling/claude/hooks/guard-installs.sh "$vg/.claude/hooks/" 2>/dev/null
    gp="$vg/.claude/hooks/guard-packages.sh"
    awk '
        /^GUARDED="package\.json/ { print "GUARDED=\"package.json\""; cut = 1; next }
        cut && /"$/ { cut = 0; next }
        cut { next }
        { print }
    ' "$gp" > "$gp.new" && mv "$gp.new" "$gp"
    vg_run
    if [ "$VG_RC" = 1 ] && grep -q 'FAIL  manifest list' "$vg/out.txt"; then
        ok "verify-guard fails on a gutted MANIFEST list too, not just the install one"
    else
        bad "verify-guard reported exit $VG_RC for a guard-packages with a one-entry list:"
        sed 's/^/          /' "$vg/out.txt"
    fi

    # --- W1: hook pairs read from outside hooks.PreToolUse -------------------
    # settings.json ships a top-level "$comment", so an "$examples" sibling holding
    # a well-formed PreToolUse block is idiomatic. The pair extractor was a boolean
    # flag with no idea of nesting, so it read that decoy and certified it while
    # the only REAL hook matched `Read`, which edits nothing.
    cp tooling/claude/hooks/guard-packages.sh "$vg/.claude/hooks/" 2>/dev/null
    cat > "$vg/.claude/settings.json" <<'VGDECOY'
{
  "$comment": "notes",
  "$examples": {
    "PreToolUse": {
      "file guard": {
        "matcher": "Edit|MultiEdit|Write|NotebookEdit",
        "command": "sh .claude/hooks/guard-packages.sh"
      },
      "install guard": {
        "matcher": "Bash",
        "command": "sh .claude/hooks/guard-installs.sh"
      }
    }
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Read",
        "hooks": [ { "type": "command", "command": "sh .claude/hooks/guard-packages.sh" } ]
      }
    ]
  }
}
VGDECOY
    vg_run
    if [ "$VG_RC" = 1 ] && grep -q 'outside hooks.PreToolUse' "$vg/out.txt"; then
        ok "verify-guard refuses a settings.json whose hook pairs are decoys"
    else
        bad "verify-guard reported exit $VG_RC for a config whose only live hook matches Read:"
        sed 's/^/          /' "$vg/out.txt"
    fi

    # --- W2: a list SUBSTITUTED rather than shortened ------------------------
    # The floor was a count, so it caught deletion and not replacement. Keeping the
    # twelve commands verify-guard exercises and replacing the other forty-four
    # with junk -- same line count -- produced GUARD: verified while `npm ci`,
    # `yarn install`, `poetry add`, `pipx install` and six more were wide open.
    cp "$vg/.claude/settings.json.bak" "$vg/.claude/settings.json" 2>/dev/null
    gi2="$vg/.claude/hooks/guard-installs.sh"
    awk '
        /^INSTALL_COMMANDS="npm install$/ {
            print "INSTALL_COMMANDS=\"npm install"
            print "yarn add";   print "dotnet add package"; print "pip install"
            print "go get";     print "npx";                print "pnpm add"
            print "cargo add";  print "bun install";        print "gem install"
            print "composer require"; print "npm --silent install"
            for (i = 0; i < 44; i++) printf "zzjunk%02d\n", i
            print "\""
            cut = 1; next
        }
        cut && /^dart pub add"$/ { cut = 0; next }
        cut { next }
        { print }
    ' "$gi2" > "$gi2.new" && mv "$gi2.new" "$gi2"
    vg_run
    if [ "$VG_RC" = 1 ] && grep -q 'does not match the digest' "$vg/out.txt"; then
        ok "verify-guard catches a guard list whose entries were REPLACED, not removed"
    else
        bad "verify-guard reported exit $VG_RC for a 56-entry list with 44 junk entries:"
        sed 's/^/          /' "$vg/out.txt"
    fi
fi
rm -rf "$vg"

# --- 11c. Both ratchets count a PLANTED number ------------------------------
# Everything above is relative: the two implementations are compared to each
# other, or to a verdict about a path. Neither says what the ratchet's own
# arithmetic produces on a real tree, and that is where it broke. `count_stubs`
# returned the two-line string "0\n0" on any tree with NO markers -- the state
# every project adopting the ratchet on a clean codebase starts in -- because
# `grep -c` prints 0 AND exits 1, so the `|| echo 0` fallback fired as well.
# Nothing in the suite could see it: this repository's own tree has markers in it,
# so the zero case never arose here.
#
# So: a scratch repository, a known number of markers, and the number asserted.
# The tree also carries the enumeration cases that cannot be written as
# classification fixtures -- a path with a space, a non-ASCII path, and a file
# named like a grep option.
echo "Stub ratchet count"
REPO=$(pwd)
plant="${TMPDIR:-/tmp}/sdlc-stub-plant.$$"
rm -rf "$plant"
if ! (mkdir -p "$plant/src" && cd "$plant" && git init -q . 2>/dev/null); then
    meh "planted stub count (could not create a scratch repository)"
else
    # 2 counted: the third marker carries a reason, so it is exempt.
    printf '// TODO: one\n// FIXME: two\n// HACK: three approved-stub: deferred to phase 4\n' \
        > "$plant/src/a.ts"
    # 1 counted: `latest-ledger` contains `test` as a SUBSTRING, and the ratchet
    # used to skip the whole file for that reason alone.
    printf '// TODO: renamed away from the ratchet\n' > "$plant/src/latest-ledger.ts"
    # 0 counted: a test file and a document.
    printf '// TODO: a note about a test\n' > "$plant/src/b.test.ts"
    printf 'TODO: prose about future work\n'  > "$plant/README.md"
    want=3

    # A filename that looks like a grep option. `grep -nHE "$MARKERS" $files` with
    # no `--` turned this into a flag: with `-q` in the tree the count fell to
    # zero, silently, on the .sh side only.
    if (cd "$plant" && touch -- -q 2>/dev/null) && [ -f "$plant/-q" ]; then
        printf '// TODO: not counted, this file is empty of source\n' > "$plant/-q.ts"
        want=$((want + 1))
    else
        printf '        note: could not create a file named -q on this filesystem\n'
    fi
    # A path with a space: the old `for f in $(git ls-files)` word-split it.
    printf '// TODO: spaced\n' > "$plant/src/my file.ts" 2>/dev/null \
        && want=$((want + 1)) \
        || printf '        note: could not create a path containing a space\n'
    # A non-ASCII path: git's default core.quotePath=true rendered it as a quoted
    # C string, which is not the name of any file, and BOTH implementations then
    # skipped it in silence.
    utf8=$(printf 'src/caf\303\251.ts')
    printf '// TODO: accented\n' > "$plant/$utf8" 2>/dev/null
    if [ -f "$plant/$utf8" ]; then want=$((want + 1))
    else printf '        note: could not create a non-ASCII path on this filesystem\n'; fi

    got=$(cd "$plant" && sh "$REPO/tooling/gate/check-stubs.sh" --count 2>/dev/null)
    if [ "$got" = "$want" ]; then
        ok "check-stubs.sh counts the planted $want markers"
    else
        bad "check-stubs.sh counted [$got] on a tree planted with $want markers"
    fi

    # The zero case, on its own, because it is the one that was broken and the one
    # every new adopter starts in.
    rm -rf "$plant/src" "$plant/README.md" "$plant/-q.ts"
    printf 'const answer = 42;\n' > "$plant/clean.ts"
    zero=$(cd "$plant" && sh "$REPO/tooling/gate/check-stubs.sh" --count 2>/dev/null)
    if [ "$zero" = "0" ]; then
        ok "check-stubs.sh counts 0 on a tree with no markers at all"
    else
        bad "check-stubs.sh counted [$zero] on a tree with no markers -- expected exactly 0"
    fi

    # --- W7: the exemption belongs to the TEXT, not the path -----------------
    # `grep -H` prefixes each match with `<path>:<lineno>:` and the exemption filter
    # ran over the whole line, so the string only had to appear SOMEWHERE. One
    # `git mv` into a directory named `approved-stub: deferred` removed every marker
    # beneath it from the ratchet, silently and without limit -- and it was a
    # divergence too: the .sh counted 1 where check-stubs.ps1, which filters the line
    # text only, counted 4.
    #
    # Both halves are asserted: that the directory name does NOT exempt, and that a
    # real per-line exemption still does. Testing only the first would pass on a
    # build that had lost the exemption altogether.
    exdir="${TMPDIR:-/tmp}/sdlc-exdir.$$"
    rm -rf "$exdir"; mkdir -p "$exdir/src/approved-stub: deferred"
    if (cd "$exdir" && git init -q . 2>/dev/null) && [ -d "$exdir/src/approved-stub: deferred" ]; then
        printf '// TODO: a\n// TODO: b\n// FIXME: c\n' > "$exdir/src/approved-stub: deferred/real.ts"
        printf '// TODO: counted\n' > "$exdir/src/plain.ts"
        got_ex=$(cd "$exdir" && sh "$REPO/tooling/gate/check-stubs.sh" --count 2>/dev/null)
        if [ "$got_ex" = "4" ]; then
            ok "a directory named 'approved-stub: ...' does not exempt the files inside it"
        else
            bad "check-stubs.sh counted [$got_ex] where 4 markers exist -- a directory name is exempting its contents"
        fi
        # And the legitimate form still works: same tree, marker exempted per line.
        rm -rf "$exdir/src/approved-stub: deferred"
        printf '// TODO: counted\n// TODO: waived approved-stub: deferred to phase 3\n' > "$exdir/src/plain.ts"
        got_ok=$(cd "$exdir" && sh "$REPO/tooling/gate/check-stubs.sh" --count 2>/dev/null)
        if [ "$got_ok" = "1" ]; then
            ok "an approved-stub reason on the LINE still exempts that marker"
        else
            bad "check-stubs.sh counted [$got_ok], expected 1 -- the per-line exemption has stopped working"
        fi
    else
        meh "approved-stub scoping (could not create the scratch tree)"
    fi
    rm -rf "$exdir"

    # --- W4: a scan that FAILED must not read as a clean tree ----------------
    # The ratchet's dangerous direction is not "wrong number", it is "zero". When
    # the enumeration or the scan fails, nothing is printed, `wc -l` says 0, and
    # the ratchet reports "improved" and invites you to write 0 into the PINNED
    # baseline -- after which no marker anywhere can ever fail it again. Two ways
    # in, both of which reported a clean tree:
    #
    #   ARG_MAX   the whole file list went to ONE exec. Measured on 1202 files with
    #             1810-byte paths: grep never ran, its "Argument list too long" went
    #             to a discarded stderr, and --count printed 0 against a real marker.
    #   no repo   `git ls-files` in a non-repository lists nothing, which is
    #             indistinguishable from a repository containing nothing.
    #
    # ARG_MAX itself is too slow to reproduce in this suite (it needs ~2 MB of
    # paths). The non-repository case exercises the same refusal, and both now exit
    # 4 rather than printing a number.
    norepo="${TMPDIR:-/tmp}/sdlc-norepo.$$"
    rm -rf "$norepo"; mkdir -p "$norepo"
    printf '// TODO: invisible\n' > "$norepo/a.ts"
    nr_out=$(cd "$norepo" && sh "$REPO/tooling/gate/check-stubs.sh" --count 2>&1); nr_rc=$?
    if [ "$nr_rc" != 0 ] && ! printf '%s' "$nr_out" | grep -qx '0'; then
        ok "check-stubs.sh refuses to report 0 when it could not read the tree"
    else
        bad "check-stubs.sh returned rc=$nr_rc [$nr_out] outside a git repository -- a failed scan must not read as a clean tree"
    fi
    rm -rf "$norepo"

    # A UTF-16 source file stores TODO as T\0O\0D\0O\0, so a byte-oriented scan
    # cannot match it and the file contributes zero -- silently. That is an
    # ordinary artefact of a Windows editor, and Windows is the primary platform.
    if command -v iconv >/dev/null 2>&1; then
        wide="${TMPDIR:-/tmp}/sdlc-wide.$$"
        rm -rf "$wide"; mkdir -p "$wide/src"
        if (cd "$wide" && git init -q . 2>/dev/null); then
            printf '// TODO: a\n// TODO: b\n' | iconv -f UTF-8 -t UTF-16 > "$wide/src/w.ts" 2>/dev/null
            w_out=$(cd "$wide" && sh "$REPO/tooling/gate/check-stubs.sh" --count 2>&1); w_rc=$?
            if [ "$w_rc" != 0 ] && printf '%s' "$w_out" | grep -q 'UTF-16'; then
                ok "check-stubs.sh refuses a UTF-16 source rather than counting it as zero"
            else
                bad "check-stubs.sh returned rc=$w_rc [$w_out] on a UTF-16 source -- its markers would leave the ratchet unnoticed"
            fi
        else
            meh "UTF-16 refusal (could not create a scratch repository)"
        fi
        rm -rf "$wide"
    else
        meh "UTF-16 refusal (iconv not installed)"
    fi

    # ...and the baseline it writes from that count has to be a number the next
    # run can read back. `--baseline` wrote the corrupt two-line value straight
    # into the pinned file.
    (cd "$plant" && sh "$REPO/tooling/gate/check-stubs.sh" --baseline >/dev/null 2>&1)
    bl=$(tr -d ' \r\n' < "$plant/.gate-stubs-baseline" 2>/dev/null)
    case "$bl" in
        ''|*[!0-9]*) bad "--baseline wrote something that is not a number: [$bl]" ;;
        *) if (cd "$plant" && sh "$REPO/tooling/gate/check-stubs.sh" >/dev/null 2>&1)
           then ok "--baseline on a zero-stub tree writes a baseline the ratchet accepts"
           else bad "the ratchet rejects the baseline --baseline just wrote"; fi ;;
    esac

    if command -v pwsh >/dev/null 2>&1; then
        pgot=$(cd "$plant" && pwsh -NoProfile -File "$REPO/tooling/gate/check-stubs.ps1" -Count 2>/dev/null | tr -d ' \r\n')
        if [ "$pgot" = "0" ]; then
            ok "check-stubs.ps1 counts 0 on the same tree"
        else
            bad "check-stubs.ps1 counted [$pgot] on a tree with no markers"
        fi
        # Same count, same bytes: .gate-stubs-baseline is PINNED, so a Windows
        # developer re-baselining at an unchanged number must not change its hash.
        sh_sum=$(sha256sum "$plant/.gate-stubs-baseline" | cut -d' ' -f1)
        (cd "$plant" && pwsh -NoProfile -File "$REPO/tooling/gate/check-stubs.ps1" -Baseline >/dev/null 2>&1)
        ps_sum=$(sha256sum "$plant/.gate-stubs-baseline" | cut -d' ' -f1)
        if [ "$sh_sum" = "$ps_sum" ]; then
            ok "--baseline and -Baseline write byte-identical files"
        else
            bad "--baseline and -Baseline write different bytes for the same count -- the pin will report the gate as weakened on a no-op"
        fi
    fi
    rm -rf "$plant"
fi

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
