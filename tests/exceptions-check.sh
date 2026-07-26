#!/usr/bin/env sh
# Behavioural tests for the CI gate's "No overdue exceptions" step.
#
#     sh tests/exceptions-check.sh
#
# WHY THIS FILE EXISTS. The exceptions check is the only mechanical thing standing
# between a dated, authorised hole in the process and a permanent one, and every
# defect it has ever had made it pass SILENTLY: a column named "Remediation notes"
# won the header match over the real deadline column; a row with a missing cell was
# skipped; `2026-13-45` compared as a string and bought five months; a second table
# was read with the first table's column index. None of those changed the output at
# all -- CI just stopped looking. A check whose failure mode is "green" cannot be
# reviewed by reading it, only by running it.
#
# The awk program is EXTRACTED from tooling/ci/gate.yml between the
# EXCEPTIONS-AWK-BEGIN/END markers rather than copied here, so these cases exercise
# the shipped code. A copy would pass forever after the shipped one drifted, which
# is the same defect one level up.
#
# Exit 0 = all cases behaved as specified.

set -u
cd "$(dirname "$0")/.." || exit 1

pass=0; fail=0
ok()  { pass=$((pass + 1)); printf '  PASS  %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL  %s\n' "$1"; }

GATE=tooling/ci/gate.yml
prog=$(sed -n '/EXCEPTIONS-AWK-BEGIN/,/EXCEPTIONS-AWK-END/p' "$GATE" \
     | sed '1d;$d' | sed 's/^          //' | grep -v '^[[:space:]]*#')
case "$prog" in
    *"awk -v t="*) ;;
    *) echo "  FAIL  could not extract the exceptions awk from $GATE"
       echo "        (are the EXCEPTIONS-AWK-BEGIN/END markers still there?)"
       echo
       echo "passed=0 failed=1"
       exit 1 ;;
esac

TMP="${TMPDIR:-/tmp}/sdlc-exc.$$"
mkdir -p "$TMP" || exit 1
f="$TMP/exceptions.md"
today=2026-07-27      # fixed, so a case cannot start passing when the clock moves

# The step reads status 0 with rows on stdout as OVERDUE, 3 as "no table carries a
# deadline column", 4 as "one table carries two", 5 as "a row cannot be read".
# `expect` is `<status>/<overdue|quiet>`.
check() {  # check <label> <expected> <line>...
    label=$1; want=$2; shift 2
    printf '%s\n' "$@" > "$f"
    st=0
    eval "$prog" || st=$?
    if [ "$st" = 0 ] && [ -n "$out" ]; then got="0/overdue"
    elif [ "$st" = 0 ]; then got="0/quiet"
    else got="$st/quiet"; fi
    if [ "$got" = "$want" ]; then ok "$label"
    else bad "$label -- expected $want, got $got${out:+ ($out)}"; fi
}

echo "Exceptions check"

# --- the deadline column is found by an EXACT header --------------------------
check "plain overdue row is caught" 0/overdue \
    '| Date | Remediate by |' '|---|---|' '| 2026-03-04 | 2026-03-11 |'
check "open row with a future date passes" 0/quiet \
    '| Date | Remediate by |' '|---|---|' '| 2026-03-04 | 2027-03-11 |'
check "a 'Due by' header is accepted too" 0/overdue \
    '| Date | Due by |' '|---|---|' '| 2026-03-04 | 2026-03-11 |'
# R5: `h ~ /remediate|remediation|dueby/` matched "Remediation notes" first and
# `next` fired, so the real column was never looked at and the step passed.
check "a 'Remediation notes' column does not win over the deadline" 0/overdue \
    '| Date | Remediation notes | Why | Authoriser | Remediate by |' \
    '|---|---|---|---|---|' \
    '| 2026-03-04 | pending | incident | A | 2026-03-11 |'
check "two deadline columns in one table is an error, not a coin toss" 4/quiet \
    '| Date | Remediate by | Due by |' '|---|---|---|' \
    '| 2026-03-04 | 2026-01-01 | 2027-01-01 |'
check "a table with no deadline column at all fails" 3/quiet \
    '| Date | Why |' '|---|---|' '| 2026-03-04 | incident |'

# --- the column is re-bound per table ----------------------------------------
# R6: `col` was a file-global that was never reset, so table 2 was read with
# table 1's index and its deadline was never seen.
check "a second table binds its own column" 0/overdue \
    '| Date | Remediate by |' '|---|---|' '| 2026-03-04 | 2027-01-01 |' \
    '' 'prose between the tables' '' \
    '| Feature | Why | Remediate by |' '|---|---|---|' \
    '| x | y | 2026-01-01 |'
# R6: the first row of a table is its header. A data row in that position used to
# be consumed as a header candidate and the whole file then had no column.
check "a header written below its own data rows fails" 3/quiet \
    '| 2026-03-04 | 2026-03-11 |' '| Date | Remediate by |' '|---|---|'

# --- a row this check cannot read is a FAILURE, not a skip -------------------
# R6: a missing cell (or a stray `|` in a Why cell) shifted the date out of $col
# and the row vanished from the check with no message.
check "a short row fails rather than being skipped" 5/quiet \
    '| Date | Why | Remediate by |' '|---|---|---|' '| 2026-03-04 | 2026-03-11 |'
check "a stray pipe inside a cell fails rather than being skipped" 5/quiet \
    '| Date | Why | Remediate by |' '|---|---|---|' \
    '| 2026-03-04 | prod | incident | 2026-03-11 |'

# --- the date is a real calendar date ----------------------------------------
# R7: shape-checked by regex and compared as a string, so an impossible date was
# simply a date far in the future.
check "an impossible month/day fails" 5/quiet \
    '| Date | Remediate by |' '|---|---|' '| 2026-03-04 | 2026-13-45 |'
check "9999-99-99 fails" 5/quiet \
    '| Date | Remediate by |' '|---|---|' '| 2026-03-04 | 9999-99-99 |'
check "29 February in a non-leap year fails" 5/quiet \
    '| Date | Remediate by |' '|---|---|' '| 2026-03-04 | 2026-02-29 |'
check "29 February in a leap year is accepted" 0/quiet \
    '| Date | Remediate by |' '|---|---|' '| 2026-03-04 | 2028-02-29 |'
check "31 April fails" 5/quiet \
    '| Date | Remediate by |' '|---|---|' '| 2026-03-04 | 2026-04-31 |'

# --- closing a row, and closing the file -------------------------------------
check "a struck-through first cell closes the row" 0/quiet \
    '| Date | Why | Remediate by |' '|---|---|---|' \
    '| ~~2026-03-04~~ | ~~prod incident~~ | **closed 2026-03-09, a1b2c3d** |'
check "~~ elsewhere in an open row does not close it" 0/overdue \
    '| Date | Why | Remediate by |' '|---|---|---|' \
    '| 2026-03-04 | ~~cancelled~~ prod incident | 2026-03-11 |'
check "a header-only table passes" 0/quiet \
    '| Date | Remediate by |' '|---|---|'
# R8: a file with no table hard-failed with "no Remediate by column", so a team
# that closed its last exception by removing the rows could neither empty the file
# nor delete it, and every PR broke with a message that described the wrong problem.
check "a file with prose and no table passes" 0/quiet \
    '# Exceptions' '' 'No exceptions are currently open.'
check "an empty file passes" 0/quiet ''
check "an aligned separator row is not mistaken for data" 0/quiet \
    '| Date | Remediate by |' '|:---|---:|'

rm -rf "$TMP"

echo
echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ] || exit 1
