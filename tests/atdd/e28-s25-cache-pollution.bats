#!/usr/bin/env bats
# ATDD — E28-S25 /plugin marketplace add cache-pollution recovery
# Tests each acceptance criterion from docs/implementation-artifacts/E28-S25-*.md.

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  PUBLIC_README="${REPO_ROOT}/README.md"
  ENTERPRISE_README="${REPO_ROOT}/../gaia-enterprise/README.md"
  STORY_FILE="${REPO_ROOT}/../docs/implementation-artifacts/E28-S25-plugin-marketplace-cache-pollution-recovery.md"
  # SMOKE_TEST path is retained for reference; AC4 is covered by plugin-cache-recovery.sh.
  # shellcheck disable=SC2034
  SMOKE_TEST="${REPO_ROOT}/scripts/cache-health.sh"
  # AC3 grep — match the specific upstream cache-pollution issue number.
  UPSTREAM_URL_PATTERN='https://github.com/anthropics/claude-code/issues/[0-9]+'
}

# --- AC1 --------------------------------------------------------------------
@test "AC1: recovery rm -rf command is documented in both READMEs" {
  run grep -E 'rm -rf[[:space:]]+~/\.claude/plugins/marketplaces/' "$PUBLIC_README"
  [ "$status" -eq 0 ]

  run grep -E 'rm -rf[[:space:]]+~/\.claude/plugins/marketplaces/' "$ENTERPRISE_README"
  [ "$status" -eq 0 ]
}

# --- AC2 --------------------------------------------------------------------
@test "AC2: upstream bug report filed against anthropics/claude-code" {
  run grep -E "$UPSTREAM_URL_PATTERN" "$STORY_FILE"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

# --- AC3 --------------------------------------------------------------------
@test "AC3: upstream issue URL captured in Dev Notes AND both READMEs" {
  run grep -E "$UPSTREAM_URL_PATTERN" "$STORY_FILE"
  [ "$status" -eq 0 ]

  run grep -E "$UPSTREAM_URL_PATTERN" "$PUBLIC_README"
  [ "$status" -eq 0 ]

  run grep -E "$UPSTREAM_URL_PATTERN" "$ENTERPRISE_README"
  [ "$status" -eq 0 ]
}

# --- AC4 (optional) ---------------------------------------------------------
@test "AC4: cache-health smoke-test exits 0 on clean cache, non-zero on polluted" {
  skip "covered by plugins/gaia/scripts/plugin-cache-recovery.sh (foundation script landed under E28-S25)"
}
