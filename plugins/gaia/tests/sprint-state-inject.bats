#!/usr/bin/env bats
# sprint-state-inject.bats — coverage for the `inject` subcommand (E38-S10).
#
# Stories: TC-SPQG-12 (golden inject + idempotency + validate round-trip)
#          TC-SPQG-13 (sprint-id mismatch + missing-fields + wrapper-sync)
#
# Each test runs against BOTH the canonical script AND the wrapper copy at
# plugins/gaia/skills/gaia-dev-story/scripts/sprint-state.sh per ADR-055
# §10.29.3 (wrapper-sync invariant, NFR-SPQG-2). The two-pass loop is the
# AC5 enforcement mechanism: any drift between canonical and wrapper output
# fails the test mechanically.

load 'test_helper.bash'

setup() {
  common_setup
  CANONICAL="$SCRIPTS_DIR/sprint-state.sh"
  WRAPPER="$(cd "$BATS_TEST_DIRNAME/../skills/gaia-dev-story/scripts" && pwd)/sprint-state.sh"
  # Wrapper script lives next to itself but its sibling foundation scripts
  # (lifecycle-event.sh, review-gate.sh) live in plugins/gaia/scripts/.
  # Point SPRINT_STATE_SCRIPT_DIR at the canonical scripts dir so the
  # wrapper resolves siblings correctly. Mirrors how the wrapper is invoked
  # in production (PROJECT_PATH + CLAUDE_PLUGIN_ROOT routing).
  export SPRINT_STATE_SCRIPT_DIR="$SCRIPTS_DIR"
  export CANONICAL WRAPPER
  export MEMORY_PATH="$TEST_TMP/_memory"
  export PROJECT_PATH="$TEST_TMP"
  ART="$TEST_TMP/docs/implementation-artifacts"
  mkdir -p "$ART" "$MEMORY_PATH"
}
teardown() { common_teardown; }

# Seed a backlog story file in $ART. Frontmatter carries the four fields the
# inject subcommand validates: sprint_id, status, points, risk.
seed_backlog_story() {
  local key="$1" sprint_id="$2" status="${3:-ready-for-dev}" points="${4:-3}" risk="${5:-medium}"
  cat > "$ART/${key}-fake.md" <<EOF
---
template: 'story'
key: "$key"
title: "Fake $key"
status: $status
sprint_id: "$sprint_id"
points: $points
risk: "$risk"
---

# Story: Fake $key

> **Status:** $status
EOF
}

# Seed a sprint-status.yaml with header fields and a single existing story.
seed_yaml_with_header() {
  local sprint_id="$1" velocity_capacity="${2:-10}" total_points="${3:-3}" cap_util="${4:-30%}"
  cat > "$ART/sprint-status.yaml" <<EOF
sprint_id: "$sprint_id"
velocity_capacity: $velocity_capacity
total_points: $total_points
capacity_utilization: "$cap_util"
stories:
  - key: "EXISTING-S1"
    title: "Existing story"
    status: "in-progress"
    points: 3
    risk_level: "low"
    assignee: null
    blocked_by: null
    updated: "2026-05-01"
EOF
}

# AC1 — golden inject for both canonical and wrapper.
@test "sprint-state.sh inject: AC1 golden inject (canonical)" {
  seed_backlog_story INJ1 sprint-test ready-for-dev 5 medium
  seed_yaml_with_header sprint-test 10 3 "30%"
  run "$CANONICAL" inject --story INJ1
  [ "$status" -eq 0 ] || { echo "exit=$status output=$output"; false; }
  grep -q '^  - key: "INJ1"' "$ART/sprint-status.yaml" \
    || { echo "yaml missing INJ1 entry"; cat "$ART/sprint-status.yaml"; false; }
  # New entry's status mirrors story-file frontmatter.
  awk '/^  - key: "INJ1"/{f=1; next} f && /^  - key:/{f=0} f && /status:/{print; exit}' \
    "$ART/sprint-status.yaml" | grep -q 'ready-for-dev' \
    || { echo "status mismatch"; cat "$ART/sprint-status.yaml"; false; }
  # total_points bumped: 3 + 5 = 8.
  grep -q '^total_points: 8$' "$ART/sprint-status.yaml" \
    || { echo "total_points not bumped"; grep total_points "$ART/sprint-status.yaml"; false; }
  # capacity_utilization recomputed: 8/10 = 80%.
  grep -q '^capacity_utilization: "80%"$' "$ART/sprint-status.yaml" \
    || { echo "capacity_utilization not recomputed"; grep capacity_utilization "$ART/sprint-status.yaml"; false; }
  # Lifecycle event emitted.
  [ -s "$MEMORY_PATH/lifecycle-events.jsonl" ] || { echo "no lifecycle event"; false; }
  grep -q 'story_injected' "$MEMORY_PATH/lifecycle-events.jsonl" \
    || { echo "wrong event type"; cat "$MEMORY_PATH/lifecycle-events.jsonl"; false; }
}

@test "sprint-state.sh inject: AC1 golden inject (wrapper)" {
  seed_backlog_story INJ1W sprint-test ready-for-dev 5 medium
  seed_yaml_with_header sprint-test 10 3 "30%"
  run "$WRAPPER" inject --story INJ1W
  [ "$status" -eq 0 ] || { echo "exit=$status output=$output"; false; }
  grep -q '^  - key: "INJ1W"' "$ART/sprint-status.yaml" || { cat "$ART/sprint-status.yaml"; false; }
  grep -q '^total_points: 8$' "$ART/sprint-status.yaml"
  grep -q '^capacity_utilization: "80%"$' "$ART/sprint-status.yaml"
}

# AC2 — idempotency. Second inject is a no-op (yaml byte-identical).
@test "sprint-state.sh inject: AC2 idempotency (canonical)" {
  seed_backlog_story INJ2 sprint-test ready-for-dev 4 low
  seed_yaml_with_header sprint-test 10 3 "30%"
  run "$CANONICAL" inject --story INJ2
  [ "$status" -eq 0 ] || { echo "first inject failed: $output"; false; }
  local hash_after_first
  hash_after_first=$(shasum -a 256 "$ART/sprint-status.yaml" | awk '{print $1}')
  run "$CANONICAL" inject --story INJ2
  [ "$status" -eq 0 ] || { echo "second inject should be no-op: $output"; false; }
  [[ "$output" == *"already injected"* ]] || { echo "missing 'already injected' message: $output"; false; }
  local hash_after_second
  hash_after_second=$(shasum -a 256 "$ART/sprint-status.yaml" | awk '{print $1}')
  [ "$hash_after_first" = "$hash_after_second" ] || { echo "yaml mutated on second inject"; false; }
}

@test "sprint-state.sh inject: AC2 idempotency (wrapper)" {
  seed_backlog_story INJ2W sprint-test ready-for-dev 4 low
  seed_yaml_with_header sprint-test 10 3 "30%"
  run "$WRAPPER" inject --story INJ2W
  [ "$status" -eq 0 ]
  local h1; h1=$(shasum -a 256 "$ART/sprint-status.yaml" | awk '{print $1}')
  run "$WRAPPER" inject --story INJ2W
  [ "$status" -eq 0 ]
  [[ "$output" == *"already injected"* ]]
  local h2; h2=$(shasum -a 256 "$ART/sprint-status.yaml" | awk '{print $1}')
  [ "$h1" = "$h2" ]
}

# AC3 — sprint-id mismatch. Refuses with both ids; yaml unchanged.
@test "sprint-state.sh inject: AC3 sprint-id mismatch refused (canonical)" {
  seed_backlog_story INJ3 sprint-other ready-for-dev 5 medium
  seed_yaml_with_header sprint-test 10 3 "30%"
  local before; before=$(shasum -a 256 "$ART/sprint-status.yaml" | awk '{print $1}')
  run bash -c "'$CANONICAL' inject --story INJ3 2>&1"
  [ "$status" -ne 0 ] || { echo "expected non-zero, got 0: $output"; false; }
  [[ "$output" != *"unknown subcommand"* ]] || { echo "canonical rejected inject: $output"; false; }
  [[ "$output" == *"sprint-test"* ]] || { echo "missing yaml sprint id: $output"; false; }
  [[ "$output" == *"sprint-other"* ]] || { echo "missing story sprint id: $output"; false; }
  local after; after=$(shasum -a 256 "$ART/sprint-status.yaml" | awk '{print $1}')
  [ "$before" = "$after" ] || { echo "yaml mutated on mismatch"; false; }
}

@test "sprint-state.sh inject: AC3 sprint-id mismatch refused (wrapper)" {
  seed_backlog_story INJ3W sprint-other ready-for-dev 5 medium
  seed_yaml_with_header sprint-test 10 3 "30%"
  local before; before=$(shasum -a 256 "$ART/sprint-status.yaml" | awk '{print $1}')
  run bash -c "'$WRAPPER' inject --story INJ3W 2>&1"
  [ "$status" -ne 0 ]
  [[ "$output" != *"unknown subcommand"* ]] || { echo "wrapper rejected inject: $output"; false; }
  [[ "$output" == *"sprint-test"* ]]
  [[ "$output" == *"sprint-other"* ]]
  local after; after=$(shasum -a 256 "$ART/sprint-status.yaml" | awk '{print $1}')
  [ "$before" = "$after" ]
}

# AC4 — missing required frontmatter fields. Names every missing field.
@test "sprint-state.sh inject: AC4 missing fields named (canonical)" {
  # Story file lacks sprint_id and risk.
  cat > "$ART/INJ4-fake.md" <<EOF
---
template: 'story'
key: "INJ4"
title: "Missing fields"
status: ready-for-dev
points: 5
---

# Story: Missing fields

> **Status:** ready-for-dev
EOF
  seed_yaml_with_header sprint-test 10 3 "30%"
  local before; before=$(shasum -a 256 "$ART/sprint-status.yaml" | awk '{print $1}')
  run bash -c "'$CANONICAL' inject --story INJ4 2>&1"
  [ "$status" -ne 0 ] || { echo "expected non-zero: $output"; false; }
  [[ "$output" != *"unknown subcommand"* ]] || { echo "canonical rejected inject: $output"; false; }
  [[ "$output" == *"sprint_id"* ]] || { echo "missing sprint_id in error: $output"; false; }
  [[ "$output" == *"risk"* ]] || { echo "missing risk in error: $output"; false; }
  local after; after=$(shasum -a 256 "$ART/sprint-status.yaml" | awk '{print $1}')
  [ "$before" = "$after" ]
}

@test "sprint-state.sh inject: AC4 missing fields named (wrapper)" {
  cat > "$ART/INJ4W-fake.md" <<EOF
---
template: 'story'
key: "INJ4W"
title: "Missing fields"
status: ready-for-dev
points: 5
---

# Story: Missing fields

> **Status:** ready-for-dev
EOF
  seed_yaml_with_header sprint-test 10 3 "30%"
  local before; before=$(shasum -a 256 "$ART/sprint-status.yaml" | awk '{print $1}')
  run bash -c "'$WRAPPER' inject --story INJ4W 2>&1"
  [ "$status" -ne 0 ]
  [[ "$output" != *"unknown subcommand"* ]] || { echo "wrapper rejected inject: $output"; false; }
  [[ "$output" == *"sprint_id"* ]]
  [[ "$output" == *"risk"* ]]
  local after; after=$(shasum -a 256 "$ART/sprint-status.yaml" | awk '{print $1}')
  [ "$before" = "$after" ]
}

# AC9 — inject-then-validate round-trip green.
@test "sprint-state.sh inject: AC9 validate round-trip (canonical)" {
  seed_backlog_story INJ9 sprint-test ready-for-dev 2 low
  seed_yaml_with_header sprint-test 10 3 "30%"
  run "$CANONICAL" inject --story INJ9
  [ "$status" -eq 0 ] || { echo "inject failed: $output"; false; }
  run "$CANONICAL" validate --story INJ9
  [ "$status" -eq 0 ] || { echo "validate failed after inject: $output"; false; }
}

@test "sprint-state.sh inject: AC9 validate round-trip (wrapper)" {
  seed_backlog_story INJ9W sprint-test ready-for-dev 2 low
  seed_yaml_with_header sprint-test 10 3 "30%"
  run "$WRAPPER" inject --story INJ9W
  [ "$status" -eq 0 ]
  run "$WRAPPER" validate --story INJ9W
  [ "$status" -eq 0 ]
}

# AC8 — usage text advertises inject.
@test "sprint-state.sh inject: usage advertises inject" {
  run "$CANONICAL" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"inject"* ]] || { echo "help missing inject: $output"; false; }
}
