#!/usr/bin/env bats
# sprint-state.bats — state-machine tests for sprint-state.sh
# Public functions covered: is_canonical_state, validate_transition,
# resolve_paths, locate_story_file, read_story_status,
# rewrite_story_status, rewrite_sprint_status_yaml,
# read_sprint_status_yaml_status, check_review_gate_all_passed,
# emit_lifecycle_event, cmd_get, cmd_validate, do_transition_locked,
# cmd_transition, main.

load 'test_helper.bash'

setup() {
  common_setup
  SCRIPT="$SCRIPTS_DIR/sprint-state.sh"
  export MEMORY_PATH="$TEST_TMP/_memory"
  export PROJECT_PATH="$TEST_TMP"
  ART="$TEST_TMP/docs/implementation-artifacts"
  JSONL="$MEMORY_PATH/lifecycle-events.jsonl"
  mkdir -p "$ART"
}
teardown() { common_teardown; }

seed_story() {
  local key="$1" status="$2" verdict="${3:-PASSED}"
  cat > "$ART/${key}-fake.md" <<EOF
---
key: "$key"
title: "Fake"
status: $status
---

# Story: Fake

> **Status:** $status

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

seed_yaml() {
  cat > "$ART/sprint-status.yaml" <<EOF
sprint_id: "sprint-test"
stories:
  - key: "$1"
    title: "Fake"
    status: "$2"
EOF
}

@test "sprint-state.sh: --help lists the three subcommands" {
  run "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"transition"* ]]
  [[ "$output" == *"get"* ]]
  [[ "$output" == *"validate"* ]]
}

# --- Legal transitions (AC6 — exercise every canonical edge) -----------------

@test "sprint-state.sh: legal transition backlog → validating" {
  seed_story L1 backlog; seed_yaml L1 backlog
  run "$SCRIPT" transition --story L1 --to validating
  [ "$status" -eq 0 ]
  grep -q '^status: validating' "$ART/L1-fake.md"
}

@test "sprint-state.sh: legal transition validating → ready-for-dev" {
  seed_story L2 validating; seed_yaml L2 validating
  run "$SCRIPT" transition --story L2 --to ready-for-dev
  [ "$status" -eq 0 ]
}

@test "sprint-state.sh: legal transition ready-for-dev → in-progress" {
  seed_story L3 ready-for-dev; seed_yaml L3 ready-for-dev
  run "$SCRIPT" transition --story L3 --to in-progress
  [ "$status" -eq 0 ]
}

@test "sprint-state.sh: legal transition in-progress → blocked" {
  seed_story L4 in-progress; seed_yaml L4 in-progress
  run "$SCRIPT" transition --story L4 --to blocked
  [ "$status" -eq 0 ]
}

@test "sprint-state.sh: legal transition blocked → in-progress" {
  seed_story L5 blocked; seed_yaml L5 blocked
  run "$SCRIPT" transition --story L5 --to in-progress
  [ "$status" -eq 0 ]
}

@test "sprint-state.sh: legal transition in-progress → review" {
  seed_story L6 in-progress; seed_yaml L6 in-progress
  run "$SCRIPT" transition --story L6 --to review
  [ "$status" -eq 0 ]
}

@test "sprint-state.sh: legal transition review → done (all PASSED)" {
  seed_story L7 review PASSED; seed_yaml L7 review
  run "$SCRIPT" transition --story L7 --to done
  [ "$status" -eq 0 ]
  grep -q '^status: done' "$ART/L7-fake.md"
}

@test "sprint-state.sh: legal transition review → in-progress" {
  seed_story L8 review UNVERIFIED; seed_yaml L8 review
  run "$SCRIPT" transition --story L8 --to in-progress
  [ "$status" -eq 0 ]
}

# --- Illegal transitions (AC6 — sample of rejected edges) -------------------

@test "sprint-state.sh: illegal backlog → done rejected, file untouched" {
  seed_story I1 backlog; seed_yaml I1 backlog
  run "$SCRIPT" transition --story I1 --to done
  [ "$status" -ne 0 ]
  grep -q '^status: backlog' "$ART/I1-fake.md"
}

@test "sprint-state.sh: illegal done → in-progress rejected" {
  seed_story I2 done; seed_yaml I2 done
  run "$SCRIPT" transition --story I2 --to in-progress
  [ "$status" -ne 0 ]
}

@test "sprint-state.sh: illegal review → backlog rejected" {
  seed_story I3 review; seed_yaml I3 review
  run "$SCRIPT" transition --story I3 --to backlog
  [ "$status" -ne 0 ]
}

# --- review gate guard -------------------------------------------------------

@test "sprint-state.sh: review → done blocked when gate not all PASSED" {
  seed_story G1 review UNVERIFIED; seed_yaml G1 review
  run "$SCRIPT" transition --story G1 --to done
  [ "$status" -ne 0 ]
  [[ "$output" == *"Review Gate"* ]] || [[ "$output" == *"review"* ]]
}

# --- get / validate ----------------------------------------------------------

@test "sprint-state.sh: get returns current status" {
  seed_story V1 in-progress; seed_yaml V1 in-progress
  run "$SCRIPT" get --story V1
  [ "$status" -eq 0 ]
  [ "$output" = "in-progress" ]
}

@test "sprint-state.sh: validate detects drift between story and sprint-status.yaml" {
  seed_story V2 in-progress; seed_yaml V2 in-progress
  run "$SCRIPT" validate --story V2
  [ "$status" -eq 0 ]
  # induce drift
  sed -i.bak 's/status: "in-progress"/status: "done"/' "$ART/sprint-status.yaml"
  rm -f "$ART/sprint-status.yaml.bak"
  run "$SCRIPT" validate --story V2
  [ "$status" -ne 0 ]
}

@test "sprint-state.sh: get with zero-match key fails with clear message" {
  run "$SCRIPT" get --story NOPE-S999
  [ "$status" -ne 0 ]
  [[ "$output" == *"no story file found"* ]]
}
