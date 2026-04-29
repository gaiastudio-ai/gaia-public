#!/usr/bin/env bash
# test_helper.bash — Cluster 1 test helper (E61-S1)
#
# Mirrors the cluster-9 helper. Wraps the shared test helper but overrides
# SCRIPTS_DIR to point to the correct scripts/ directory (two levels up
# from cluster-1/). The shared helper resolves SCRIPTS_DIR via
# $BATS_TEST_DIRNAME/../scripts, which works for tests at the root tests/
# level but not for subdirectories.

set -euo pipefail
LC_ALL=C
export LC_ALL
export TZ=UTC

# Resolve SCRIPTS_DIR before loading the shared helper so the cd in the
# shared helper doesn't fail.
SCRIPTS_DIR="$(cd "${BATS_TEST_DIRNAME}/../../scripts" && pwd)"
export SCRIPTS_DIR

# common_setup — same as shared helper
common_setup() {
  local slug
  slug="$(printf '%s' "${BATS_TEST_NAME:-unknown}" | tr -c '[:alnum:]' '_')"
  TEST_TMP="${BATS_TEST_TMPDIR:-${BATS_TMPDIR:-/tmp}}/gaia-${slug}-$$"
  mkdir -p "$TEST_TMP"
  export TEST_TMP
}

# common_teardown — same as shared helper
common_teardown() {
  if [ -n "${TEST_TMP:-}" ] && [ -d "$TEST_TMP" ]; then
    rm -rf "$TEST_TMP" 2>/dev/null || true
  fi
}
