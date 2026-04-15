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
  : > "$TEST_ARTIFACTS/test-plan.md"
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
  : > "$TEST_ARTIFACTS/traceability-matrix.md"
  run "$SCRIPT" traceability_exists
  [ "$status" -eq 0 ]
}

@test "validate-gate.sh: atdd_exists requires --story" {
  run "$SCRIPT" atdd_exists
  [ "$status" -eq 1 ]
  [[ "$output" == *"--story"* ]]
}

@test "validate-gate.sh: atdd_exists resolves story key" {
  : > "$TEST_ARTIFACTS/atdd-E1-S1.md"
  run "$SCRIPT" atdd_exists --story E1-S1
  [ "$status" -eq 0 ]
}

@test "validate-gate.sh: file_exists multi-file happy path" {
  : > "$TEST_TMP/a.md"; : > "$TEST_TMP/b.md"
  run "$SCRIPT" file_exists --file "$TEST_TMP/a.md" --file "$TEST_TMP/b.md"
  [ "$status" -eq 0 ]
}

@test "validate-gate.sh: file_exists first-missing fails with clear error" {
  : > "$TEST_TMP/a.md"
  run "$SCRIPT" file_exists --file "$TEST_TMP/a.md" --file "$TEST_TMP/missing.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing.md"* ]]
}

@test "validate-gate.sh: --multi happy path reports aggregate pass" {
  : > "$TEST_ARTIFACTS/test-plan.md"
  : > "$TEST_ARTIFACTS/traceability-matrix.md"
  : > "$TEST_ARTIFACTS/ci-setup.md"
  run "$SCRIPT" --multi "test_plan_exists,traceability_exists,ci_setup_exists"
  [ "$status" -eq 0 ]
  [[ "$output" == *"3 gates passed"* ]]
}

@test "validate-gate.sh: --multi fails fast on first missing gate" {
  : > "$TEST_ARTIFACTS/test-plan.md"
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
  run "$SCRIPT" readiness_report_exists
  [ "$status" -eq 1 ]
  local abs
  abs="$(cd "$TEST_ARTIFACTS" && pwd)"
  [[ "$output" == *"$abs/readiness-report.md"* ]]
}
