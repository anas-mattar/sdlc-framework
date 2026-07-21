#!/usr/bin/env sh
# Gate script — Node/Next.js frontend. Copy to the frontend repo root as `gate.sh`.
# Adjust the steps to the project's package.json scripts. This file is the ONLY
# definition of the gate; docs and CLAUDE.md must point here, never restate commands.
#
# If the project pins yarn via `packageManager`, run `corepack enable` once first.
#
# Usage: ./gate.sh           full gate
#        ./gate.sh --min     minimum gate (build only)

yarn build
code=$?
if [ "$1" != "--min" ] && [ $code -eq 0 ]; then
    yarn check && yarn test   # replace with the project's scripts
    code=$?
fi

echo "EXIT: $code"
exit $code
