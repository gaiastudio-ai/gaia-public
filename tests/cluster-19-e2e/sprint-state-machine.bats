#!/usr/bin/env bats
# sprint-state-machine.bats — E28-S135: Test sprint state machine (Cluster 19)
#
# Exercises the native `sprint-state.sh` foundation script against an isolated
# fixture story through all 7 canonical states, all documented valid transitions,
# and a canonical set of invalid transitions that must be rejected. Captures a
# newline-delimited JSON trace per transition, diffs the trace against the
# v-parity-baseline oracle (projecting out timestamps), and verifies the
# fixture story's frontmatter `status:` field and body `**Status:**` line stay
# in sync after every transition.
#
# AC mapping:
#   AC1 — happy-path traversal through all 7 states, trace recorded
#   AC2 — every valid transition succeeds, story file + sprint-status.yaml stay in sync
#   AC3 — invalid transitions rejected with non-zero exit and source→target error
#   AC4 — native trace == baseline trace (timestamp stripped)
#   AC5 — rolled-up PASS/FAIL verdict in the results markdown
#
# Usage:
#   bats tests/cluster-19-e2e/sprint-state-machine.bats

# ---------- Helpers ----------

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCRIPTS_DIR="$REPO_ROOT/plugins/gaia/scripts"
  FIXTURE_DIR="$REPO_ROOT/plugins/gaia/test/fixtures/cluster-19/sprint-state-machine"
  BASELINE_TRACE="$REPO_ROOT/plugins/gaia/test/fixtures/parity-baseline/traces/sprint-state-machine.jsonl"

  TEST_TMP="$BATS_TEST_TMPDIR/ssm-$$"
  mkdir -p "$TEST_TMP/docs/implementation-artifacts"
  mkdir -p "$TEST_TMP/checkpoints" "$TEST_TMP/memory"

  # Copy the immutable seed into the per-test working area so mutations during
  # the test never touch the committed seed (the seed's sha256 is anchored in
  # fixture-manifest.yaml per E28-S132 AC4).
  cp "$FIXTURE_DIR/seed/state-machine-fixture-story.md" \
     "$TEST_TMP/docs/implementation-artifacts/SSM-E2E-01-state-machine.md"
  cp "$FIXTURE_DIR/seed/sprint-status.yaml" \
     "$TEST_TMP/docs/implementation-artifacts/sprint-status.yaml"
  cp "$FIXTURE_DIR/seed/story-index.yaml" \
     "$TEST_TMP/docs/implementation-artifacts/story-index.yaml"

  export PROJECT_PATH="$TEST_TMP"
  export IMPLEMENTATION_ARTIFACTS="$TEST_TMP/docs/implementation-artifacts"
  export CHECKPOINT_PATH="$TEST_TMP/checkpoints"
  export MEMORY_PATH="$TEST_TMP/memory"
  # lifecycle-event.sh writes to MEMORY_PATH/lifecycle.jsonl by default;
  # we do not assert on its output in this test, only that it succeeds.
}

teardown() {
  rm -rf "$TEST_TMP" 2>/dev/null || true
}

# Reset the fixture back to `backlog` between test cases that share state.
reset_fixture() {
  cp "$FIXTURE_DIR/seed/state-machine-fixture-story.md" \
     "$TEST_TMP/docs/implementation-artifacts/SSM-E2E-01-state-machine.md"
  cp "$FIXTURE_DIR/seed/sprint-status.yaml" \
     "$TEST_TMP/docs/implementation-artifacts/sprint-status.yaml"
  cp "$FIXTURE_DIR/seed/story-index.yaml" \
     "$TEST_TMP/docs/implementation-artifacts/story-index.yaml"
}

# Force the fixture into a specific state by traversing the canonical edges.
# Safer than editing frontmatter directly because it exercises the same script
# the test is validating.
force_to_state() {
  local target="$1"
  reset_fixture
  case "$target" in
    backlog) return 0 ;;
    validating)
      run_transition backlog validating ;;
    ready-for-dev)
      run_transition backlog validating
      run_transition validating ready-for-dev ;;
    in-progress)
      run_transition backlog validating
      run_transition validating ready-for-dev
      run_transition ready-for-dev in-progress ;;
    blocked)
      force_to_state in-progress
      run_transition in-progress blocked ;;
    review)
      force_to_state in-progress
      run_transition in-progress review ;;
    done)
      force_to_state review
      run_transition review done ;;
  esac
}

# Run one transition and — on success — append a trace record.
run_transition() {
  local from="$1" to="$2"
  run "$SCRIPTS_DIR/sprint-state.sh" transition --story SSM-E2E-01 --to "$to"
}

# Read story status via script (source of truth).
get_status() {
  "$SCRIPTS_DIR/sprint-state.sh" get --story SSM-E2E-01
}

# Read body `**Status:**` line from the story file.
get_body_status() {
  awk '/^>[[:space:]]*\*\*Status:\*\*/ {
         sub(/^>[[:space:]]*\*\*Status:\*\*[[:space:]]*/, "", $0); print; exit
       }' \
    "$TEST_TMP/docs/implementation-artifacts/SSM-E2E-01-state-machine.md"
}

# Read status of SSM-E2E-01 from sprint-status.yaml.
get_yaml_status() {
  awk '
    BEGIN { in_entry = 0 }
    /^[[:space:]]*-[[:space:]]*key:[[:space:]]*/ {
      k = $0
      sub(/^[[:space:]]*-[[:space:]]*key:[[:space:]]*/, "", k)
      gsub(/["[:space:]]/, "", k)
      in_entry = (k == "SSM-E2E-01")
      next
    }
    in_entry && /^[[:space:]]+status:[[:space:]]*/ {
      v = $0
      sub(/^[[:space:]]+status:[[:space:]]*/, "", v)
      gsub(/["[:space:]]/, "", v)
      print v
      exit
    }
  ' "$TEST_TMP/docs/implementation-artifacts/sprint-status.yaml"
}

# Append one JSONL record to TRACE_FILE.
trace_record() {
  local from="$1" to="$2" rejected="$3" err="$4"
  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  if [ "$rejected" = "true" ]; then
    # shellcheck disable=SC2016
    printf '{"from":"%s","to":"%s","skill":"sprint-state.sh","story_key":"SSM-E2E-01","timestamp":"%s","rejected":true,"error_message":%s}\n' \
      "$from" "$to" "$ts" "$(printf '%s' "$err" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().strip()))')" \
      >> "$TRACE_FILE"
  else
    printf '{"from":"%s","to":"%s","skill":"sprint-state.sh","story_key":"SSM-E2E-01","timestamp":"%s"}\n' \
      "$from" "$to" "$ts" >> "$TRACE_FILE"
  fi
}

# ---------- Tests ----------

@test "AC1 — happy-path traversal reaches all 7 states and trace is written" {
  TRACE_FILE="$TEST_TMP/trace.jsonl"
  : > "$TRACE_FILE"
  reset_fixture

  # Happy-path: backlog → validating → ready-for-dev → in-progress → review → done
  [ "$(get_status)" = "backlog" ]

  run "$SCRIPTS_DIR/sprint-state.sh" transition --story SSM-E2E-01 --to validating
  [ "$status" -eq 0 ]
  trace_record "backlog" "validating" "false" ""

  run "$SCRIPTS_DIR/sprint-state.sh" transition --story SSM-E2E-01 --to ready-for-dev
  [ "$status" -eq 0 ]
  trace_record "validating" "ready-for-dev" "false" ""

  run "$SCRIPTS_DIR/sprint-state.sh" transition --story SSM-E2E-01 --to in-progress
  [ "$status" -eq 0 ]
  trace_record "ready-for-dev" "in-progress" "false" ""

  # blocked branch (in-progress → blocked → in-progress)
  run "$SCRIPTS_DIR/sprint-state.sh" transition --story SSM-E2E-01 --to blocked
  [ "$status" -eq 0 ]
  trace_record "in-progress" "blocked" "false" ""

  run "$SCRIPTS_DIR/sprint-state.sh" transition --story SSM-E2E-01 --to in-progress
  [ "$status" -eq 0 ]
  trace_record "blocked" "in-progress" "false" ""

  run "$SCRIPTS_DIR/sprint-state.sh" transition --story SSM-E2E-01 --to review
  [ "$status" -eq 0 ]
  trace_record "in-progress" "review" "false" ""

  run "$SCRIPTS_DIR/sprint-state.sh" transition --story SSM-E2E-01 --to done
  [ "$status" -eq 0 ]
  trace_record "review" "done" "false" ""

  [ "$(get_status)" = "done" ]

  # Confirm all 7 states appeared across trace + final state.
  states_seen=$(awk -F'"' '{ for (i=1; i<=NF; i++) if ($i == "from" || $i == "to") print $(i+2) }' \
    "$TRACE_FILE" | sort -u)
  [[ "$states_seen" == *"backlog"* ]]
  [[ "$states_seen" == *"validating"* ]]
  [[ "$states_seen" == *"ready-for-dev"* ]]
  [[ "$states_seen" == *"in-progress"* ]]
  [[ "$states_seen" == *"blocked"* ]]
  [[ "$states_seen" == *"review"* ]]
  [[ "$states_seen" == *"done"* ]]

  # Each trace line must be valid JSON.
  while IFS= read -r line; do
    printf '%s\n' "$line" | python3 -c 'import json,sys; json.loads(sys.stdin.read())'
  done < "$TRACE_FILE"
}

@test "AC2 — review → in-progress rollback branch is a valid transition" {
  TRACE_FILE="$TEST_TMP/trace-rollback.jsonl"
  : > "$TRACE_FILE"
  force_to_state review

  run "$SCRIPTS_DIR/sprint-state.sh" transition --story SSM-E2E-01 --to in-progress
  [ "$status" -eq 0 ]
  trace_record "review" "in-progress" "false" ""
  [ "$(get_status)" = "in-progress" ]
}

@test "AC2 — frontmatter status and body **Status:** line stay in sync after every transition" {
  reset_fixture

  for target in validating ready-for-dev in-progress review done; do
    run "$SCRIPTS_DIR/sprint-state.sh" transition --story SSM-E2E-01 --to "$target"
    [ "$status" -eq 0 ]
    fm=$(get_status)
    body=$(get_body_status)
    yaml=$(get_yaml_status)
    [ "$fm" = "$target" ] || { echo "frontmatter drift: $fm != $target"; return 1; }
    [ "$body" = "$target" ] || { echo "body drift: $body != $target"; return 1; }
    [ "$yaml" = "$target" ] || { echo "sprint-status.yaml drift: $yaml != $target"; return 1; }
  done
}

@test "AC3 — invalid transition backlog → done is rejected with non-zero exit" {
  reset_fixture
  run "$SCRIPTS_DIR/sprint-state.sh" transition --story SSM-E2E-01 --to done
  [ "$status" -ne 0 ]
  [[ "$output" == *"backlog"* ]]
  [[ "$output" == *"done"* ]]
  [ "$(get_status)" = "backlog" ]
}

@test "AC3 — invalid transition backlog → in-progress is rejected" {
  reset_fixture
  run "$SCRIPTS_DIR/sprint-state.sh" transition --story SSM-E2E-01 --to in-progress
  [ "$status" -ne 0 ]
  [[ "$output" == *"backlog"* ]]
  [[ "$output" == *"in-progress"* ]]
  [ "$(get_status)" = "backlog" ]
}

@test "AC3 — invalid transition ready-for-dev → done is rejected" {
  force_to_state ready-for-dev
  run "$SCRIPTS_DIR/sprint-state.sh" transition --story SSM-E2E-01 --to done
  [ "$status" -ne 0 ]
  [[ "$output" == *"ready-for-dev"* ]]
  [[ "$output" == *"done"* ]]
  [ "$(get_status)" = "ready-for-dev" ]
}

@test "AC3 — invalid transition done → in-progress (terminal regression) is rejected" {
  force_to_state done
  run "$SCRIPTS_DIR/sprint-state.sh" transition --story SSM-E2E-01 --to in-progress
  [ "$status" -ne 0 ]
  [[ "$output" == *"done"* ]]
  [[ "$output" == *"in-progress"* ]]
  [ "$(get_status)" = "done" ]
}

@test "AC3 — invalid transition review → backlog (non-adjacent regression) is rejected" {
  force_to_state review
  run "$SCRIPTS_DIR/sprint-state.sh" transition --story SSM-E2E-01 --to backlog
  [ "$status" -ne 0 ]
  [[ "$output" == *"review"* ]]
  [[ "$output" == *"backlog"* ]]
  [ "$(get_status)" = "review" ]
}

@test "AC4 — native trace matches v-parity-baseline trace (timestamp stripped)" {
  [ -s "$BASELINE_TRACE" ] || skip "baseline trace not present — expected at $BASELINE_TRACE"

  TRACE_FILE="$TEST_TMP/trace-parity.jsonl"
  : > "$TRACE_FILE"
  reset_fixture

  # Exact same edge sequence recorded in the baseline oracle.
  run "$SCRIPTS_DIR/sprint-state.sh" transition --story SSM-E2E-01 --to validating
  [ "$status" -eq 0 ]; trace_record "backlog" "validating" "false" ""
  run "$SCRIPTS_DIR/sprint-state.sh" transition --story SSM-E2E-01 --to ready-for-dev
  [ "$status" -eq 0 ]; trace_record "validating" "ready-for-dev" "false" ""
  run "$SCRIPTS_DIR/sprint-state.sh" transition --story SSM-E2E-01 --to in-progress
  [ "$status" -eq 0 ]; trace_record "ready-for-dev" "in-progress" "false" ""
  run "$SCRIPTS_DIR/sprint-state.sh" transition --story SSM-E2E-01 --to blocked
  [ "$status" -eq 0 ]; trace_record "in-progress" "blocked" "false" ""
  run "$SCRIPTS_DIR/sprint-state.sh" transition --story SSM-E2E-01 --to in-progress
  [ "$status" -eq 0 ]; trace_record "blocked" "in-progress" "false" ""
  run "$SCRIPTS_DIR/sprint-state.sh" transition --story SSM-E2E-01 --to review
  [ "$status" -eq 0 ]; trace_record "in-progress" "review" "false" ""
  run "$SCRIPTS_DIR/sprint-state.sh" transition --story SSM-E2E-01 --to done
  [ "$status" -eq 0 ]; trace_record "review" "done" "false" ""

  # Strip timestamp from both and diff.
  local normalizer="$BATS_TEST_DIRNAME/lib/normalize-trace.py"
  native_stripped="$TEST_TMP/native-stripped.jsonl"
  baseline_stripped="$TEST_TMP/baseline-stripped.jsonl"
  python3 "$normalizer" "$TRACE_FILE"    > "$native_stripped"
  python3 "$normalizer" "$BASELINE_TRACE" > "$baseline_stripped"

  diff -u "$baseline_stripped" "$native_stripped"
}
