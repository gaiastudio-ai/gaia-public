#!/usr/bin/env bats
# lifecycle-event.bats — unit tests for plugins/gaia/scripts/lifecycle-event.sh
# Public functions covered: iso_utc_now_ms, event_type_allowed,
# append_line, main.

load 'test_helper.bash'

setup() {
  common_setup
  SCRIPT="$SCRIPTS_DIR/lifecycle-event.sh"
  export MEMORY_PATH="$TEST_TMP/_memory"
  JSONL="$MEMORY_PATH/lifecycle-events.jsonl"
}
teardown() { common_teardown; }

need_jq() {
  command -v jq >/dev/null 2>&1 || skip "jq not on PATH"
}

@test "lifecycle-event.sh: --help prints usage, exits 0" {
  run "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *[Uu]sage* ]]
}

@test "lifecycle-event.sh: happy path emits one valid JSON line" {
  need_jq
  run "$SCRIPT" --type step_complete --workflow create-story
  [ "$status" -eq 0 ]
  [ -f "$JSONL" ]
  [ "$(wc -l < "$JSONL" | tr -d ' ')" = "1" ]
  run jq -e . "$JSONL"
  [ "$status" -eq 0 ]
}

@test "lifecycle-event.sh: full field event includes story_key/step/data" {
  need_jq
  run "$SCRIPT" --type gate_failed --workflow dev-story --story E1-S1 --step 7 --data '{"gate":"lint"}'
  [ "$status" -eq 0 ]
  line="$(tail -1 "$JSONL")"
  printf '%s' "$line" | jq -e '.event_type == "gate_failed" and .workflow == "dev-story" and .story_key == "E1-S1" and .step == 7 and .data.gate == "lint"' >/dev/null
}

@test "lifecycle-event.sh: timestamp is ISO 8601 UTC with ms precision" {
  need_jq
  "$SCRIPT" --type step_complete --workflow w
  local ts
  ts="$(jq -r .timestamp "$JSONL")"
  [[ "$ts" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3}Z$ ]]
}

@test "lifecycle-event.sh: missing --type → non-zero with usage hint" {
  run "$SCRIPT" --workflow create-story
  [ "$status" -ne 0 ]
  [[ "$output" == *[Tt]ype* ]]
}

@test "lifecycle-event.sh: malformed --data rejected, no partial append" {
  run "$SCRIPT" --type step_complete --workflow x --data 'not-json'
  [ "$status" -ne 0 ]
  [ ! -s "$JSONL" ] || [ "$(wc -l < "$JSONL" | tr -d ' ')" = "0" ]
}

@test "lifecycle-event.sh: event-types file rejects unknown type" {
  local f="$TEST_TMP/types.txt"
  printf 'step_complete\ngate_failed\n' > "$f"
  run "$SCRIPT" --type bogus --workflow x --event-types-file "$f"
  [ "$status" -ne 0 ]
  [[ "$output" == *"bogus"* ]]
}

@test "lifecycle-event.sh: event-types file accepts known type" {
  local f="$TEST_TMP/types.txt"
  printf 'step_complete\n' > "$f"
  run "$SCRIPT" --type step_complete --workflow x --event-types-file "$f"
  [ "$status" -eq 0 ]
  [ -s "$JSONL" ]
}

@test "lifecycle-event.sh: 10 concurrent writes produce 10 valid lines" {
  need_jq
  seq 1 10 | xargs -P 10 -I {} "$SCRIPT" --type concurrent_test --workflow cw --step {}
  [ "$(wc -l < "$JSONL" | tr -d ' ')" = "10" ]
  while IFS= read -r l; do printf '%s' "$l" | jq -e . >/dev/null; done < "$JSONL"
}

@test "lifecycle-event.sh: JSONL created with 0644 permissions" {
  "$SCRIPT" --type step_complete --workflow w
  local mode
  if stat -f %Lp "$JSONL" >/dev/null 2>&1; then mode=$(stat -f %Lp "$JSONL")
  else mode=$(stat -c %a "$JSONL"); fi
  [ "$mode" = "644" ]
}
