#!/usr/bin/env bash
# generate-report.sh — Cluster 9 run-all-reviews pass/fail PR report (E28-S73, AC5)
#
# Runs the Cluster 9 bats suite, captures TAP output, and generates a
# markdown report suitable for posting as a PR comment.
#
# Usage: generate-report.sh <output-path> <repo-root>
#
# Exit codes:
#   0 — report generated (regardless of test pass/fail)
#   1 — usage error

set -euo pipefail
LC_ALL=C
export LC_ALL

OUTPUT="${1:?Usage: generate-report.sh <output-path> <repo-root>}"
REPO_ROOT="${2:?Usage: generate-report.sh <output-path> <repo-root>}"

BATS_FILE="$REPO_ROOT/plugins/gaia/tests/cluster-9/run-all-reviews.bats"

if [ ! -f "$BATS_FILE" ]; then
  echo "Error: bats file not found: $BATS_FILE" >&2
  exit 1
fi

# Run bats and capture TAP output
TAP_OUTPUT=""
bats_rc=0
TAP_OUTPUT=$(bats "$BATS_FILE" 2>&1) || bats_rc=$?

# Count results
total=$(echo "$TAP_OUTPUT" | grep -cE '^(ok|not ok) ' || true)
passed=$(echo "$TAP_OUTPUT" | grep -cE '^ok ' || true)
failed=$(echo "$TAP_OUTPUT" | grep -cE '^not ok ' || true)

verdict="PASS"
[ "$failed" -gt 0 ] && verdict="FAIL"

# Extract failing test details
fail_details=""
if [ "$failed" -gt 0 ]; then
  fail_details=$(echo "$TAP_OUTPUT" | awk '
    /^not ok / { printing = 1; print; next }
    /^ok / { printing = 0 }
    /^#/ && printing { print }
  ')
fi

# Generate report
{
  echo "# Cluster 9 Run-All-Reviews Integration Report"
  echo ""
  echo "**Date:** $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "**Verdict:** $verdict ($passed passed, $failed failed, $total total)"
  echo ""
  echo "## Test Results"
  echo ""
  echo '```tap'
  echo "$TAP_OUTPUT"
  echo '```'
  echo ""

  if [ -n "$fail_details" ]; then
    echo "## Failing Tests"
    echo ""
    echo '```'
    echo "$fail_details"
    echo '```'
    echo ""
    echo "### Review Gate Diff"
    echo ""
    echo "Check the bats output above for unified diffs between expected and actual Review Gate tables."
    echo ""
  fi

  echo "## Vocabulary Invariant"
  echo ""
  echo "Canonical values: \`PASSED\` | \`FAILED\` | \`UNVERIFIED\`"
  echo ""
  if echo "$TAP_OUTPUT" | grep -q 'NON-CANONICAL'; then
    echo "**BREACH DETECTED** — see failing test output above for details."
  else
    echo "No vocabulary breaches detected."
  fi
} > "$OUTPUT"

echo "Report written to $OUTPUT"
exit 0
