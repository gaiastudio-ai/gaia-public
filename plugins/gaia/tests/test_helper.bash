#!/usr/bin/env bash
# test_helper.bash — shared setup/teardown for the E28-S17 bats suite.
#
# Provides per-test temp dirs under $BATS_TMPDIR (never touches the working
# tree), a run_script helper that always invokes the real script from
# plugins/gaia/scripts/, and deterministic LC_ALL/TZ pinning.

set -euo pipefail
LC_ALL=C
export LC_ALL
export TZ=UTC

# Resolve SCRIPTS_DIR once. BATS_TEST_DIRNAME is set by bats to the dir of
# the .bats file — tests/ — so scripts live one level up under scripts/.
SCRIPTS_DIR="$(cd "$BATS_TEST_DIRNAME/../scripts" && pwd)"
export SCRIPTS_DIR

# common_setup — called from every test's setup(). Creates a per-test temp
# dir, namespaces it by $BATS_TEST_NAME, and exports TEST_TMP.
common_setup() {
  local slug
  slug="$(printf '%s' "${BATS_TEST_NAME:-unknown}" | tr -c '[:alnum:]' '_')"
  TEST_TMP="${BATS_TEST_TMPDIR:-${BATS_TMPDIR:-/tmp}}/gaia-${slug}-$$"
  mkdir -p "$TEST_TMP"
  export TEST_TMP
}

# common_teardown — called from every test's teardown(). Removes the temp
# dir. Safe to call twice; failures are swallowed so teardown never masks
# the real test failure.
common_teardown() {
  if [ -n "${TEST_TMP:-}" ] && [ -d "$TEST_TMP" ]; then
    rm -rf "$TEST_TMP" 2>/dev/null || true
  fi
}

# run_script <basename> [args...] — run a foundation script by basename
# (e.g. "resolve-config.sh") with $status, $output, $stderr populated by
# bats' `run` built-in.
run_script() {
  local name="$1"; shift
  run "$SCRIPTS_DIR/$name" "$@"
}
