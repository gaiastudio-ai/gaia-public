#!/usr/bin/env bats
# e28-s126-verify-cluster-gates.bats — bats-core tests for the verify-cluster-gates.sh
# pre-start verifier (E28-S126 Task 1 / AC1 / AC-EC4).
#
# RED phase: script does not yet exist — all tests fail until Step 7 (Green) implements it.

PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SCRIPTS_DIR="$PLUGIN_DIR/scripts"
FIXTURES_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/fixtures/e28-s126" && pwd)"
SCRIPT="$SCRIPTS_DIR/verify-cluster-gates.sh"

@test "verify-cluster-gates.sh exists and is executable" {
  [ -x "$SCRIPT" ]
}

@test "happy path — all 12 cluster gates done + 6x PASSED (exit 0)" {
  run "$SCRIPT" --project-root "$FIXTURES_DIR/gates-all-passed"
  [ "$status" -eq 0 ]
}

@test "happy-path output names every checked gate" {
  run "$SCRIPT" --project-root "$FIXTURES_DIR/gates-all-passed"
  for k in E28-S76 E28-S81 E28-S95 E28-S99 E28-S118 E28-S133 E28-S134 E28-S135 E28-S136 E28-S137 E28-S138 E28-S139; do
    [[ "$output" == *"$k"* ]]
  done
}

@test "one gate failed (E28-S136 QA Tests FAILED) — exit 1" {
  run "$SCRIPT" --project-root "$FIXTURES_DIR/gates-one-failed"
  [ "$status" -eq 1 ]
}

@test "failure output names the blocking gate" {
  run "$SCRIPT" --project-root "$FIXTURES_DIR/gates-one-failed"
  [[ "$output" == *"E28-S136"* ]]
}

@test "missing story file — exit 2 (parse error)" {
  local tmp
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/docs/implementation-artifacts"
  # Only one gate story present — the rest are missing
  cp "$FIXTURES_DIR/gates-all-passed/docs/implementation-artifacts/E28-S76-fake.md" "$tmp/docs/implementation-artifacts/"
  run "$SCRIPT" --project-root "$tmp"
  [ "$status" -eq 2 ]
  rm -rf "$tmp"
}

@test "missing --project-root arg — prints usage and exits non-zero" {
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"project-root"* || "$output" == *"usage"* || "$output" == *"Usage"* ]]
}
