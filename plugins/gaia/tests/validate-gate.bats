#!/usr/bin/env bats
# validate-gate.bats — unit tests for plugins/gaia/scripts/validate-gate.sh
# Public functions covered: abs_path, gate_path, list_gates, evaluate_gate,
# main.

load 'test_helper.bash'

setup() {
  common_setup
  SCRIPT="$SCRIPTS_DIR/validate-gate.sh"
  export TEST_ARTIFACTS="$TEST_TMP/test-artifacts"
  mkdir -p "$TEST_ARTIFACTS"
}
teardown() { common_teardown; }

@test "validate-gate.sh: --help prints usage on stdout and exits 0" {
  run "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *[Uu]sage* ]]
}

@test "validate-gate.sh: --list enumerates all gate types" {
  run "$SCRIPT" --list
  [ "$status" -eq 0 ]
  [[ "$output" == *"test_plan_exists"* ]]
  [[ "$output" == *"traceability_exists"* ]]
  [[ "$output" == *"ci_setup_exists"* ]]
  [[ "$output" == *"atdd_exists"* ]]
  [[ "$output" == *"readiness_report_exists"* ]]
  [[ "$output" == *"file_exists"* ]]
}

@test "validate-gate.sh: test_plan_exists happy path returns 0" {
  printf 'x' > "$TEST_ARTIFACTS/test-plan.md"
  run "$SCRIPT" test_plan_exists
  [ "$status" -eq 0 ]
}

@test "validate-gate.sh: missing test-plan.md fails with stable error format" {
  run "$SCRIPT" test_plan_exists
  [ "$status" -eq 1 ]
  [[ "$output" == *"validate-gate: test_plan_exists failed"* ]]
  [[ "$output" == *"expected:"* ]]
}

@test "validate-gate.sh: traceability_exists happy path" {
  printf 'x' > "$TEST_ARTIFACTS/traceability-matrix.md"
  run "$SCRIPT" traceability_exists
  [ "$status" -eq 0 ]
}

@test "validate-gate.sh: atdd_exists requires --story" {
  run "$SCRIPT" atdd_exists
  [ "$status" -eq 1 ]
  [[ "$output" == *"--story"* ]]
}

@test "validate-gate.sh: atdd_exists resolves story key" {
  printf 'x' > "$TEST_ARTIFACTS/atdd-E1-S1.md"
  run "$SCRIPT" atdd_exists --story E1-S1
  [ "$status" -eq 0 ]
}

@test "validate-gate.sh: file_exists multi-file happy path" {
  printf 'x' > "$TEST_TMP/a.md"; printf 'x' > "$TEST_TMP/b.md"
  run "$SCRIPT" file_exists --file "$TEST_TMP/a.md" --file "$TEST_TMP/b.md"
  [ "$status" -eq 0 ]
}

@test "validate-gate.sh: file_exists first-missing fails with clear error" {
  printf 'x' > "$TEST_TMP/a.md"
  run "$SCRIPT" file_exists --file "$TEST_TMP/a.md" --file "$TEST_TMP/missing.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing.md"* ]]
}

@test "validate-gate.sh: --multi happy path reports aggregate pass" {
  printf 'x' > "$TEST_ARTIFACTS/test-plan.md"
  printf 'x' > "$TEST_ARTIFACTS/traceability-matrix.md"
  printf 'x' > "$TEST_ARTIFACTS/ci-setup.md"
  run "$SCRIPT" --multi "test_plan_exists,traceability_exists,ci_setup_exists"
  [ "$status" -eq 0 ]
  [[ "$output" == *"3 gates passed"* ]]
}

@test "validate-gate.sh: --multi fails fast on first missing gate" {
  printf 'x' > "$TEST_ARTIFACTS/test-plan.md"
  run "$SCRIPT" --multi "test_plan_exists,traceability_exists"
  [ "$status" -eq 1 ]
  [[ "$output" == *"traceability_exists"* ]]
}

@test "validate-gate.sh: unknown gate type fails with non-zero" {
  run "$SCRIPT" bogus_gate
  [ "$status" -ne 0 ]
  [[ "$output" == *"bogus_gate"* ]]
}

@test "validate-gate.sh: missing file error names absolute path" {
  # E28-S152: readiness_report_exists now resolves against PLANNING_ARTIFACTS
  export PLANNING_ARTIFACTS="$TEST_TMP/planning-artifacts"
  mkdir -p "$PLANNING_ARTIFACTS"
  run "$SCRIPT" readiness_report_exists
  [ "$status" -eq 1 ]
  local abs
  abs="$(cd "$PLANNING_ARTIFACTS" && pwd)"
  [[ "$output" == *"$abs/readiness-report.md"* ]]
}

# --- E28-S152: readiness_report_exists resolves against PLANNING_ARTIFACTS ---

@test "validate-gate.sh: readiness_report_exists happy path uses PLANNING_ARTIFACTS" {
  export PLANNING_ARTIFACTS="$TEST_TMP/planning-artifacts"
  mkdir -p "$PLANNING_ARTIFACTS"
  printf '# Readiness\n' > "$PLANNING_ARTIFACTS/readiness-report.md"
  run "$SCRIPT" readiness_report_exists
  [ "$status" -eq 0 ]
}

@test "validate-gate.sh: readiness_report_exists fails when PLANNING_ARTIFACTS file missing" {
  export PLANNING_ARTIFACTS="$TEST_TMP/planning-artifacts"
  mkdir -p "$PLANNING_ARTIFACTS"
  # No readiness-report.md created under PLANNING_ARTIFACTS
  # Also create one under TEST_ARTIFACTS to prove the old path is no longer used
  printf '# Stale\n' > "$TEST_ARTIFACTS/readiness-report.md"
  run "$SCRIPT" readiness_report_exists
  [ "$status" -eq 1 ]
  [[ "$output" == *"readiness_report_exists failed"* ]]
}

# --- E28-S97: epics_and_stories_exists gate type ---

@test "validate-gate.sh: epics_and_stories_exists happy path returns 0" {
  export PLANNING_ARTIFACTS="$TEST_TMP/planning-artifacts"
  mkdir -p "$PLANNING_ARTIFACTS"
  printf '# Epics\n' > "$PLANNING_ARTIFACTS/epics-and-stories.md"
  run "$SCRIPT" epics_and_stories_exists
  [ "$status" -eq 0 ]
}

@test "validate-gate.sh: epics_and_stories_exists fails when file missing" {
  export PLANNING_ARTIFACTS="$TEST_TMP/planning-artifacts"
  mkdir -p "$PLANNING_ARTIFACTS"
  run "$SCRIPT" epics_and_stories_exists
  [ "$status" -eq 1 ]
  [[ "$output" == *"epics_and_stories_exists failed"* ]]
  [[ "$output" == *"expected:"* ]]
}

@test "validate-gate.sh: --list includes epics_and_stories_exists" {
  run "$SCRIPT" --list
  [ "$status" -eq 0 ]
  [[ "$output" == *"epics_and_stories_exists"* ]]
}

# --- E28-S198: prd_exists gate type ---

@test "validate-gate.sh: prd_exists happy path returns 0" {
  export PLANNING_ARTIFACTS="$TEST_TMP/planning-artifacts"
  mkdir -p "$PLANNING_ARTIFACTS"
  printf '# PRD\n' > "$PLANNING_ARTIFACTS/prd.md"
  run "$SCRIPT" prd_exists
  [ "$status" -eq 0 ]
}

@test "validate-gate.sh: prd_exists fails when file missing with stable error format" {
  export PLANNING_ARTIFACTS="$TEST_TMP/planning-artifacts"
  mkdir -p "$PLANNING_ARTIFACTS"
  run "$SCRIPT" prd_exists
  [ "$status" -eq 1 ]
  [[ "$output" == *"validate-gate: prd_exists failed"* ]]
  [[ "$output" == *"expected:"* ]]
  local abs
  abs="$(cd "$PLANNING_ARTIFACTS" && pwd)"
  [[ "$output" == *"$abs/prd.md"* ]]
}

@test "validate-gate.sh: prd_exists fails when file is zero bytes" {
  export PLANNING_ARTIFACTS="$TEST_TMP/planning-artifacts"
  mkdir -p "$PLANNING_ARTIFACTS"
  : > "$PLANNING_ARTIFACTS/prd.md"
  run "$SCRIPT" prd_exists
  [ "$status" -eq 1 ]
  [[ "$output" == *"prd_exists failed"* ]]
}

@test "validate-gate.sh: prd_exists honors PLANNING_ARTIFACTS env var override" {
  export PLANNING_ARTIFACTS="$TEST_TMP/custom-planning"
  mkdir -p "$PLANNING_ARTIFACTS"
  printf '# PRD\n' > "$PLANNING_ARTIFACTS/prd.md"
  run "$SCRIPT" prd_exists
  [ "$status" -eq 0 ]
  [[ "$output" != *"failed"* ]]
}

@test "validate-gate.sh: --list includes prd_exists" {
  run "$SCRIPT" --list
  [ "$status" -eq 0 ]
  [[ "$output" == *"prd_exists"* ]]
}

@test "validate-gate.sh: --help includes prd_exists in enumeration" {
  run "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"prd_exists"* ]]
}
