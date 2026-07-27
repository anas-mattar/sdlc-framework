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

# Is this basename a TEST file? Split into TOKENS at `.`, `_` and `-`, and ask
# whether any token IS the word test/tests/spec/specs -- or ends with it in
# CamelCase, which is how .NET, Java and Scala name theirs.
#
# The rule used to be the substring `*[Tt]est*`, and a substring is not a word:
# `git mv src/ledger.ts src/latest-ledger.ts` took the count from 1 to 0 on both
# implementations, and `protest.go`, `contest.rb`, `Greatest.cs` and
# `attestation.ts` were invisible to the ratchet for as long as they existed.
# Renaming a file is not a code review event, so that is a hole anyone could walk
# through without meaning to.
#
# Erring the other way is deliberate: `Testing.cs` and `TestHelpers.cs` are now
# SOURCE, so their markers count. A ratchet that counts too much fails loudly and
# gets fixed; one that counts too little reports a floor nobody is standing on.
#
# Mirrored token for token in check-stubs.ps1's Test-IsTestName.
is_test_name() {  # is_test_name <basename>
    _ifs=$IFS
    IFS='._-'
    set -f                        # a token like `*` must not glob
    # shellcheck disable=SC2086
    set -- $1
    set +f
    IFS=$_ifs
    for _t in "$@"; do
        case "$_t" in
            test|tests|Test|Tests|spec|specs|Spec|Specs) return 0 ;;
            # CamelCase: `OrderTests`, `UserSpec`. A lower-case letter or digit
            # before the capital is what keeps `Greatest` out -- its `test` is
            # lower case and so is not a word boundary.
            *[a-z0-9]Test|*[a-z0-9]Tests|*[a-z0-9]Spec|*[a-z0-9]Specs) return 0 ;;
        esac
    done
    return 1
}

# Source files only. Tests are excluded because a TODO in a test is a note about a
# test, not shipped behaviour; docs and specs are excluded because prose about
# future work is the point of a roadmap. Vendored and generated trees are not ours.
#
# Every rule below is duplicated, EXACTLY, in check-stubs.ps1's Test-IsSource, and
# tests/framework-checks.sh feeds both the same path list and diffs the answers
# AGAINST THE VERDICT WRITTEN IN THE FIXTURE -- parity alone would let both sides
# be gutted together and still agree.
#
# The locals are `_p`/`_b`, not `p`/`b`. POSIX sh has no function-local variables,
# so the bare names clobbered the caller's loop variable: `--classify` echoed the
# path the function had left behind rather than the one it was asked about, which
# would have named the wrong file in any FAIL this fixture ever produced.
is_source() {  # is_source <path>
    _p=${1%"${1##*[!/]}"}         # trailing slashes are not part of a filename
    # Fold backslashes only when there are any. This runs once per tracked file,
    # and a `tr` per file cost thirty seconds on Windows for a substitution that
    # is a no-op on every path `git ls-files` ever prints.
    case "$_p" in *\\*) _p=$(printf '%s' "$_p" | tr '\\' '/') ;; esac
    _b=${_p##*/}
    case "$_b" in
        # The checker itself names every marker it hunts for, in its own regex and
        # its own comments. Left in, it would count six of its own lines on a clean
        # repo -- a number nobody can explain and everybody learns to ignore.
        check-stubs.sh|check-stubs.ps1) return 1 ;;
        # THE FRAMEWORK'S OWN INSTALLED TOOLING IS NOT PROJECT SOURCE. The first
        # real v2.2.0 -> v2.3.0 upgrade rehearsal caught this: a fresh multi-repo
        # install with ZERO application code baselined at 1, because the word TODO
        # appears in a COMMENT inside tooling/ci/gate-ci.sh. Appending one more
        # explanatory `# TODO:` line to that script then made the ratchet FAIL on a
        # project whose own code had not changed -- so any framework release that
        # edits a comment in its own tooling breaks every consuming project's
        # ratchet. A marker in these files is upstream's prose about deferred work;
        # it was never the project's.
        gate.sh|gate.ps1|gate-ci.sh) return 1 ;;
        # A leading-dot file with no further extension is configuration, not code.
        # `.gitignore` counted as source while README.md did not, purely because
        # this deny-list happened to name one and not the other. A dotfile WITH a
        # code extension (.eslintrc.js) is still source -- see the case below.
        .*) case "$_b" in *.*.*) ;; *) return 1 ;; esac ;;
        # Extensions are matched case-INSENSITIVELY (PowerShell's -match is, so the
        # bracket classes are how the .sh agrees with it rather than the other way
        # round -- `README.MD` must not be source on one platform only).
        *.[Mm][Dd]|*.[Tt][Xx][Tt]|*.[Jj][Ss][Oo][Nn]|*.[Yy][Mm][Ll]|\
        *.[Yy][Aa][Mm][Ll]|*.[Cc][Ss][Vv]|*.[Ss][Vv][Gg]|\
        *.[Ll][Oo][Cc][Kk]|*.[Ss][Uu][Mm]) return 1 ;;
        *.min.js) return 1 ;;
    esac
    is_test_name "$_b" && return 1
    case "/$_p" in
        */node_modules/*|*/vendor/*|*/dist/*|*/build/*) return 1 ;;
        */test/*|*/tests/*|*/Test/*|*/Tests/*|*/__tests__/*|*/spec/*|*/specs/*) return 1 ;;
    esac
    # Framework-owned DIRECTORIES, matched on the path rather than the basename so
    # a project's own `src/tooling/ci/pipeline.ts` stays source. Anchored with a
    # leading `/` on both sides of the comparison, so `.claude/` matches at the repo
    # root or under a sub-repo path and `app/github/webhook.go` does not.
    case "/$_p" in
        */.claude/*|*/.github/*) return 1 ;;
    esac
    # Deliberately NO `*/tooling/ci/*` rule. The only framework file that lands
    # there is gate-ci.sh, already excluded by basename above, and a directory rule
    # swallowed a project's own `src/tooling/ci/pipeline.ts` -- real source, in a
    # directory that merely shares a name. Excluding a path because it resembles the
    # framework's layout is how a ratchet stops counting the code it exists for.
    # The per-platform CI wrapper filenames, which live at a repo root.
    case "$_p" in
        azure-pipelines.yml|bitbucket-pipelines.yml|.gitlab-ci.yml) return 1 ;;
        */azure-pipelines.yml|*/bitbucket-pipelines.yml|*/.gitlab-ci.yml) return 1 ;;
    esac
    case "$_p" in
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
#
# `--` before the paths, always. Without an option terminator a REPOSITORY FILE
# NAMED LIKE A FLAG becomes one: with `-q` in the tree grep went quiet and the
# count fell to zero, `-i` re-enabled the case-insensitive matching this pair was
# rewritten to remove, and `-e` swallowed the pattern. A filename is data.
#
# GREP'S STDERR IS FATAL, NOT DISCARDED. `2>/dev/null` here was hiding the two
# ways this function can fail while still exiting 0:
#
#   Argument list too long   the whole file list was passed to one exec, so a
#         large repository exceeded ARG_MAX. grep never ran, wrote to a stream
#         nobody read, and the trailing `grep -vE` succeeded -- so the ratchet
#         reported STUBS: 0, printed "improved", exited 0, and invited the user to
#         write 0 into the PINNED baseline. Measured on a synthetic repo: 1202
#         files, 2.18 MB of paths, one real marker, `--count` -> 0.
#   binary file matches      grep's notice goes to STDERR with exit status 0 and
#         the matching lines never reach stdout, so a UTF-16 source file -- an
#         ordinary artefact of a Windows editor -- contributed nothing to the
#         count. `-a` makes grep treat every input as text, which is what a marker
#         scan wants.
#
# A control that cannot determine an answer must block, never allow. Both of those
# were "report perfection", which is the one direction this framework's own
# non-functional requirements forbid outright.
# A SENTINEL FILE, not just `exit 4`.
#
# `count_stubs` is `all_stub_lines | wc -l`, and the left-hand side of a pipeline
# runs in a SUBSHELL. An `exit 4` in there kills the subshell and nothing else:
# `wc -l` then reads the empty stream, prints 0, and the script carries on to
# report a clean tree -- the precise failure this whole change exists to remove,
# reintroduced by the fix for it. The flag file crosses the subshell boundary; the
# callers check it after the pipeline has finished.
SCAN_FAIL="${TMPDIR:-/tmp}/check-stubs-failed.$$"
rm -f "$SCAN_FAIL"

scan_failed() {  # scan_failed <stderr file>
    echo "check-stubs: the marker scan failed and its output cannot be trusted:" >&2
    sed 's/^/  /' "$1" >&2
    echo "  Refusing to report a count. A scan that errors and returns nothing" >&2
    echo "  looks exactly like a clean tree, which is how a ratchet turns itself off." >&2
    rm -f "$1"
    : > "$SCAN_FAIL"
    exit 4
}

# Call after any pipeline OR command substitution whose inner shell may have
# called scan_failed. It deliberately does NOT clear the flag: `current=$(count_stubs)`
# is itself a subshell, so the check inside count_stubs exits that subshell and the
# main shell has to ask again. Clearing on the first ask would answer "fine" to the
# second. The flag is cleared once, at startup, and on the successful paths out.
assert_scan_ok() {
    [ -f "$SCAN_FAIL" ] && exit 4
    return 0
}

#
# THE EXEMPTION APPLIES TO THE MATCHED TEXT, NEVER TO THE PATH. `grep -H` prefixes
# every match with `<path>:<lineno>:`, and running the exemption filter over the
# whole line meant the string only had to appear SOMEWHERE:
#
#     mkdir -p 'src/approved-stub: deferred'
#     git mv src/ledger.ts 'src/approved-stub: deferred/'
#
# and every marker in every file beneath that directory left the ratchet, silently.
# One `git mv` into a plausibly-named folder, no message, unlimited scope -- the
# same "a rename is not a code-review event" argument this file already makes about
# `latest-ledger.ts`. It was also a divergence: check-stubs.ps1 filters `$_.Line`,
# so the shell counted 1 where PowerShell counted 4.
#
# The prefix is stripped with awk rather than `cut -d:`, because a path may contain
# a colon: the first two colon-delimited fields are dropped only after the known
# line-number field is located, and the remainder -- the actual source line -- is
# what the exemption sees. The path is still printed, because callers parse it.
exempt_filter() {
    awk -v ex="$EXEMPT" '
        {
            # Find `:<digits>:` -- the line-number field grep inserts. Search from
            # the left and take the FIRST such field, so a path containing digits
            # between colons cannot shift the split.
            rest = $0; off = 0
            while (match(rest, /:[0-9]+:/)) {
                off += RSTART + RLENGTH - 1
                break
            }
            if (off == 0) { print; next }          # not grep -nH output; pass through
            text = substr($0, off + 1)
            if (text ~ ex) next                    # exempted, on the TEXT alone
            print
        }'
}

stub_lines() {  # stub_lines <file>...
    _err="${TMPDIR:-/tmp}/check-stubs-err.$$"
    : > "$_err"
    grep -anHE "$MARKERS" -- "$@" 2>"$_err" | exempt_filter
    [ -s "$_err" ] && scan_failed "$_err"
    rm -f "$_err"
}

# Every tracked-or-untracked path, ONE PER LINE, whatever is in the name.
#
# Tracked files plus untracked-but-not-ignored ones: the gate runs on a dirty
# tree, and a stub added in an uncommitted file is exactly what this catches.
#
# Two flags carry the whole safety of this function:
#
#   core.quotePath=false  git's DEFAULT renders any non-ASCII path as a quoted C
#         string -- `src/caf\303\251.ts` comes back as `"src/caf\303\251.ts"`,
#         which is not the name of any file. The `[ -f ]` test below then failed
#         and the file was skipped in silence, on every platform, so
#         `mv ledger.ts ledgeŕ.ts` removed its markers from the count with no
#         message. The .ps1 twin defaulted the same way and had the same hole.
#   -z    NUL-delimited output, so a path containing a space or a glob character
#         arrives whole. The old `for f in $(git ls-files)` word-split
#         `src/my file.ts` into two non-existent paths and expanded `*.ts`
#         against the working directory.
#
# POSIX `read` cannot split on NUL (`read -r -d ''` is a bashism and this script
# runs under dash), so the stream is re-delimited: any newline INSIDE a path is
# folded to \001 first, then NUL becomes the line separator. One line is then
# always exactly one path, and the fold is undone below.
tracked_paths() {
    git -c core.quotePath=false ls-files -z --cached --others --exclude-standard 2>/dev/null \
        | tr '\n\0' '\1\n'
}

SOH=$(printf '\001')

# ONE grep per BATCH rather than one per file. Two forks per file took thirty
# seconds on a repository of eighty files, and this script runs inside the gate,
# which is meant to be run often. `-H` forces the filename prefix even when a batch
# happens to be one file, so the output shape does not change with the size of the
# repo -- and it is the shape check-stubs.ps1 prints too.
#
# BATCHED THROUGH xargs, NOT ACCUMULATED INTO `$@`. The previous version built the
# entire file list into the positional parameters and handed it to a single exec.
# That is correct for spaces, quotes and globs -- and it breaks at ARG_MAX, where
# the exec never happens at all. Because grep's stderr was discarded and the
# trailing filter still succeeded, a repository too large to scan reported zero
# markers and passed. `xargs -0` splits the list into as many execs as the system
# allows, which removes the ceiling; `-r` stops it running grep at all on an empty
# list, so a genuinely empty selection produces no output rather than a scan of the
# current directory.
#
# The NUL-delimited stream feeds xargs directly, so no re-quoting happens anywhere:
# a path containing a space, a quote, a backslash or a glob character survives.
# Newlines inside paths are still folded to \001 by tracked_paths for the `is_source`
# loop and unfolded here before the path is emitted.
#
# grep exits 1 when a batch has no match, and xargs turns any non-zero child status
# into 123. Neither is an error for us -- most batches legitimately contain no
# markers -- so the status is ignored here and correctness is enforced by
# stub_lines' stderr check instead, which fires on the failures that actually
# matter.
all_stub_lines() {
    _list="${TMPDIR:-/tmp}/check-stubs-list.$$"
    _err="${TMPDIR:-/tmp}/check-stubs-err.$$"
    : > "$_list"; : > "$_err"

    while IFS= read -r _line; do
        [ -n "$_line" ] || continue
        case "$_line" in *"$SOH"*) _line=$(printf '%s' "$_line" | tr '\1' '\n') ;; esac
        is_source "$_line" || continue
        [ -f "$_line" ] || continue
        printf '%s\0' "$_line" >> "$_list"
    done <<EOF
$(tracked_paths)
EOF

    if [ ! -s "$_list" ]; then
        # No source files selected. Legitimate on a docs-only repo, and NOT
        # legitimate when the enumeration itself failed -- and those two look
        # identical from here, so distinguish them: if git listed nothing at all,
        # this is not a repository we can scan and saying "0 markers" would be a
        # verdict about a tree we never read.
        if [ -z "$(tracked_paths | head -c 1)" ]; then
            echo "check-stubs: git listed no files in this directory." >&2
            echo "  Either this is not a git repository, or the working tree is empty." >&2
            echo "  Refusing to report 0 markers: a scan that saw nothing and a tree" >&2
            echo "  with nothing in it are not the same answer." >&2
            rm -f "$_list" "$_err"
            : > "$SCAN_FAIL"
            exit 4
        fi
        rm -f "$_list" "$_err"
        return 0
    fi

    # A UTF-16 source file is unreadable to a byte-oriented marker scan: `TODO`
    # is stored as T\0O\0D\0O\0, so the pattern cannot match and the file
    # contributes zero. That is an ordinary artefact of a Windows editor, and
    # Windows is this framework's primary platform -- so `mv` a file into UTF-16
    # and its markers leave the ratchet. `-a` fixes the NUL-byte case (grep used to
    # call those files binary, write a notice to stderr and print nothing) but it
    # cannot fix an encoding. Refuse instead of undercounting in silence.
    _wide=$(xargs -0 -r sh -c '
        for f do
            case $(od -An -N2 -tx1 <"$f" 2>/dev/null | tr -d " ") in
                fffe|feff) printf "%s\n" "$f" ;;
            esac
        done' _ < "$_list" 2>/dev/null)
    if [ -n "$_wide" ]; then
        echo "check-stubs: these source files are UTF-16 and cannot be scanned for markers:" >&2
        printf '%s\n' "$_wide" | sed 's/^/  /' >&2
        echo "  A UTF-16 file stores TODO as T\\0O\\0D\\0O\\0, so every marker in it is" >&2
        echo "  invisible to this scan and would silently leave the ratchet." >&2
        echo "  Convert them to UTF-8 (git can do it: 'working-tree-encoding=UTF-16'" >&2
        echo "  in .gitattributes keeps the editor happy and the repository readable)." >&2
        rm -f "$_list" "$_err"
        : > "$SCAN_FAIL"
        exit 4
    fi

    xargs -0 -r grep -anHE "$MARKERS" -- < "$_list" 2>"$_err" | exempt_filter
    if [ -s "$_err" ]; then
        rm -f "$_list"
        scan_failed "$_err"
    fi
    rm -f "$_list" "$_err"
}

# `wc -l`, not `grep -c ''`. `grep -c` prints 0 AND EXITS 1 when nothing matches,
# so `|| echo 0` fired as well and this function returned the two-line string
# "0\n0" on any tree with no markers -- which is the state every project adopting
# the ratchet on a clean codebase starts in. Downstream that wrote a corrupt
# `0\n0` into the pinned baseline file, made every `[ "$current" -gt ... ]`
# comparison die with "Illegal number", and -- because a failed `[` is false --
# fell through to `exit 0`, so the ratchet passed inertly. `wc -l` exits 0 on
# empty input and has no such second channel.
count_stubs() {
    _n=$(all_stub_lines | wc -l | tr -d ' ')
    assert_scan_ok
    printf '%s' "$_n"
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
# Asked again in the MAIN shell. The line above is a command substitution, so an
# `exit` inside count_stubs ends that subshell and nothing more -- which is how the
# first version of this very fix still reported a clean tree on a repository it had
# failed to read.
assert_scan_ok
rm -f "$SCAN_FAIL"

if [ "${1:-}" = "--count" ]; then
    echo "$current"
    exit 0
fi

if [ "${1:-}" = "--baseline" ]; then
    echo "$current" > "$BASELINE_FILE"
    echo "STUBS: baseline set to $current — commit $BASELINE_FILE."
    echo "  Pin it too, in the same commit:  sha256sum gate.sh gate.ps1 check-stubs.sh check-stubs.ps1 $BASELINE_FILE tooling/ci/gate-ci.sh > .gate-sha256"
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
    assert_scan_ok
    exit 1
fi

if [ "$current" -lt "$baseline" ]; then
    echo "STUBS: $current (baseline $baseline) — improved. Lower the baseline:"
    echo "    sh check-stubs.sh --baseline"
    exit 0
fi

echo "STUBS: $current (baseline $baseline)"
exit 0
