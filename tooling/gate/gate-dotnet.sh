#!/usr/bin/env sh
# Gate script — .NET backend. Copy to the backend repo root as `gate.sh`,
# fill in SOLUTION and TEST_PROJECT. This file is the ONLY definition of the gate;
# docs and CLAUDE.md must point here, never restate the commands.
#
# Usage: ./gate.sh           full gate (build + test)
#        ./gate.sh --min     minimum gate (build only)

SOLUTION="{{SOLUTION}}"         # e.g. wms-v3.sln
TEST_PROJECT="{{TEST_PROJECT}}" # e.g. WMS.API.Tests — the authoritative test project

dotnet build "$SOLUTION"
code=$?
if [ "$1" != "--min" ] && [ $code -eq 0 ]; then
    dotnet test "$TEST_PROJECT"
    code=$?
fi

echo "EXIT: $code"
exit $code
