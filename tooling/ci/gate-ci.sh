#!/usr/bin/env sh
# The CI gate's enforcement steps — the mechanical backstop, in one place.
#
#     sh tooling/ci/gate-ci.sh <step>
#
# Steps, in the order `all` runs them:
#
#   pin                       .gate-sha256 names and matches every gate file
#   override-not-committed    .claude/allow-package-changes is not tracked
#   stub-ratchet              the unimplemented-marker count has not risen
#   exceptions                no open exception is past its remediation date
#   verify-guards             the configured PreToolUse hooks actually block
#   run-gate                  the repository's own gate script, unmodified
#   all                       every step above, stopping at the first failure
#
# ---------------------------------------------------------------------------
# WHY THIS IS A SCRIPT AND NOT A PIPELINE FILE
#
# The framework supports four hosting platforms, and each wants the gate written
# in its own YAML dialect. Writing these steps four times would create four twins
# that must agree — and this framework's entire defect history is twins that
# stopped agreeing, in the copy nobody remembered to bring along. The 250-line
# exceptions parser in particular has had five separate bugs, every one of which
# made it pass silently.
#
# So the logic lives here, once, in POSIX shell that every runner already has,
# and the per-platform files under tooling/ci/<platform>/ are thin wrappers that
# check out the repository and invoke these steps. A new platform is a wrapper,
# not a port. `tests/framework-checks.sh` asserts that every wrapper invokes
# every step, because a wrapper that quietly drops one is the obvious failure.
#
# ---------------------------------------------------------------------------
# WHAT THIS DOES AND DOES NOT GUARANTEE. Read this before trusting it.
#
# CI runs a script that lives in the repository, from the change request's own
# head branch. So "CI is not run by the party being checked" holds for the
# *execution* and not for the *definition*: an agent that edits `gate.sh` to
# `true` and then runs it honestly produces a receipt that is genuine in every
# checkable respect and a green CI job, while the test suite still fails. This
# does not take malice — an agent whose lint step trips on pre-existing warnings,
# reading that the gate script is the only place gate commands are defined, may
# reasonably conclude that adjusting the gate is the sanctioned way to adjust it.
#
# The `pin` step is what closes that. It does NOT make `gate.sh` unmodifiable —
# nothing in-repo can. What it does is make a modification *impossible to land
# silently*: changing the gate now requires changing `.gate-sha256` in the same
# change request, which is a one-line diff a reviewer cannot miss and code
# ownership can require a specific human to approve.
#
# The same caveat applies to the pipeline files and to THIS script: most
# platforms run the pipeline definition from the head branch, so a change request
# can weaken its own required check. Put the CI directory and `tooling/ci/` under
# code ownership — see tooling/ci/<platform>/ — and require review from someone
# who is not the author.
# ---------------------------------------------------------------------------

set -u

fail() { printf '%s\n' "$@"; exit 1; }

# --- pin --------------------------------------------------------------------
# Fail closed. A missing pin file is indistinguishable from a deleted one, so
# treat it as a failure rather than skipping the check — the whole point is that
# weakening the gate cannot be done quietly.
#
# `sha256sum -c` verifies the lines it is GIVEN. It says nothing about the lines
# it is not given, so a pin file that names some other file passes with
# `README.md: OK` and rc=0 while gate.sh sits unpinned:
#
#     echo 'exit 0' > gate.sh
#     sha256sum README.md > .gate-sha256
#     sha256sum -c .gate-sha256      # README.md: OK, rc=0
#
# That is not a theoretical hole. The install guard's perimeter block
# deliberately does NOT protect gate.sh, .gate-sha256, check-stubs.* or
# .gate-stubs-baseline, on the stated grounds that they are "pinned by CI and
# owned by the code-ownership rules" — so the delegation has to be real.
# Asserting that the pin NAMES its subjects is what makes it real.
#
# And naming is not enough on its own. The coverage test used to accept `$2` of
# ANY line, while `sha256sum -c` treats a `#`-leading line as a comment and skips
# it silently — so a pin file listing every gate file as a comment, plus one real
# hash for README.md, satisfied both halves at once and left the whole gate
# unpinned. The naming line must therefore carry a well-formed digest; `--strict`
# does not help, because a comment is legal in a checksum file.
#
# The stub ratchet is in the list for the same reason: `echo 9999 >
# .gate-stubs-baseline` turns the ratchet off and the script then prints
# "improved" and exits 0, congratulating you for disabling it.
#
# The .ps1 halves are in the list because two hooks say they are: guard-installs.*
# leaves `check-stubs.*` and `gate.*` out of its perimeter on the stated grounds
# that they are pinned here. A pin that named only the .sh halves left the
# delegation half-true, and the .ps1 ratchet — the one the Windows developer
# actually runs — editable in silence.
#
# Each name is required only if the file EXISTS: a POSIX-only team has no gate.ps1
# to pin, and demanding a hash for a file that is not there would fail a correct
# install. What this will not tolerate is a file that exists and is not named.
PINNED='gate.sh gate.ps1 check-stubs.sh check-stubs.ps1 .gate-stubs-baseline'

step_pin() {
    present=""
    for f in $PINNED; do
        [ -f "$f" ] && present="$present $f"
    done
    if [ -z "$present" ]; then
        fail "MISSING: none of '$PINNED' exists in this repository." \
             "  Either the gate was never installed here, or it has been deleted."
    fi
    if [ ! -f .gate-sha256 ]; then
        fail "MISSING: .gate-sha256 — the gate script is unpinned, so a change to" \
             "  gate.sh would land without anyone having to acknowledge it." \
             "  Create it with:  sha256sum$present > .gate-sha256"
    fi
    missing=""
    for f in $present; do
        # `$1` must be a real 64-hex digest and `$2` the filename column; a
        # leading `*` on the name means the hash was taken in binary mode.
        # Requiring the digest is what stops a commented-out name counting as
        # coverage.
        awk -v want="$f" '$1 ~ /^[0-9a-fA-F]{64}$/ {
                              sub(/^\*/, "", $2); if ($2 == want) found = 1
                          }
                          END { exit found ? 0 : 1 }' .gate-sha256 || missing="$missing $f"
    done
    if [ -n "$missing" ]; then
        fail "UNPINNED: .gate-sha256 does not carry a hash for:$missing" \
             '  A pin only covers the lines it contains, and a commented-out name is' \
             '  not a line sha256sum -c will ever check. Regenerate it with:' \
             "    sha256sum$present > .gate-sha256"
    fi
    # Count what was actually verified. Junk, comments and malformed lines are
    # skipped in silence by `sha256sum -c`, so a file can be mostly decoration
    # and still report OK on the one line that parses.
    checked=$(sha256sum -c .gate-sha256 2>/dev/null | grep -c ': OK$')
    lines=$(grep -c '[^[:space:]]' .gate-sha256)
    if ! sha256sum -c .gate-sha256; then
        fail "" \
             "CHANGED: a pinned file does not match .gate-sha256." \
             "  If this change is intended, regenerate the pin in this same change request:" \
             "    sha256sum$present > .gate-sha256" \
             "  and say in the description what the gate now does differently." \
             "  If it is not intended, the gate has been weakened — find out by whom."
    fi
    if [ "$checked" -ne "$lines" ]; then
        fail "" \
             "UNCHECKED: .gate-sha256 has $lines non-blank lines but sha256sum -c" \
             "  verified only $checked of them. The rest are comments or malformed," \
             "  and a line this file does not check is a line that proves nothing." \
             "  Regenerate it with:  sha256sum$present > .gate-sha256"
    fi
}

# --- override-not-committed --------------------------------------------------
# The package guard is disabled for as long as this marker exists. It is meant to
# be created by a human, used for one approved change, and deleted when the phase
# commits. Committing it makes that "temporarily open" state permanent and
# shared — and /framework-doctor, which finds the residue, runs after setup and
# after upgrade, never during phase work.
step_override_not_committed() {
    if git ls-files --error-unmatch .claude/allow-package-changes >/dev/null 2>&1; then
        fail "COMMITTED: .claude/allow-package-changes is tracked in git." \
             "  While it exists the package guard permits every manifest edit and" \
             "  every install command, for everyone who clones this repo." \
             "  Remove it:  git rm --cached .claude/allow-package-changes" \
             "  and add it to .gitignore."
    fi
}

# --- stub-ratchet ------------------------------------------------------------
# Nothing else in the framework requires the implementation to be REAL. A phase
# can persist a value, leave the block holding the feature's core invariant empty
# behind a TODO, write tests that assert a status code and the presence of a
# field, pass the build, earn a GENUINE valid receipt, tick every review box, and
# reach "Done pending human review".
#
# A ratchet rather than a threshold: brownfield repos legitimately start with
# hundreds of markers, and demanding zero would be ignored within a week. What it
# forbids is the number going up. `approved-stub: <where the spec defers it>` on
# the line exempts a deliberate placeholder, so a deferral is declared and
# reviewable instead of invisible.
step_stub_ratchet() {
    [ -f ./check-stubs.sh ] || fail \
        "MISSING: ./check-stubs.sh — the stub ratchet is not installed here." \
        "  Reinstall it (SETUP.md step 5) or delete this step rather than" \
        "  shipping a check that cannot fail."
    chmod +x ./check-stubs.sh
    ./check-stubs.sh
}

# --- exceptions --------------------------------------------------------------
# An exception path with no cost is just the process, and gets used for
# convenience within a month. This charges the debt to whoever tries to move NEXT
# rather than to whoever incurred it, which is the only pressure that reliably
# beats the pressure that created the exception in the first place. Struck-through
# rows are closed and ignored. No exceptions file is fine.
#
# ONE awk pass, deliberately. The first version piped through a `while` loop, and
# a `while` returns the status of the last command in its body: when the last date
# scanned was NOT overdue the `&&` list returned 1, so the pipeline returned 1, so
# the command substitution returned 1, and a `-e` shell killed the step before the
# `if` was ever evaluated. A single legitimate open exception with a future date
# therefore failed every change request, with no output at all — and a genuinely
# overdue row that was not the LAST row exited 1 without ever printing the OVERDUE
# message or its guidance. The file promises CI fails "while an open exception is
# past its remediation date"; it was wrong in both directions, and the predictable
# outcome of a step that fails silently and inexplicably is that someone deletes it.
#
# The remediation column is found by its HEADER, not by position. Anchoring to the
# last cell silently disabled the check for every row the moment anyone appended a
# Status column -- the most likely way a human-maintained table evolves. Scanning
# every cell instead is worse, not better: the FIRST column of this table is the
# date the exception was opened, which is in the past by definition, so it would
# report every open exception as overdue.
#
# Five things earlier header-bound versions got wrong, all of which made the check
# pass silently -- the failure mode this whole file exists to argue against -- and
# all of which are now hard failures instead:
#
#   1. The header was matched with `h ~ /remediate|remediation|dueby/`, so a column
#      called "Remediation notes" earlier in the table won and the real deadline
#      column was never read. The match is now EXACT, and two matching headers in
#      one table are an error rather than a coin toss.
#   2. `col` was bound once per FILE and never reset, so a second table with
#      different columns was read with the first table's index. It is now re-bound
#      per table -- a table is a maximal run of lines starting `|`.
#   3. A row with a missing cell (or a stray `|` inside a Why cell -- the most
#      likely typo in a hand-maintained table) shifted the date out of `$col` and
#      the row was silently skipped. A row whose cell count does not match its
#      header is now a FAILURE.
#   4. The date was shape-checked by regex and compared as a string, so
#      `2026-13-45` bought five months of silence and `9999-99-99` bought forever.
#      Month and day are now range-checked, leap years included.
#   5. `bound` was tracked per FILE while rows of an unbound table were skipped, so
#      ONE decoy table with a satisfied deadline disabled the deadline check for
#      every other table in the file. A table that has data rows and no deadline
#      column is now an error in its own right, not a skip.
#
# The strikethrough test is scoped to the first cell: `grep -v '~~'` dropped a row
# if `~~` appeared ANYWHERE in it, so `~~cancelled~~ prod incident` in the Why cell
# closed a row that was still open.
#
# A file with no table at all is FINE. Deleting the ROWS of a file that had them is
# not: it erases every open exception and its deadline exactly as deleting the file
# does, and for three releases only the second was detected.
step_exceptions() {
    f=docs/exceptions.md
    had_rows_before=0
    if [ -n "$(git log --oneline -1 -- "$f" 2>/dev/null)" ]; then
        git show "HEAD:$f" 2>/dev/null | grep -qE '^[[:space:]]*\|' && had_rows_before=1
    fi
    if [ ! -f "$f" ]; then
        if [ -n "$(git log --oneline -1 -- "$f" 2>/dev/null)" ]; then
            fail "DELETED: $f existed in this repository's history and is gone." \
                 "  Close exceptions by striking the row through, not by deleting" \
                 "  the file: a deleted file passes this check with no open rows."
        fi
        return 0
    fi
    today=$(date -u +%Y-%m-%d)
    # `|| st=$?` and not a bare assignment: a command substitution that exits
    # non-zero fails the assignment, and under a `-e` shell that kills the step
    # before anything below runs. That is the bug this rewrite exists to fix; do
    # not simplify it back.
    #
    # Exit codes out of the awk: 0 fine (overdue rows, if any, on stdout), 3 no
    # table in the file carries a deadline column, 4 one table carries two, 5 a row
    # could not be read, 6 a table has rows but no deadline column. All print their
    # detail on stdout.
    st=0
    # EXCEPTIONS-AWK-BEGIN
    # tests/exceptions-check.sh extracts these lines and runs them against a table
    # of cases, so the shipped program is what the tests exercise. Keep the markers.
    out=$(awk -v t="$today" -F'|' '
      function trim(s) { gsub(/^[ \t\r]+|[ \t\r]+$/, "", s); return s }
      function realdate(d,   y, mo, da, dim) {
        if (d !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) return 0
        y = substr(d, 1, 4) + 0; mo = substr(d, 6, 2) + 0; da = substr(d, 9, 2) + 0
        if (y < 1970 || y > 2999 || mo < 1 || mo > 12 || da < 1) return 0
        dim = 31
        if (mo == 4 || mo == 6 || mo == 9 || mo == 11) dim = 30
        else if (mo == 2) dim = (y % 4 == 0 && (y % 100 != 0 || y % 400 == 0)) ? 29 : 28
        return da <= dim
      }
      !/^[[:space:]]*\|/ { intable = 0; col = 0; hdr = 0; next }
      {
        rows++
        if (!intable) {
          intable = 1; hdr = NF; col = 0; tblrows = 0
          for (i = 2; i <= NF; i++) {
            h = tolower($i); gsub(/[^a-z]/, "", h)
            if (h == "remediateby" || h == "dueby") {
              if (col) {
                print "  line " NR ": two deadline columns in one table"
                # A flag, not a bare `exit 4`: `exit` runs END, and END has its own
                # `exit`, which would overwrite this status with 3.
                dup = 1; exit
              }
              col = i
            }
          }
          if (col) bound = 1
          next
        }
        sep = 1; dashes = 0
        for (i = 2; i <= NF; i++) {
          c = trim($i)
          if (c == "") continue
          if (c ~ /^:?-+:?$/) dashes++; else { sep = 0; break }
        }
        if (sep && dashes) next
        # A DATA row. Counted before the deadline column is consulted, so a table
        # with rows and no deadline column is visible rather than skipped.
        tblrows++
        if (col == 0) {
          if (tblrows == 1) {
            print "  line " NR ": this table has rows but no deadline column,"
            print "           so none of its exceptions can ever be overdue:"
            print "           " $0
          }
          unbound = 1; next
        }
        if (NF != hdr) {
          print "  line " NR ": this row is not the same width as its header,"
          print "           so which cell holds the deadline cannot be decided:"
          print "           " $0
          shape = 1; next
        }
        if (trim($2) ~ /~~/) next
        c = trim($col); gsub(/^[*_`~]+|[*_`~]+$/, "", c); c = trim(c)
        if (!realdate(c)) {
          print "  line " NR ": deadline is \"" trim($col) "\", which is not a real date"
          shape = 1; next
        }
        if (c < t) over = over "  " $0 "\n"
      }
      END {
        if (dup) exit 4
        if (rows == 0) exit 0
        if (!bound) exit 3
        if (unbound) exit 6
        if (shape) exit 5
        printf "%s", over
      }' "$f") || st=$?
    # EXCEPTIONS-AWK-END
    case "$st" in
        0) ;;
        3) fail "MALFORMED: no table in $f has a 'Remediate by' column." \
                "  That column is what this check reads; without it no exception has" \
                "  a deadline and this step would pass no matter what the table says." \
                "  A file with no table at all is fine — this is a table whose header" \
                "  is missing, misspelled, or written below its own data rows." \
                "  See docs/process/exceptions.md for the table format." ;;
        4) printf 'MALFORMED: %s has two deadline columns in one table.\n' "$f"
           printf '  Which one is binding cannot be decided, and guessing is how a\n'
           printf '  check starts reading the wrong cell. Keep one.\n'
           printf '%s\n' "$out"; exit 1 ;;
        5) printf 'MALFORMED: %s has rows this check cannot read.\n' "$f"
           printf '  A row whose cell count differs from its header, or whose deadline\n'
           printf '  is not a real calendar date, is not skipped — skipping it is how an\n'
           printf '  exception outlives its deadline with nobody noticing.\n'
           printf '%s\n' "$out"; exit 1 ;;
        6) printf 'MALFORMED: %s has a table with rows and no deadline column.\n' "$f"
           printf '  Rows in such a table were skipped, so ONE table with a satisfied\n'
           printf '  deadline used to hide every overdue row in every other table.\n'
           printf '  Give every table a "Remediate by" column, or no rows.\n'
           printf '%s\n' "$out"; exit 1 ;;
        *) printf 'MALFORMED: reading %s failed with status %s.\n' "$f" "$st"
           printf '%s\n' "$out"; exit 1 ;;
    esac
    # Rows present in history and gone now: the same erasure as deleting the file,
    # one edit cheaper, and undetected until this check existed.
    if [ "$had_rows_before" = 1 ] && ! grep -qE '^[[:space:]]*\|' "$f"; then
        fail "EMPTIED: $f had exception rows in this repository's history and now has none." \
             "  Deleting the rows erases every open exception and its deadline exactly" \
             "  as deleting the file does. Close exceptions by striking the row" \
             "  through, so the history stays readable."
    fi
    if [ -n "$out" ]; then
        printf 'OVERDUE: an open exception is past its remediation date.\n'
        printf '  Remediate it or move the date with a named authoriser — see\n'
        printf '  docs/process/exceptions.md. This blocks every change request until it\n'
        printf '  is closed, which is the point: the cost lands on whoever moves next.\n\n'
        printf '%s\n' "$out"
        exit 1
    fi
}

# --- verify-guards -----------------------------------------------------------
# A PreToolUse hook that is misconfigured fails OPEN: Claude Code treats an
# unrunnable command as a hook ERROR, not a block, so the guard silently stops
# guarding and the only thing that says so is this script. It was shipped, and
# /framework-doctor ran it, but nothing ran it on a clean checkout — which is the
# one place the answer is not produced by the party being checked.
#
# THREE exit codes, and the third is the one worth knowing about. The verifier
# reads the command configured in settings.json; if that command's interpreter is
# not on the runner it falls back to the sibling hook and exits 3 — "partially
# verified". That is not a pass. settings.json ships the PowerShell commands, and
# most runners are Linux, so an install that never swapped them lands exactly
# here: the hooks Claude Code invokes are unrunnable, an unrunnable hook fails
# OPEN, and the verifier would otherwise have certified the twin it tested.
#
#   0  the configured hooks were run and they block
#   3  a DIFFERENT script was run — the configured one is untested
#   1  a guard is not enforcing
step_verify_guards() {
    if [ ! -f .claude/hooks/verify-guard.sh ]; then
        fail "MISSING: .claude/hooks/verify-guard.sh — the guards are unverified." \
             "  Reinstall the hooks (SETUP.md step 5) or delete this step rather" \
             "  than shipping a check that cannot fail."
    fi
    rc=0
    sh .claude/hooks/verify-guard.sh || rc=$?
    if [ "$rc" = 3 ]; then
        printf '\n'
        printf 'The guards may well be fine — what this job cannot say is that the\n'
        printf 'hooks CLAUDE CODE RUNS are fine, because they were not the ones tested.\n'
        printf 'Point settings.json at an interpreter this runner has (see above).\n'
    fi
    exit "$rc"
}

# --- run-gate ----------------------------------------------------------------
# gate.sh prints `EXIT: <code>` and exits with it, so a non-zero gate fails the
# job. Do not let any wrapper mark this step non-fatal — that turns the gate into
# a notification, and the framework's whole premise is that it is a gate.
step_run_gate() {
    [ -f ./gate.sh ] || fail \
        "MISSING: ./gate.sh — there is no gate to run in this repository."
    chmod +x ./gate.sh
    ./gate.sh
}

# --- dispatch ----------------------------------------------------------------
# STEPS is the contract every platform wrapper is checked against. Adding a step
# here without adding it to all four wrappers is a self-test failure, which is the
# point: a wrapper that silently runs five of six checks is the failure mode this
# whole arrangement exists to prevent.
STEPS='pin override-not-committed stub-ratchet exceptions verify-guards run-gate'

run_step() {
    case "$1" in
        pin)                    step_pin ;;
        override-not-committed) step_override_not_committed ;;
        stub-ratchet)           step_stub_ratchet ;;
        exceptions)             step_exceptions ;;
        verify-guards)          step_verify_guards ;;
        run-gate)               step_run_gate ;;
        *) fail "unknown step: $1" "  known steps: $STEPS all" ;;
    esac
}

case "${1:-}" in
    "")    fail "usage: sh tooling/ci/gate-ci.sh <step>" "  steps: $STEPS all" ;;
    steps) printf '%s\n' "$STEPS" ;;
    all)
        for s in $STEPS; do
            printf '\n--- %s ---\n' "$s"
            # A subshell, because verify-guards exits with the verifier's own
            # status and `all` must keep going to report which step stopped it.
            ( run_step "$s" ) || fail "" "GATE-CI: the '$s' step failed."
        done
        printf '\nGATE-CI: all steps passed.\n' ;;
    *) run_step "$1" ;;
esac
