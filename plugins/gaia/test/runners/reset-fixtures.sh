#!/usr/bin/env bash
# reset-fixtures.sh — resets the 3 Cluster 19 review-gate fixture stories back
# to status: review with UNVERIFIED Review Gate rows. Invoked by bats test setup
# and by idempotency re-run scenarios (AC-EC7).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FIXTURES_ROOT="$(cd "$SCRIPT_DIR/../fixtures/cluster-19/stories" && pwd)"

if sed --version >/dev/null 2>&1; then
  SED_INPLACE=(sed -i)
else
  SED_INPLACE=(sed -i '')
fi

reset_one() {
  local story_file="$1"
  "${SED_INPLACE[@]}" -E 's/^status: (done|in-progress)$/status: review/' "$story_file"
  "${SED_INPLACE[@]}" -E 's/^\> \*\*Status:\*\* (done|in-progress)$/> **Status:** review/' "$story_file"
  for label in "Code Review" "QA Tests" "Security Review" "Test Automation" "Test Review" "Performance Review"; do
    "${SED_INPLACE[@]}" -E "s#^\\| ${label} \\| (PASSED|FAILED|FAILED.*) \\| [^|]* \\|\$#| ${label} | UNVERIFIED | — |#" "$story_file"
  done
}

for dir in clean code-review-defect security-finding; do
  story_file="$(ls "$FIXTURES_ROOT/$dir"/*.md 2>/dev/null | head -1)"
  [ -n "$story_file" ] && reset_one "$story_file"
done

echo "reset complete"
