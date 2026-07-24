#!/usr/bin/env sh
# Regression test for the gate receipt contract.
#
#     sh tests/receipt-contract.sh
#
# Builds a throwaway git repo, installs the real gate script from tooling/gate/
# with its build steps stubbed out, and asserts every receipt state. Exit 0 = all
# assertions passed.
#
# The two assertions that matter most, because they define the boundary of what a
# receipt promises:
#   - editing specs/<f>/spec.md MUST invalidate it (specs can change what builds)
#   - editing specs/<f>/tasks.md MUST NOT (phase status is written after the gate)
# Widen RECEIPT_EXCLUDES and the spec.md case fails. That is the point.

set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORK="${TMPDIR:-/tmp}/sdlc-receipt-test-$$"
pass=0
fail=0

cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

# --- fixture ---------------------------------------------------------------
mkdir -p "$WORK" || exit 1
cd "$WORK" || exit 1
git init -q .
git config user.email test@example.com
git config user.name "receipt test"

mkdir -p src specs/feature/001-example docs/roadmap
echo "console.log('app')"        > src/app.js
echo "# Spec"                    > specs/feature/001-example/spec.md
echo "# Plan"                    > specs/feature/001-example/plan.md
echo "# Tasks"                   > specs/feature/001-example/tasks.md
echo "# Roadmap"                 > docs/roadmap/README.md
echo ".gate-result.json"         > .gitignore
git add -A
git commit -qm "baseline"

# Install the real gate script, stubbing only the build/test commands.
sed -e 's/^yarn build$/eval "${GATE_BUILD:-true}"/' \
    -e 's/^    yarn check \&\& yarn test.*$/    eval "${GATE_TEST:-true}"/' \
    "$ROOT/tooling/gate/gate-node.sh" > gate.sh
chmod +x gate.sh
if ! grep -q 'GATE_BUILD' gate.sh; then
    echo "SETUP FAILED: could not stub gate-node.sh -- did its build steps change?"
    exit 1
fi

# --- helpers ---------------------------------------------------------------
gate()  { ./gate.sh "$@" >/dev/null 2>&1; }

check() {  # check <label> <expected_rc>
    label="$1"; want="$2"
    out=$(./gate.sh --verify 2>&1); rc=$?
    if [ "$rc" = "$want" ]; then
        pass=$((pass + 1))
        printf '  PASS  %s\n' "$label"
    else
        fail=$((fail + 1))
        printf '  FAIL  %s (rc=%s want=%s) :: %s\n' "$label" "$rc" "$want" "$(echo "$out" | head -1)"
    fi
}

echo "receipt contract"

# --- lifecycle -------------------------------------------------------------
check "no receipt yet is rejected"                 1
gate
check "fresh full green receipt is accepted"       0

# --- code changes MUST invalidate ------------------------------------------
echo "// changed" >> src/app.js
check "edited tracked source invalidates"          1
gate
echo "console.log('new')" > src/added.js
check "new untracked source invalidates"           1
gate
echo "// more" >> src/added.js
check "edited untracked source invalidates"        1
gate

# --- process artifacts MUST NOT invalidate ---------------------------------
# These are written by /phase-review and /phase-done, which necessarily run after
# the user's gate. Before this exclusion existed, /phase-done invalidated the very
# receipt it had just verified.
echo "- [x] phase 1" >> specs/feature/001-example/tasks.md
check "tasks.md status does not invalidate"        0
echo "PASS" > specs/feature/001-example/ai-code-review.md
check "ai-code-review.md does not invalidate"      0
echo "APPROVED" > specs/feature/001-example/human-pr-review.md
check "human-pr-review.md does not invalidate"     0
echo "| 001 | done |" >> docs/roadmap/README.md
check "roadmap status does not invalidate"         0

# --- the exclusion must stay NARROW ----------------------------------------
echo "## New requirement" >> specs/feature/001-example/spec.md
check "spec.md DOES invalidate"                    1
gate
echo "## New approach" >> specs/feature/001-example/plan.md
check "plan.md DOES invalidate"                    1
gate
mkdir -p specs/feature/001-example/contracts
echo "openapi: 3.0.0" > specs/feature/001-example/contracts/api.yml
check "contracts DO invalidate"                    1

# --- mode and exit code ----------------------------------------------------
gate --min
check "min-mode receipt is rejected"               1
GATE_BUILD=false ./gate.sh >/dev/null 2>&1
check "failed gate is rejected"                    1
gate
rm -f .gate-result.json
check "deleted receipt is rejected"                1

# --- the gate must not disturb the developer's index -----------------------
gate
git add src/app.js
before=$(git diff --cached --name-only)
./gate.sh --verify >/dev/null 2>&1
after=$(git diff --cached --name-only)
if [ "$before" = "$after" ]; then
    pass=$((pass + 1)); echo "  PASS  verify leaves the git index untouched"
else
    fail=$((fail + 1)); echo "  FAIL  verify mutated the git index"
fi

echo
echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ] || exit 1
