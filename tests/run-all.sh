#!/usr/bin/env sh
# The framework's own gate. Run everything:
#
#     sh tests/run-all.sh
#
# CI runs this exact script (.github/workflows/selftest.yml), so there is no
# separate CI command chain to drift out of sync -- the same rule the framework
# imposes on consuming projects in process/team/team-workflow.md section 3.
#
# Prints EXIT: <code> and exits with it, matching the gate script convention.

set -u
cd "$(dirname "$0")/.." || exit 1

code=0

echo "================================================================"
echo " framework self-tests"
echo "================================================================"
echo

echo "--- static consistency ------------------------------------------"
sh tests/framework-checks.sh || code=1
echo

echo "--- CI exceptions check -----------------------------------------"
sh tests/exceptions-check.sh || code=1
echo

echo "--- gate receipt contract ---------------------------------------"
sh tests/receipt-contract.sh || code=1
echo

echo "--- powershell gate behaviour -----------------------------------"
sh tests/gate-powershell.sh || code=1
echo

echo "================================================================"
if [ "$code" -eq 0 ]; then
    echo " all self-tests passed"
else
    echo " SELF-TESTS FAILED"
fi
echo "================================================================"
echo "EXIT: $code"
exit $code
