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

SOLUTION="{{SOLUTION}}"         # e.g. app.sln
TEST_PROJECT="{{TEST_PROJECT}}" # e.g. App.API.Tests — the authoritative test project

# --- receipt machinery (identical in every gate script — do not let it diverge) ---
# Fingerprints the working tree, including uncommitted and untracked files, using a
# throwaway index so the developer's real index is untouched. The gate legitimately
# runs on a dirty tree (phase work is gated before it is committed), so freshness is
# content-based, not HEAD-based. The receipt itself is excluded so it never alters
# the fingerprint it is stored in.
#
# Process artifacts are excluded -- but only the ones carrying STATUS, never the
# ones carrying requirements. /phase-review and /phase-done necessarily run after
# the gate, so fingerprinting their output would make a receipt go stale the moment
# a phase is written up. Status therefore lives in files of its own:
#
#   specs/<feature>/status.md   phase progress
#   docs/roadmap/status.md      delivery board
#
# NOT tasks.md, and NOT the roadmap itself. Those define what the work IS -- the
# task list is the requirement for the phase, the roadmap owns scope and
# sequencing. If they were excluded, requirements could be rewritten after the
# gate to match whatever was built, and the receipt would still report valid.
#
# Everything else stays in, including spec.md, plan.md, tasks.md, the roadmap
# definitions, and specs/*/contracts/.
RECEIPT_EXCLUDES=".gate-result.json specs/*/status.md specs/*/ai-code-review.md specs/*/human-pr-review.md docs/roadmap/status.md"

fingerprint() {
    idx="${TMPDIR:-/tmp}/gate-index-$$"
    GIT_INDEX_FILE="$idx" git read-tree HEAD 2>/dev/null
    GIT_INDEX_FILE="$idx" git add -A 2>/dev/null
    set -f  # keep the patterns literal so git's pathspec matcher does the matching
    # -r is kept even though every pattern now names a file: if any pattern ever
    # resolves to a directory, git aborts the WHOLE call without it, silently
    # applying no exclusions at all.
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
    # Fail closed on an unfingerprintable tree. Every git call in fingerprint() is
    # silenced, so if they all fail the answer is the literal string "unknown" --
    # and "unknown" = "unknown" makes the equality below succeed forever, no matter
    # what changes on disk. The realistic trigger is not "not a repo": it is
    # `fatal: detected dubious ownership`, the standard Docker/WSL/CI-container
    # failure. An unverifiable tree is a failure, never a pass.
    { [ "$current" != "unknown" ] && [ "$(json_str tree)" != "unknown" ]; } || {
        echo "RECEIPT: unverifiable — the working tree could not be fingerprinted."
        echo "  Run 'git status': 'detected dubious ownership' is the usual cause in Docker, WSL and CI containers."
        exit 1; }
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
# A receipt naming a tree that could not be read is not evidence -- it is a
# permanently-valid pass. Refuse to write one, and fail the gate.
if [ "$tree" = "unknown" ]; then
    echo "GATE: the working tree could not be fingerprinted — no receipt written."
    echo "  Run 'git status': 'detected dubious ownership' is the usual cause in Docker, WSL and CI containers."
    echo "EXIT: 1"
    exit 1
fi
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
