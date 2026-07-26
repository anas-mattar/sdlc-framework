#!/usr/bin/env sh
# Stub ratchet — refuses to let unimplemented code grow.
#
#     sh check-stubs.sh            check against the baseline
#     sh check-stubs.sh --baseline write the current count as the new baseline
#     sh check-stubs.sh --count    print the count and nothing else
#     sh check-stubs.sh --classify <path>...  print `source`/`skip` per path
#
# The last two exist so tests/framework-checks.sh can compare this script's
# answers against check-stubs.ps1's on the same inputs. The two implementations
# used to be compared by diffing their MARKER STRINGS, which passed while they
# returned different counts on the same tree: PowerShell's `Select-String` and
# `-notmatch` are case-INSENSITIVE by default, so `// todo: later` counted on
# Windows and not on macOS, and the two file filters disagreed about any path
# with `test` in a directory name. A rule implemented twice needs its ANSWERS
# compared, not its constants.
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

# Markers that mean "not implemented". `approved-stub: <reason>` on the same line
# exempts it, so a deliberate, reviewed placeholder is declared rather than hidden.
MARKERS='TODO|FIXME|HACK|XXX|NotImplementedException|NotImplementedError|UnimplementedError|unimplemented!|todo!\(\)'

# The exemption needs a REASON after the colon. `// TODO: everything
# approved-stub:` was accepted for three releases and exempted the line while
# saying nothing at all — an escape hatch whose entire cost was typing eleven
# characters is not an escape hatch, it is a delete key with extra steps. Written
# as one pattern so check-stubs.ps1 can carry the same one.
# APPROVED-STUB-PATTERN-BEGIN
EXEMPT='approved-stub:[[:space:]]*[^[:space:]]'
# APPROVED-STUB-PATTERN-END

# Source files only. Tests are excluded because a TODO in a test is a note about a
# test, not shipped behaviour; docs and specs are excluded because prose about
# future work is the point of a roadmap. Vendored and generated trees are not ours.
#
# Every rule below is duplicated, EXACTLY, in check-stubs.ps1's Test-IsSource, and
# tests/framework-checks.sh feeds both the same path list and diffs the answers.
# The previous pair did not agree: this one matched `*[Tt]est*` against the WHOLE
# path and the .ps1 matched it against the filename only, so `src/latest/run.ts`
# was source on Windows and not on macOS. Where the two disagree, the .sh answer is
# the one CI uses and the .ps1 answer is the one the developer sees.
is_source() {  # is_source <path>
    p=${1%"${1##*[!/]}"}          # trailing slashes are not part of a filename
    # Fold backslashes only when there are any. This runs once per tracked file,
    # and a `tr` per file cost thirty seconds on Windows for a substitution that
    # is a no-op on every path `git ls-files` ever prints.
    case "$p" in *\\*) p=$(printf '%s' "$p" | tr '\\' '/') ;; esac
    b=${p##*/}
    case "$b" in
        # The checker itself names every marker it hunts for, in its own regex and
        # its own comments. Left in, it would count six of its own lines on a clean
        # repo -- a number nobody can explain and everybody learns to ignore.
        check-stubs.sh|check-stubs.ps1) return 1 ;;
        # Extensions are matched case-INSENSITIVELY (PowerShell's -match is, so the
        # bracket classes are how the .sh agrees with it rather than the other way
        # round -- `README.MD` must not be source on one platform only).
        *.[Mm][Dd]|*.[Tt][Xx][Tt]|*.[Jj][Ss][Oo][Nn]|*.[Yy][Mm][Ll]|\
        *.[Yy][Aa][Mm][Ll]|*.[Cc][Ss][Vv]|*.[Ss][Vv][Gg]|\
        *.[Ll][Oo][Cc][Kk]|*.[Ss][Uu][Mm]) return 1 ;;
        *.min.js) return 1 ;;
        *[Tt]est*) return 1 ;;
        *[Ss]pec.*) return 1 ;;
    esac
    case "/$p" in
        */node_modules/*|*/vendor/*|*/dist/*|*/build/*) return 1 ;;
        */test/*|*/tests/*|*/Test/*|*/Tests/*|*/__tests__/*|*/spec/*|*/specs/*) return 1 ;;
    esac
    case "$p" in
        docs/*|specs/*) return 1 ;;
    esac
    return 0
}

# Marker lines that are NOT exempted, for one file. The exemption is per LINE, not
# per file: counting `approved-stub:` occurrences anywhere in the file and
# subtracting would let unrelated prose about approved stubs cancel out real ones,
# and -- worse -- would disagree with check-stubs.ps1, which filters per line. Two
# implementations of one rule that quietly return different numbers is the exact
# defect the sh/ps1 parity tests elsewhere in this framework exist to prevent.
stub_lines() {  # stub_lines <file>...
    grep -nHE "$MARKERS" "$@" 2>/dev/null | grep -vE "$EXEMPT"
}

# The source files this repo has right now, one per line.
#
# Tracked files plus untracked-but-not-ignored ones: the gate runs on a dirty
# tree, and a stub added in an uncommitted file is exactly what this catches.
source_files() {
    for f in $(git ls-files --cached --others --exclude-standard 2>/dev/null); do
        is_source "$f" || continue
        [ -f "$f" ] || continue
        printf '%s\n' "$f"
    done
}

# ONE grep over the whole list rather than one per file. Two forks per file took
# thirty seconds on a repository of eighty files, and this script runs inside the
# gate, which is meant to be run often. `-H` forces the filename prefix even when
# the list happens to be one file, so the output shape does not change with the
# size of the repo -- and it is the shape check-stubs.ps1 prints too.
all_stub_lines() {
    files=$(source_files)
    [ -n "$files" ] || return 0
    # Word splitting is intended here: the list is one path per line and git does
    # not print backslashes. A path containing a space was already split by the
    # loop above, which is a pre-existing limitation of both implementations.
    # shellcheck disable=SC2086
    stub_lines $files
}

count_stubs() {
    all_stub_lines | grep -c '' 2>/dev/null || echo 0
}

# --- test-support modes -----------------------------------------------------
if [ "${1:-}" = "--classify" ]; then
    shift
    for p in "$@"; do
        if is_source "$p"; then echo "source $p"; else echo "skip $p"; fi
    done
    exit 0
fi

# Which LINES of a given file count, ignoring is_source. The marker regex and the
# exemption are the other half of the rule, and the tree this script normally
# walks does not happen to contain a lower-case `todo:` or an unjustified
# `approved-stub:` -- so a count over the real repo cannot see either.
if [ "${1:-}" = "--scan" ]; then
    shift
    stub_lines "$@"
    exit 0
fi

current=$(count_stubs)

if [ "${1:-}" = "--count" ]; then
    echo "$current"
    exit 0
fi

if [ "${1:-}" = "--baseline" ]; then
    echo "$current" > "$BASELINE_FILE"
    echo "STUBS: baseline set to $current — commit $BASELINE_FILE."
    echo "  Pin it too, in the same commit:  sha256sum gate.sh check-stubs.sh $BASELINE_FILE > .gate-sha256"
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
    echo "  deferral is reviewable rather than invisible. The reason is required:"
    echo "  a bare 'approved-stub:' with nothing after it does not exempt anything."
    echo
    all_stub_lines | sed 's|^|  |'
    exit 1
fi

if [ "$current" -lt "$baseline" ]; then
    echo "STUBS: $current (baseline $baseline) — improved. Lower the baseline:"
    echo "    sh check-stubs.sh --baseline"
    exit 0
fi

echo "STUBS: $current (baseline $baseline)"
exit 0
