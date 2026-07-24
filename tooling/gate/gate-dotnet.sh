#!/usr/bin/env sh
# Gate script — .NET backend. Copy to the backend repo root as `gate.sh`,
# fill in SOLUTION and TEST_PROJECT. This file is the ONLY definition of the gate;
# docs and CLAUDE.md must point here, never restate the commands.
#
# Usage: ./gate.sh           full gate (build + test)
#        ./gate.sh --min     minimum gate (build only)
#        ./gate.sh --verify  no build — check the existing receipt is fresh and green
#
# On completion the gate writes `.gate-result.json` — the receipt recording WHICH
# working tree passed. `--verify` re-fingerprints the tree and reports whether the
# receipt still applies, so a stale pass cannot satisfy the Definition of Done.
# Add `.gate-result.json` to .gitignore: it is local evidence, never committed.

SOLUTION="{{SOLUTION}}"         # e.g. wms-v3.sln
TEST_PROJECT="{{TEST_PROJECT}}" # e.g. WMS.API.Tests — the authoritative test project

# --- receipt machinery (identical in every gate script — do not let it diverge) ---
# Fingerprints the working tree, including uncommitted and untracked files, using a
# throwaway index so the developer's real index is untouched. The gate legitimately
# runs on a dirty tree (phase work is gated before it is committed), so freshness is
# content-based, not HEAD-based. The receipt itself is excluded so it never alters
# the fingerprint it is stored in.
#
# Process artifacts are excluded. These are written AROUND the gate, not built by
# it: phase/roadmap status and review output are produced by /phase-review and
# /phase-done, which necessarily run after the gate. Fingerprinting them would make
# the receipt go stale the moment a phase is written up. They are never build
# inputs. Everything else stays in -- including spec.md, plan.md and
# specs/*/contracts/, which CAN affect a build and must invalidate the receipt.
RECEIPT_EXCLUDES=".gate-result.json specs/*/tasks.md specs/*/ai-code-review.md specs/*/human-pr-review.md docs/roadmap"

fingerprint() {
    idx="${TMPDIR:-/tmp}/gate-index-$$"
    GIT_INDEX_FILE="$idx" git read-tree HEAD 2>/dev/null
    GIT_INDEX_FILE="$idx" git add -A 2>/dev/null
    set -f  # keep the patterns literal so git's pathspec matcher does the matching
    # -r is required: docs/roadmap is a directory, and without it git aborts the
    # whole call, silently applying NO exclusions at all.
    GIT_INDEX_FILE="$idx" git rm --cached -q -r --ignore-unmatch $RECEIPT_EXCLUDES 2>/dev/null
    set +f
    tree=$(GIT_INDEX_FILE="$idx" git write-tree 2>/dev/null)
    rm -f "$idx"
    [ -n "$tree" ] || tree="unknown"
    echo "$tree"
}

json_str() { sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" .gate-result.json; }
json_num() { sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p" .gate-result.json; }

if [ "$1" = "--verify" ]; then
    [ -f .gate-result.json ] || { echo "RECEIPT: missing — run ./gate.sh"; exit 1; }
    current=$(fingerprint)
    [ "$(json_str tree)" = "$current" ] || {
        echo "RECEIPT: stale — the working tree changed after the gate ran; re-run ./gate.sh"; exit 1; }
    [ "$(json_str mode)" = "full" ] || {
        echo "RECEIPT: min — only the minimum gate ran; a full gate is required"; exit 1; }
    [ "$(json_num exit)" = "0" ] || {
        echo "RECEIPT: failed — recorded EXIT: $(json_num exit)"; exit 1; }
    echo "RECEIPT: valid — full gate, EXIT: 0, tree $current"
    echo "  not fingerprinted (process artifacts, never build inputs): $RECEIPT_EXCLUDES"
    exit 0
fi

dotnet build "$SOLUTION"
code=$?
if [ "$1" != "--min" ] && [ $code -eq 0 ]; then
    dotnet test "$TEST_PROJECT"
    code=$?
fi

if [ "$1" = "--min" ]; then mode="min"; else mode="full"; fi
tree=$(fingerprint)
cat > .gate-result.json <<EOF
{
  "exit": $code,
  "mode": "$mode",
  "tree": "$tree",
  "head": "$(git rev-parse HEAD 2>/dev/null || echo unknown)",
  "utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

git check-ignore -q .gate-result.json 2>/dev/null || \
    echo "WARNING: add .gate-result.json to .gitignore — the receipt is local evidence, never committed."

echo "EXIT: $code"
exit $code
