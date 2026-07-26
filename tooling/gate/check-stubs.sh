#!/usr/bin/env sh
# Stub ratchet — refuses to let unimplemented code grow.
#
#     sh check-stubs.sh            check against the baseline
#     sh check-stubs.sh --baseline write the current count as the new baseline
#
# WHY THIS EXISTS. Nothing else in the framework requires the implementation to be
# REAL. The word "coverage" appears nowhere as a requirement, and the two review
# checkboxes that gesture at it do not close the gap: "tests accompany the behavior
# introduced in this phase" is a co-location predicate that `expect(true).toBe(true)`
# satisfies, and "no tests weakened, skipped, or deleted" constrains changes to
# EXISTING tests while saying nothing about the strength of new ones.
#
# So a phase can persist a value, leave `if (remaining.length === 0) { /* TODO */ }`
# empty, write three tests asserting a 200 and the presence of a field, pass the
# build, earn a GENUINE valid receipt with no forgery involved, tick every box in
# the AI review, and reach "Done pending human review" — with the feature's stated
# core invariant unimplemented. The only thing between that and merge is the manual
# acceptance step, which is the first thing that gets rubber-stamped.
#
# This is a ratchet, not a threshold. A brownfield repo may legitimately have two
# hundred TODOs on day one; demanding zero would be ignored within a week, and a
# rule that gets ignored trains people to ignore the others. What it forbids is the
# number going UP: this phase may not add unimplemented code.
#
# It does not prove the implementation is complete. It proves nobody left a marker
# saying it is not. That is a floor, not a ceiling — `approved-stub:` exists so the
# floor stays honest rather than being gamed by deleting the comment.

set -u

BASELINE_FILE=".gate-stubs-baseline"

# Markers that mean "not implemented". `approved-stub:` on the same line exempts it,
# so a deliberate, reviewed placeholder is declared rather than hidden — write
# `// approved-stub: spec.md §4.2 deferred to phase 3` and it stops counting.
MARKERS='TODO|FIXME|HACK|XXX|NotImplementedException|NotImplementedError|UnimplementedError|unimplemented!|todo!\(\)'

# Source files only. Tests are excluded because a TODO in a test is a note about a
# test, not shipped behaviour; docs and specs are excluded because prose about
# future work is the point of a roadmap. Vendored and generated trees are not ours.
is_source() {
    case "$1" in
        # The checker itself names every marker it hunts for, in its own regex and
        # its own comments. Left in, it would count six of its own lines on a clean
        # repo -- a number nobody can explain and everybody learns to ignore.
        */check-stubs.sh|check-stubs.sh|*/check-stubs.ps1|check-stubs.ps1) return 1 ;;
        *node_modules/*|*/vendor/*|vendor/*|*/dist/*|dist/*|*/build/*|build/*|\
        *.min.js|*.lock|*.sum) return 1 ;;
        docs/*|specs/*|*.md|*.txt|*.json|*.yml|*.yaml|*.csv|*.svg|*.lock) return 1 ;;
        *[Tt]est*|*[Ss]pec.*|*.spec.*|*_test.*|*Tests/*|*tests/*|*__tests__/*) return 1 ;;
        *) return 0 ;;
    esac
}

# Marker lines that are NOT exempted, for one file. The exemption is per LINE, not
# per file: counting `approved-stub:` occurrences anywhere in the file and
# subtracting would let unrelated prose about approved stubs cancel out real ones,
# and -- worse -- would disagree with check-stubs.ps1, which filters per line. Two
# implementations of one rule that quietly return different numbers is the exact
# defect the sh/ps1 parity tests elsewhere in this framework exist to prevent.
stub_lines() {  # stub_lines <file>
    grep -nE "$MARKERS" "$1" 2>/dev/null | grep -vE 'approved-stub:'
}

count_stubs() {
    n=0
    # Tracked files plus untracked-but-not-ignored ones: the gate runs on a dirty
    # tree, and a stub added in an uncommitted file is exactly what this catches.
    for f in $(git ls-files --cached --others --exclude-standard 2>/dev/null); do
        is_source "$f" || continue
        [ -f "$f" ] || continue
        c=$(stub_lines "$f" | grep -c '' 2>/dev/null)
        [ -n "$c" ] || c=0
        n=$((n + c))
    done
    echo "$n"
}

current=$(count_stubs)

if [ "${1:-}" = "--baseline" ]; then
    echo "$current" > "$BASELINE_FILE"
    echo "STUBS: baseline set to $current — commit $BASELINE_FILE."
    exit 0
fi

if [ ! -f "$BASELINE_FILE" ]; then
    # Fail closed, loudly, with the fix on screen. A control that quietly does
    # nothing when its configuration is absent is the failure mode this framework
    # exists to argue against — and the fix is one command.
    echo "STUBS: no $BASELINE_FILE — the stub ratchet has never been baselined."
    echo "  Current count: $current. To adopt the ratchet as it stands, run:"
    echo "    sh check-stubs.sh --baseline"
    echo "  and commit the file. Lower it deliberately as stubs are implemented."
    exit 1
fi

baseline=$(tr -d ' \r\n' < "$BASELINE_FILE")
case "$baseline" in
    ''|*[!0-9]*) echo "STUBS: $BASELINE_FILE does not contain a number — refusing to guess."; exit 1 ;;
esac

if [ "$current" -gt "$baseline" ]; then
    echo "STUBS: unimplemented markers rose to $current (baseline $baseline)."
    echo "  This phase added code that says it is not finished. Implement it, or"
    echo "  mark the line 'approved-stub: <where the spec defers it>' so the"
    echo "  deferral is reviewable rather than invisible."
    echo
    for f in $(git ls-files --cached --others --exclude-standard 2>/dev/null); do
        is_source "$f" || continue
        [ -f "$f" ] || continue
        stub_lines "$f" | sed "s|^|  $f:|"
    done
    exit 1
fi

if [ "$current" -lt "$baseline" ]; then
    echo "STUBS: $current (baseline $baseline) — improved. Lower the baseline:"
    echo "    sh check-stubs.sh --baseline"
    exit 0
fi

echo "STUBS: $current (baseline $baseline)"
exit 0
