#!/usr/bin/env sh
# Behavioural test for the PowerShell gates.
#
#     sh tests/gate-powershell.sh
#
# receipt-contract.sh exercises gate-node.sh only. The two .ps1 gates had no
# behavioural coverage at all -- which is how they shipped reporting EXIT: 0 and
# writing a valid receipt when the toolchain was missing. That is the primary
# control failing OPEN, on the platform tooling/claude/settings.json treats as
# primary, and no assertion anywhere could see it.
#
# Every case below is a state the .ps1 gates must get right and the .sh gates
# already do. SKIPs when pwsh is absent; it must not skip in CI.

set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORK="${TMPDIR:-/tmp}/sdlc-psgate-test-$$"
# Must be a SIBLING of $WORK, not a child: $WORK is a git repo, and anything
# beneath it is inside that repo, so git would succeed there and the
# unfingerprintable-tree case would silently test nothing.
NOREPO="${TMPDIR:-/tmp}/sdlc-psgate-norepo-$$"
pass=0
fail=0

cleanup() { rm -rf "$WORK" "$NOREPO"; }
trap cleanup EXIT

echo "PowerShell gate behaviour"

if ! command -v pwsh >/dev/null 2>&1; then
    echo "  SKIP  pwsh not installed -- the .ps1 gates are untested on this machine"
    exit 0
fi

mkdir -p "$WORK" || exit 1
cd "$WORK" || exit 1
git init -q .
git config user.email test@example.com
git config user.name "ps gate test"
mkdir -p src
echo "console.log('app')" > src/app.js
echo ".gate-result.json"  > .gitignore
git add -A
git commit -qm baseline

# Install the real gate, replacing only the body of the $Steps array. `git` stands
# in for the project's build tool: it is a native executable that is guaranteed
# present here, so $LASTEXITCODE behaves exactly as it would for yarn or dotnet.
make_gate() {  # make_gate <PowerShell array body>
    awk -v repl="$1" '
        /^\$Steps = @\(/ { print; print repl; skip = 1; next }
        skip && /^\)/    { print; skip = 0; next }
        skip             { next }
                         { print }
    ' "$ROOT/tooling/gate/gate-node.ps1" > gate.ps1
    if ! grep -q 'git\|definitelynot' gate.ps1; then
        echo "SETUP FAILED: could not rewrite \$Steps -- did gate-node.ps1 change shape?"
        exit 1
    fi
}

run()    { pwsh -NoProfile -File ./gate.ps1 "$@" >/dev/null 2>&1; }
verify() { pwsh -NoProfile -File ./gate.ps1 -Verify >/dev/null 2>&1; }

assert() {  # assert <label> <actual> <expected>
    if [ "$2" = "$3" ]; then
        pass=$((pass + 1)); printf '  PASS  %s\n' "$1"
    else
        fail=$((fail + 1)); printf '  FAIL  %s (got %s, want %s)\n' "$1" "$2" "$3"
    fi
}

# --- all steps green -------------------------------------------------------
make_gate '    @("git", "--version"),
    @("git", "status", "--short")'
run; rc=$?
assert "green gate exits 0"                     "$rc" "0"
verify; rc=$?
assert "green gate writes a valid receipt"      "$rc" "0"

# --- a one-step gate ------------------------------------------------------
# PowerShell flattens @( @("git", "--version") ) into @("git", "--version"), so a
# project that trims its gate to a single step would iterate over the characters
# of its own command name and report a baffling 127. Plausible customisation, and
# the failure looks exactly like "the toolchain is missing".
make_gate '    @("git", "--version")'
run; rc=$?
assert "a one-step gate runs its step"          "$rc" "0"
verify; rc=$?
assert "a one-step gate writes a valid receipt" "$rc" "0"

# --- a step fails ----------------------------------------------------------
make_gate '    @("git", "--version"),
    @("git", "rev-parse", "--verify", "no-such-ref")'
run; rc=$?
assert "a failing step fails the gate"          "$([ "$rc" -ne 0 ] && echo nonzero || echo zero)" "nonzero"
verify; rc=$?
assert "a failed gate is rejected by -Verify"   "$rc" "1"

# --- the toolchain is missing ---------------------------------------------
# $LASTEXITCODE is set only by a NATIVE executable. An unresolvable command raises
# CommandNotFoundException and leaves it $null; [int]$null is 0, so before the fix
# this arm produced EXIT: 0, a receipt reading {"exit": 0, "mode": "full"}, and
# RECEIPT: valid -- while gate.sh on the same tree answered EXIT: 127.
make_gate '    @("definitelynotacommand", "build")'
rm -f .gate-result.json
run; rc=$?
assert "a missing toolchain fails the gate"     "$([ "$rc" -ne 0 ] && echo nonzero || echo zero)" "nonzero"
if [ -f .gate-result.json ]; then
    grep -q '"exit": 0' .gate-result.json \
        && { fail=$((fail + 1)); echo "  FAIL  a missing toolchain recorded exit 0 in the receipt"; } \
        || { pass=$((pass + 1)); echo "  PASS  a missing toolchain records a non-zero exit"; }
else
    pass=$((pass + 1)); echo "  PASS  a missing toolchain records a non-zero exit"
fi
verify; rc=$?
assert "a missing toolchain is rejected by -Verify" "$rc" "1"

# --- the tree cannot be fingerprinted -------------------------------------
# Outside a git repo every call in Get-GateFingerprint fails and the answer is the
# literal "unknown". Before the fix the receipt recorded it, and "unknown" -eq
# "unknown" made that receipt valid forever, whatever changed on disk. The
# realistic trigger in production is `fatal: detected dubious ownership`.
make_gate '    @("git", "--version")'
mkdir -p "$NOREPO/src"
cp gate.ps1 "$NOREPO/gate.ps1"
echo "x" > "$NOREPO/src/app.js"
( cd "$NOREPO" && pwsh -NoProfile -File ./gate.ps1 >/dev/null 2>&1 ); rc=$?
assert "an unfingerprintable tree fails the gate" "$([ "$rc" -ne 0 ] && echo nonzero || echo zero)" "nonzero"
if [ -f "$NOREPO/.gate-result.json" ]; then
    fail=$((fail + 1)); echo "  FAIL  a receipt was written for an unfingerprintable tree"
else
    pass=$((pass + 1)); echo "  PASS  no receipt is written for an unfingerprintable tree"
fi

# --- min mode is still rejected -------------------------------------------
make_gate '    @("git", "--version"),
    @("git", "status", "--short")'
run -Min
verify; rc=$?
assert "a min-mode receipt is rejected"         "$rc" "1"

# --- the two interpreters agree on the fingerprint ------------------------
# The receipt has to mean the same thing on both platforms, or a Windows developer
# and a Linux developer get different verdicts on the same commit.
# Write both gates BEFORE either runs. gate.sh is an untracked file and therefore
# part of the fingerprint, so creating it between the two runs would change the
# tree and make this compare two different trees rather than two interpreters.
sed -e 's/^yarn build$/true/' -e 's/yarn check/true/' -e 's/yarn test/true/' \
    "$ROOT/tooling/gate/gate-node.sh" > gate.sh
run
ps_tree=$(sed -n 's/.*"tree"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' .gate-result.json)
sh ./gate.sh >/dev/null 2>&1
sh_tree=$(sed -n 's/.*"tree"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' .gate-result.json)
assert "sh and ps1 fingerprint the same tree"   "$ps_tree" "$sh_tree"

echo
echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ] || exit 1
