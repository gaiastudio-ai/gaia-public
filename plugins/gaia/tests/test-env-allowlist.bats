#!/usr/bin/env bats
# test-env-allowlist.bats -- unit tests for plugins/gaia/scripts/test-env-allowlist.sh
#
# E35-S2: Approval gate wiring + YOLO auto-approve allowlist derivation
# NFR-052: Every new public function MUST have a direct unit test.
#
# The test-env-allowlist.sh helper parses test-environment.yaml to derive
# the tier-directory allowlist consumed by:
#   - E35-S2 YOLO auto-approve path (AC5, AC-EC6)
#   - E35-S3 Phase 2 target-path enforcement (FR-TAF-3)
#
# Derivation rule (per approved plan W1 resolution):
#   Primary:  tiers.stack_hints.bats_test_dirs values (split on whitespace)
#   Fallback: extract path args from runners.shell.tier_{N}_* commands
#   Fixture:  if top-level tier_directories: is present, use it directly
#             (E35-S3 ATDD synthetic fixture tolerance)
#
# Public functions exercised:
#   derive_allowlist (main entrypoint), parse_bats_test_dirs,
#   parse_runner_paths, check_fixture_override

load 'test_helper.bash'

setup() {
  common_setup
  SCRIPT="$SCRIPTS_DIR/test-env-allowlist.sh"
  export PROJECT_PATH="$TEST_TMP"
}

teardown() { common_teardown; }

# ---------------------------------------------------------------------------
# Helper: write a test-environment.yaml with the real production structure
# ---------------------------------------------------------------------------
write_real_test_env() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
  cat > "$path" <<'YAML'
schema_version: 1
primary_stack: shell
ci_workflow: plugin-ci.yml

runners:
  shell:
    tier_1_unit: bats plugins/gaia/tests
    tier_2_integration: bats tests/e2e tests/cluster-6-parity tests/cluster-7-parity
    tier_3_e2e: bats plugins/gaia/tests tests/e2e tests/cluster-6-parity

tiers:
  gate_mapping:
    qa_tests: [tier_1_unit, tier_2_integration]
    test_automate: [tier_1_unit]
  stack_hints:
    bats_test_dirs:
      unit: plugins/gaia/tests
      integration: tests/e2e
      parity: tests/cluster-6-parity tests/cluster-7-parity
    shell_lint: shellcheck
YAML
}

# ---------------------------------------------------------------------------
# Helper: write a synthetic ATDD fixture with top-level tier_directories:
# ---------------------------------------------------------------------------
write_fixture_test_env() {
  local path="$1"
  local dir="$2"
  mkdir -p "$(dirname "$path")"
  cat > "$path" <<YAML
---
tier_directories:
  - "${dir}"
YAML
}

# ---------------------------------------------------------------------------
# Primary path: derives dirs from tiers.stack_hints.bats_test_dirs
# ---------------------------------------------------------------------------

@test "primary: derives allowlist from tiers.stack_hints.bats_test_dirs" {
  local env_path="$TEST_TMP/test-environment.yaml"
  write_real_test_env "$env_path"

  run "$SCRIPT" --test-env "$env_path"
  [ "$status" -eq 0 ]

  # Must include all dirs from bats_test_dirs values
  [[ "$output" == *"plugins/gaia/tests"* ]]
  [[ "$output" == *"tests/e2e"* ]]
  [[ "$output" == *"tests/cluster-6-parity"* ]]
  [[ "$output" == *"tests/cluster-7-parity"* ]]
}

# ---------------------------------------------------------------------------
# Fallback: extracts dirs from runners.shell.tier_* commands
# ---------------------------------------------------------------------------

@test "fallback: extracts dirs from runner commands when stack_hints absent" {
  local env_path="$TEST_TMP/test-environment.yaml"
  mkdir -p "$(dirname "$env_path")"
  cat > "$env_path" <<'YAML'
schema_version: 1
primary_stack: shell
runners:
  shell:
    tier_1_unit: bats plugins/gaia/tests
    tier_2_integration: bats tests/e2e tests/cluster-6-parity
tiers:
  gate_mapping:
    qa_tests: [tier_1_unit]
YAML

  run "$SCRIPT" --test-env "$env_path"
  [ "$status" -eq 0 ]

  [[ "$output" == *"plugins/gaia/tests"* ]]
  [[ "$output" == *"tests/e2e"* ]]
  [[ "$output" == *"tests/cluster-6-parity"* ]]
}

# ---------------------------------------------------------------------------
# Fixture tolerance: top-level tier_directories: overrides all other sources
# ---------------------------------------------------------------------------

@test "fixture: top-level tier_directories used directly (ATDD synthetic)" {
  local env_path="$TEST_TMP/test-environment.yaml"
  local fixture_dir="$TEST_TMP/my-fixture-tests"
  mkdir -p "$fixture_dir"
  write_fixture_test_env "$env_path" "$fixture_dir"

  run "$SCRIPT" --test-env "$env_path"
  [ "$status" -eq 0 ]

  [[ "$output" == *"$fixture_dir"* ]]
}

# ---------------------------------------------------------------------------
# Missing test-environment.yaml: exits non-zero
# ---------------------------------------------------------------------------

@test "missing file: exits non-zero when test-environment.yaml not found" {
  run "$SCRIPT" --test-env "$TEST_TMP/does-not-exist.yaml"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]] || [[ "$output" == *"missing"* ]] || [[ "$output" == *"No such file"* ]]
}

# ---------------------------------------------------------------------------
# Empty file: exits non-zero or returns empty allowlist
# ---------------------------------------------------------------------------

@test "empty file: exits non-zero for empty test-environment.yaml" {
  local env_path="$TEST_TMP/test-environment.yaml"
  : > "$env_path"

  run "$SCRIPT" --test-env "$env_path"
  [ "$status" -ne 0 ] || [ -z "$output" ]
}

# ---------------------------------------------------------------------------
# Output format: one directory per line, no duplicates
# ---------------------------------------------------------------------------

@test "output format: one directory per line with no duplicates" {
  local env_path="$TEST_TMP/test-environment.yaml"
  write_real_test_env "$env_path"

  run "$SCRIPT" --test-env "$env_path"
  [ "$status" -eq 0 ]

  # Count lines vs unique lines
  local total_lines unique_lines
  total_lines="$(printf '%s\n' "$output" | wc -l | tr -d ' ')"
  unique_lines="$(printf '%s\n' "$output" | sort -u | wc -l | tr -d ' ')"
  [ "$total_lines" -eq "$unique_lines" ]
  [ "$total_lines" -gt 0 ]
}

# ---------------------------------------------------------------------------
# Whitespace splitting: multi-dir values correctly split
# ---------------------------------------------------------------------------

@test "whitespace splitting: space-separated bats_test_dirs values split correctly" {
  local env_path="$TEST_TMP/test-environment.yaml"
  mkdir -p "$(dirname "$env_path")"
  cat > "$env_path" <<'YAML'
schema_version: 1
tiers:
  stack_hints:
    bats_test_dirs:
      parity: tests/a tests/b tests/c
YAML

  run "$SCRIPT" --test-env "$env_path"
  [ "$status" -eq 0 ]

  [[ "$output" == *"tests/a"* ]]
  [[ "$output" == *"tests/b"* ]]
  [[ "$output" == *"tests/c"* ]]
}

# ---------------------------------------------------------------------------
# No args: prints usage
# ---------------------------------------------------------------------------

@test "no args: prints usage and exits non-zero" {
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"usage"* ]] || [[ "$output" == *"--test-env"* ]]
}
