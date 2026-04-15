#!/usr/bin/env bats
# checkpoint.bats — unit tests for plugins/gaia/scripts/checkpoint.sh
# Public functions covered: iso_utc_now, file_mtime_utc, file_sha256,
# validate_workflow_name, yaml_scalar, resolve_checkpoint_path, cmd_write,
# cmd_read, parse_files_touched, cmd_validate, main.

load 'test_helper.bash'

setup() {
  common_setup
  SCRIPT="$SCRIPTS_DIR/checkpoint.sh"
  export CHECKPOINT_PATH="$TEST_TMP/_memory/checkpoints"
  mkdir -p "$CHECKPOINT_PATH"
}
teardown() { common_teardown; }

@test "checkpoint.sh: --help exits 0 and lists subcommands" {
  run "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"write"* ]]
  [[ "$output" == *"read"* ]]
  [[ "$output" == *"validate"* ]]
}

@test "checkpoint.sh: write happy path — writes yaml file" {
  run "$SCRIPT" write --workflow dev-story --step 3 --var story_key=E1-S1
  [ "$status" -eq 0 ]
  [ -f "$CHECKPOINT_PATH/dev-story.yaml" ]
  run cat "$CHECKPOINT_PATH/dev-story.yaml"
  [[ "$output" == *"workflow: dev-story"* ]]
  [[ "$output" == *"step: 3"* ]]
}

@test "checkpoint.sh: write then read round-trips content" {
  "$SCRIPT" write --workflow w1 --step 1
  run "$SCRIPT" read --workflow w1
  [ "$status" -eq 0 ]
  [[ "$output" == *"w1"* ]]
}

@test "checkpoint.sh: read missing checkpoint → exit 2" {
  run "$SCRIPT" read --workflow nope
  [ "$status" -eq 2 ]
}

@test "checkpoint.sh: write rejects malformed workflow name" {
  run "$SCRIPT" write --workflow "../evil" --step 1
  [ "$status" -ne 0 ]
}

@test "checkpoint.sh: write with --file records sha256 in files_touched" {
  local f="$TEST_TMP/touched.txt"
  printf "hello\n" > "$f"
  run "$SCRIPT" write --workflow w2 --step 1 --file "$f"
  [ "$status" -eq 0 ]
  run cat "$CHECKPOINT_PATH/w2.yaml"
  [[ "$output" == *"files_touched"* ]]
  [[ "$output" == *"sha256:"* ]]
}

@test "checkpoint.sh: write with --file pointing to missing path fails" {
  run "$SCRIPT" write --workflow w3 --step 1 --file "$TEST_TMP/missing.txt"
  [ "$status" -ne 0 ]
}

@test "checkpoint.sh: validate happy path returns 0 when files unchanged" {
  local f="$TEST_TMP/a.txt"
  printf "stable\n" > "$f"
  "$SCRIPT" write --workflow w4 --step 1 --file "$f"
  run "$SCRIPT" validate --workflow w4
  [ "$status" -eq 0 ]
}

@test "checkpoint.sh: validate detects checksum drift" {
  local f="$TEST_TMP/b.txt"
  printf "v1\n" > "$f"
  "$SCRIPT" write --workflow w5 --step 1 --file "$f"
  printf "v2\n" > "$f"
  run "$SCRIPT" validate --workflow w5
  [ "$status" -ne 0 ]
}

@test "checkpoint.sh: idempotent — two writes with no diffs produce stable step" {
  "$SCRIPT" write --workflow w6 --step 1 --var k=v
  local a b
  a="$(cat "$CHECKPOINT_PATH/w6.yaml" | grep -v '^timestamp:' | grep -v 'last_modified:')"
  "$SCRIPT" write --workflow w6 --step 1 --var k=v
  b="$(cat "$CHECKPOINT_PATH/w6.yaml" | grep -v '^timestamp:' | grep -v 'last_modified:')"
  [ "$a" = "$b" ]
}

@test "checkpoint.sh: usage error with no args → non-zero" {
  run "$SCRIPT"
  [ "$status" -ne 0 ]
}
