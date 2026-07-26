#!/usr/bin/env sh
# Regression test for the gate receipt contract.
#
#     sh tests/receipt-contract.sh
#
# Builds a throwaway git repo, installs the real gate script from tooling/gate/
# with its build steps stubbed out, and asserts every receipt state. Exit 0 = all
# assertions passed.
#
# The assertions that matter most define the boundary of what a receipt promises:
#   - specs/feature/NNN-<name>/status.md MUST NOT invalidate it (status is written after the gate)
#   - specs/feature/NNN-<name>/tasks.md MUST invalidate it (it defines the phase's requirements,
#     and requirements rewritten after the gate must not still read as verified)
#   - docs/roadmap/status.md MUST NOT; the roadmap definitions MUST
# Widen RECEIPT_EXCLUDES back to whole files and the tasks.md/roadmap cases fail.
# That is the point: the exclusion covers status, never requirements.

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

# Install the real gate script, stubbing the build/test COMMANDS -- never whole
# lines. This fixture used to replace the entire `yarn check && yarn test` line,
# which meant the shell operators joining those commands were supplied by the test
# rather than read from the gate. A regression written into gate-node.sh -- `|| true`
# appended, or `;` in place of `&&`, the textbook status-swallowing bug -- was
# substituted away before it could be observed, and the suite reported 18/18 PASS.
# Replacing only the command words leaves the operators in place, so the shape of
# the real gate line is under test.
sed -e 's/^yarn build$/eval "${GATE_BUILD:-true}"/' \
    -e 's/yarn check/eval "${GATE_CHECK:-true}"/' \
    -e 's/yarn test/eval "${GATE_TEST:-true}"/' \
    "$ROOT/tooling/gate/gate-node.sh" > gate.sh
chmod +x gate.sh
for v in GATE_BUILD GATE_CHECK GATE_TEST; do
    if ! grep -q "$v" gate.sh; then
        echo "SETUP FAILED: could not stub $v in gate-node.sh -- did its build steps change?"
        exit 1
    fi
done

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

# --- STATUS artifacts MUST NOT invalidate ----------------------------------
# These are written by /phase-review and /phase-done, which necessarily run after
# the user's gate. Before this exclusion existed, /phase-done invalidated the very
# receipt it had just verified.
echo "- [x] phase 1 complete" >> specs/feature/001-example/status.md
check "feature status.md does not invalidate"      0
echo "PASS" > specs/feature/001-example/ai-code-review.md
check "ai-code-review.md does not invalidate"      0
echo "APPROVED" > specs/feature/001-example/human-pr-review.md
check "human-pr-review.md does not invalidate"     0
echo "| 001 | done |" >> docs/roadmap/status.md
check "roadmap status.md does not invalidate"      0

# --- REQUIREMENTS MUST invalidate, even when they are process files --------
# The exclusion covers status, never requirements. tasks.md and the roadmap were
# excluded wholesale until v2.2.0: a task's implementation requirements, or the
# roadmap's scope and sequencing, could be rewritten after the gate to match
# whatever was actually built, and the receipt still reported valid.
echo "## New requirement" >> specs/feature/001-example/spec.md
check "spec.md DOES invalidate"                    1
gate
echo "## New approach" >> specs/feature/001-example/plan.md
check "plan.md DOES invalidate"                    1
gate
echo "- T7: also rewrite the parser" >> specs/feature/001-example/tasks.md
check "tasks.md definitions DO invalidate"         1
gate
echo "| 002 | descoped |" >> docs/roadmap/README.md
check "roadmap definitions DO invalidate"          1
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

# --- the compound step keeps its && semantics ------------------------------
# Every step of the gate must be able to fail the gate, and a failing step must
# stop the ones after it. `|| true`, `; ` instead of `&&`, or a `tee` swallowing
# the status all break this, and all of them look harmless in a diff. The test
# step touches a marker file, so "did it run" is observable rather than inferred.
rm -f ran-test
GATE_CHECK=false GATE_TEST='touch ran-test' ./gate.sh >/dev/null 2>&1
check "failing lint step is not swallowed"         1
if [ -f ran-test ]; then
    fail=$((fail + 1)); echo "  FAIL  the test step ran after lint failed -- && semantics lost"
else
    pass=$((pass + 1)); echo "  PASS  the test step is skipped when lint fails"
fi

# The mirror image: with lint green the test step must actually run. Without this,
# a gate that silently skipped its tests would satisfy every assertion above.
rm -f ran-test
GATE_CHECK=true GATE_TEST='touch ran-test' ./gate.sh >/dev/null 2>&1
if [ -f ran-test ]; then
    pass=$((pass + 1)); echo "  PASS  the test step runs when lint passes"
else
    fail=$((fail + 1)); echo "  FAIL  the test step never ran -- the gate is not running its own steps"
fi
rm -f ran-test
gate

# A failing TEST step must fail the gate too -- the last command in the chain is
# the one whose status the gate reports, so it is the easiest to lose.
GATE_TEST=false ./gate.sh >/dev/null 2>&1
check "failing test step is not swallowed"         1
gate

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
