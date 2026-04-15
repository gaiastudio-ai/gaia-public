#!/usr/bin/env bats
# review-gate.bats — unit tests for plugins/gaia/scripts/review-gate.sh
# Public functions covered: is_canonical_gate, is_canonical_verdict,
# join_by, locate_story_file, parse_gate_rows, load_canonical_rows,
# cmd_status, cmd_check, cmd_update, main. (join_by is the internal
# string-join helper exercised end-to-end by the status/check subcommand
# tests that emit a comma-separated list of gate verdicts.)

load 'test_helper.bash'

setup() {
  common_setup
  SCRIPT="$SCRIPTS_DIR/review-gate.sh"
  export PROJECT_PATH="$TEST_TMP"
  ART="$TEST_TMP/docs/implementation-artifacts/stories"
  mkdir -p "$ART"
}
teardown() { common_teardown; }

seed_story() {
  local key="$1" verdict="${2:-UNVERIFIED}"
  cat > "$ART/${key}-fake.md" <<EOF
---
key: "$key"
---

# Story: Fake

## Review Gate

| Review | Status | Report |
|--------|--------|--------|
| Code Review | $verdict | — |
| QA Tests | $verdict | — |
| Security Review | $verdict | — |
| Test Automation | $verdict | — |
| Test Review | $verdict | — |
| Performance Review | $verdict | — |
EOF
}

@test "review-gate.sh: --help exits 0 and lists subcommands" {
  run "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"check"* ]]
  [[ "$output" == *"update"* ]]
  [[ "$output" == *"status"* ]]
}

@test "review-gate.sh: check — all PASSED returns 0" {
  seed_story R1 PASSED
  run "$SCRIPT" check --story R1
  [ "$status" -eq 0 ]
}

@test "review-gate.sh: check — any UNVERIFIED returns non-zero" {
  seed_story R2 UNVERIFIED
  run "$SCRIPT" check --story R2
  [ "$status" -ne 0 ]
}

@test "review-gate.sh: check — any FAILED returns non-zero" {
  seed_story R3 PASSED
  sed -i.bak 's/Code Review | PASSED/Code Review | FAILED/' "$ART/R3-fake.md"
  rm -f "$ART/R3-fake.md.bak"
  run "$SCRIPT" check --story R3
  [ "$status" -ne 0 ]
}

@test "review-gate.sh: update rewrites a single row" {
  seed_story R4 UNVERIFIED
  run "$SCRIPT" update --story R4 --gate "Code Review" --verdict PASSED
  [ "$status" -eq 0 ]
  grep -q 'Code Review | PASSED' "$ART/R4-fake.md"
  grep -q 'QA Tests | UNVERIFIED' "$ART/R4-fake.md"
}

@test "review-gate.sh: update rejects unknown gate name" {
  seed_story R5 UNVERIFIED
  run "$SCRIPT" update --story R5 --gate "Bogus Gate" --verdict PASSED
  [ "$status" -ne 0 ]
}

@test "review-gate.sh: update rejects non-canonical verdict" {
  seed_story R6 UNVERIFIED
  run "$SCRIPT" update --story R6 --gate "Code Review" --verdict approve
  [ "$status" -ne 0 ]
}

@test "review-gate.sh: status emits JSON summary when jq available" {
  command -v jq >/dev/null 2>&1 || skip "jq required"
  seed_story R7 PASSED
  run "$SCRIPT" status --story R7
  [ "$status" -eq 0 ]
  printf '%s' "$output" | jq -e . >/dev/null
}

@test "review-gate.sh: zero-match story key → non-zero" {
  run "$SCRIPT" check --story NOPE-S999
  [ "$status" -ne 0 ]
}

@test "review-gate.sh: update idempotent — second identical update exits 0" {
  seed_story R8 UNVERIFIED
  "$SCRIPT" update --story R8 --gate "QA Tests" --verdict PASSED
  run "$SCRIPT" update --story R8 --gate "QA Tests" --verdict PASSED
  [ "$status" -eq 0 ]
  [ "$(grep -c 'QA Tests | PASSED' "$ART/R8-fake.md")" = "1" ]
}
