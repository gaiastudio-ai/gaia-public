#!/usr/bin/env bats
# write-checkpoint.bats — unit tests for plugins/gaia/scripts/write-checkpoint.sh
# Covers VCP-CPT-01 (schema v1 shape), VCP-CPT-10 (atomic write under SIGKILL),
# AC1-AC6 and AC-EC1..AC-EC10 from story E43-S1.
#
# Refs: docs/implementation-artifacts/E43-S1-*.md,
#       docs/test-artifacts/test-plan.md §11.46.2,
#       docs/planning-artifacts/architecture.md §10.31.3 (ADR-059).

load 'test_helper.bash'

setup() {
  common_setup
  SCRIPT="$SCRIPTS_DIR/write-checkpoint.sh"
  # Isolate checkpoint root per test so concurrent test runs don't clash.
  export CHECKPOINT_ROOT="$TEST_TMP/_memory/checkpoints"
  mkdir -p "$CHECKPOINT_ROOT"
  # The script locates the checkpoint root via the CHECKPOINT_ROOT env var.
  # (Contract chosen deliberately: isolates from CHECKPOINT_PATH used by
  #  the older checkpoint.sh script — see Dev Notes in the story.)
}
teardown() { common_teardown; }

# ---------- Sanity ----------

@test "write-checkpoint.sh: exists and is executable" {
  [ -f "$SCRIPT" ]
  [ -x "$SCRIPT" ]
}

@test "write-checkpoint.sh: --help exits 0 and documents CLI surface" {
  run "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"skill_name"* ]]
  [[ "$output" == *"step_number"* ]]
  [[ "$output" == *"--paths"* ]]
}

# ---------- AC1: happy path write ----------

@test "AC1: valid invocation writes JSON to _memory/checkpoints/{skill}/{ts}-step-{N}.json" {
  local touched="$TEST_TMP/touched.md"
  printf 'hello\n' > "$touched"
  run "$SCRIPT" gaia-brainstorm 3 slug=test --paths "$touched"
  [ "$status" -eq 0 ]
  # Exactly one json file under the skill directory.
  local dir="$CHECKPOINT_ROOT/gaia-brainstorm"
  [ -d "$dir" ]
  local count
  count=$(find "$dir" -name '*.json' -type f | wc -l | tr -d ' ')
  [ "$count" = "1" ]
  # Filename convention: {ISO8601-microseconds-Z}-step-{N}.json
  local fname
  fname=$(basename "$(find "$dir" -name '*.json' -type f)")
  [[ "$fname" == *"-step-3.json" ]]
  # Valid JSON.
  run jq . "$dir"/*.json
  [ "$status" -eq 0 ]
}

# ---------- AC4 / VCP-CPT-01: schema v1 shape + types ----------

@test "AC4/VCP-CPT-01: JSON carries all 7 mandatory schema fields with correct types" {
  local touched="$TEST_TMP/touched.md"
  printf 'hi\n' > "$touched"
  "$SCRIPT" gaia-brainstorm 2 slug=test --paths "$touched"
  local json
  json=$(find "$CHECKPOINT_ROOT/gaia-brainstorm" -name '*.json' -type f)
  # schema_version integer = 1
  run jq -r '.schema_version' "$json"
  [ "$output" = "1" ]
  run jq -r '.schema_version | type' "$json"
  [ "$output" = "number" ]
  # step_number integer >= 0
  run jq -r '.step_number' "$json"
  [ "$output" = "2" ]
  # skill_name non-empty string
  run jq -r '.skill_name' "$json"
  [ "$output" = "gaia-brainstorm" ]
  # timestamp ISO 8601
  run jq -r '.timestamp' "$json"
  [[ "$output" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2} ]]
  # key_variables is an object carrying slug=test
  run jq -r '.key_variables.slug' "$json"
  [ "$output" = "test" ]
  run jq -r '.key_variables | type' "$json"
  [ "$output" = "object" ]
  # output_paths array of strings
  run jq -r '.output_paths | type' "$json"
  [ "$output" = "array" ]
  run jq -r '.output_paths[0]' "$json"
  [ "$output" = "$touched" ]
  # file_checksums object mapping path → sha256:<64hex>
  run jq -r --arg p "$touched" '.file_checksums[$p]' "$json"
  [[ "$output" =~ ^sha256:[0-9a-f]{64}$ ]]
}

# ---------- AC5: checksums match on-disk contents ----------

@test "AC5: file_checksums match actual sha256 of output_paths" {
  local a="$TEST_TMP/a.md" b="$TEST_TMP/b.md"
  printf 'alpha\n' > "$a"
  printf 'beta\n'  > "$b"
  "$SCRIPT" gaia-skill 1 --paths "$a" "$b"
  local json
  json=$(find "$CHECKPOINT_ROOT/gaia-skill" -name '*.json' -type f)
  local expected_a expected_b
  expected_a=$(shasum -a 256 "$a" | awk '{print $1}')
  expected_b=$(shasum -a 256 "$b" | awk '{print $1}')
  run jq -r --arg p "$a" '.file_checksums[$p]' "$json"
  [ "$output" = "sha256:$expected_a" ]
  run jq -r --arg p "$b" '.file_checksums[$p]' "$json"
  [ "$output" = "sha256:$expected_b" ]
}

# ---------- AC3: custom: namespace preserved ----------

@test "AC3: --custom JSON block preserved verbatim under 'custom' key" {
  local custom="$TEST_TMP/custom.json"
  printf '{"foo":"bar","nested":{"x":1}}' > "$custom"
  "$SCRIPT" gaia-skill 0 --custom "$custom"
  local json
  json=$(find "$CHECKPOINT_ROOT/gaia-skill" -name '*.json' -type f)
  run jq -r '.custom.foo' "$json"
  [ "$output" = "bar" ]
  run jq -r '.custom.nested.x' "$json"
  [ "$output" = "1" ]
}

# ---------- VCP-CPT-10 / AC2: atomic write (SIGKILL mid-run leaves no partial) ----------

@test "VCP-CPT-10/AC2: SIGKILL during write leaves no partial JSON file" {
  local big="$TEST_TMP/big.bin"
  # Create a file large enough that checksum + write take measurable time.
  dd if=/dev/zero of="$big" bs=1M count=8 status=none
  "$SCRIPT" gaia-skill 1 --paths "$big" &
  local pid=$!
  # Kill hard immediately — before the tmp->final mv can complete.
  kill -9 "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  # Directory may not exist at all — that's a valid post-state.
  if [ -d "$CHECKPOINT_ROOT/gaia-skill" ]; then
    # Any *.json file that exists must be valid JSON.
    for f in "$CHECKPOINT_ROOT/gaia-skill"/*.json; do
      [ -f "$f" ] || continue
      jq . "$f" >/dev/null
    done
    # No lingering tmp files.
    local tmp_count
    tmp_count=$(find "$CHECKPOINT_ROOT/gaia-skill" -name '*.tmp' -type f | wc -l | tr -d ' ')
    [ "$tmp_count" = "0" ]
  fi
}

# ---------- AC-EC1: zero output paths ----------

@test "AC-EC1: zero --paths writes empty output_paths and file_checksums" {
  run "$SCRIPT" gaia-skill 4
  [ "$status" -eq 0 ]
  local json
  json=$(find "$CHECKPOINT_ROOT/gaia-skill" -name '*.json' -type f)
  run jq -r '.output_paths | length' "$json"
  [ "$output" = "0" ]
  run jq -r '.file_checksums | length' "$json"
  [ "$output" = "0" ]
}

# ---------- AC-EC2: missing output path ----------

@test "AC-EC2: missing output path exits non-zero and writes no file" {
  run "$SCRIPT" gaia-skill 1 --paths "$TEST_TMP/does-not-exist.md"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]] || [[ "$output" == *"does not exist"* ]] || [[ "$output" == *"no such file"* ]]
  # No checkpoint file written.
  if [ -d "$CHECKPOINT_ROOT/gaia-skill" ]; then
    local count
    count=$(find "$CHECKPOINT_ROOT/gaia-skill" -name '*.json' -type f | wc -l | tr -d ' ')
    [ "$count" = "0" ]
  fi
}

# ---------- AC-EC3: unwriteable checkpoint dir ----------

@test "AC-EC3: unwriteable checkpoint root exits non-zero with clear error" {
  # Point at a location under a file (not a directory), forcing mkdir to fail.
  local blocker="$TEST_TMP/blocker"
  printf 'block\n' > "$blocker"
  # Place checkpoints under blocker (regular file) — mkdir -p must fail.
  export CHECKPOINT_ROOT="$blocker/checkpoints"
  run "$SCRIPT" gaia-skill 1
  [ "$status" -ne 0 ]
  # No stray tmp file next to the blocker.
  local tmp_count
  tmp_count=$(find "$TEST_TMP" -name '*.tmp' -type f 2>/dev/null | wc -l | tr -d ' ')
  [ "$tmp_count" = "0" ]
}

# ---------- AC-EC4: concurrent same-step writes ----------

@test "AC-EC4: two same-step concurrent writes produce distinct valid files" {
  local f="$TEST_TMP/f.md"; printf 'x\n' > "$f"
  "$SCRIPT" gaia-skill 5 --paths "$f" &
  local pid1=$!
  "$SCRIPT" gaia-skill 5 --paths "$f" &
  local pid2=$!
  wait "$pid1"
  wait "$pid2"
  local count
  count=$(find "$CHECKPOINT_ROOT/gaia-skill" -name '*-step-5.json' -type f | wc -l | tr -d ' ')
  [ "$count" = "2" ]
  # Both files are valid JSON.
  for f in "$CHECKPOINT_ROOT/gaia-skill"/*-step-5.json; do
    jq . "$f" >/dev/null
  done
}

# ---------- AC-EC5: path-traversal in skill_name ----------

@test "AC-EC5: malicious skill_name (path traversal) is rejected" {
  run "$SCRIPT" "../etc" 1
  [ "$status" -ne 0 ]
  [[ "$output" == *"invalid skill_name"* ]]
  # No file written anywhere in TEST_TMP outside checkpoints.
  ! [ -e "$TEST_TMP/../etc" ]
}

@test "AC-EC5: absolute path in skill_name is rejected" {
  run "$SCRIPT" "/tmp/evil" 1
  [ "$status" -ne 0 ]
  [[ "$output" == *"invalid skill_name"* ]]
}

@test "AC-EC5: uppercase skill_name is rejected" {
  run "$SCRIPT" "BadName" 1
  [ "$status" -ne 0 ]
  [[ "$output" == *"invalid skill_name"* ]]
}

# ---------- AC-EC6: shell metacharacters in key_variables ----------

@test "AC-EC6: shell metacharacters in key_variables are preserved verbatim" {
  local evil='$(rm -rf /)'
  "$SCRIPT" gaia-skill 1 "danger=$evil"
  local json
  json=$(find "$CHECKPOINT_ROOT/gaia-skill" -name '*.json' -type f)
  run jq -r '.key_variables.danger' "$json"
  [ "$output" = "$evil" ]
  # Round-trip: jq can parse.
  run jq . "$json"
  [ "$status" -eq 0 ]
}

# ---------- AC-EC7: missing sha256 tool ----------

@test "AC-EC7: sha256 tool missing exits non-zero with clear error" {
  local f="$TEST_TMP/f.md"; printf 'x\n' > "$f"
  # Construct a PATH with only the temp dir and the script's own dir (so the
  # script can still be resolved) but no shasum/sha256sum.
  local stubdir="$TEST_TMP/stubs"
  mkdir -p "$stubdir"
  run env PATH="$stubdir" "$SCRIPT" gaia-skill 1 --paths "$f"
  [ "$status" -ne 0 ]
  [[ "$output" == *"sha256"* ]]
  # No checkpoint file written.
  if [ -d "$CHECKPOINT_ROOT/gaia-skill" ]; then
    local count
    count=$(find "$CHECKPOINT_ROOT/gaia-skill" -name '*.json' -type f | wc -l | tr -d ' ')
    [ "$count" = "0" ]
  fi
}

# ---------- AC-EC8: clock regression (step_number is authoritative) ----------

@test "AC-EC8: two writes with step_number 1 then 2 both succeed (step ordering authoritative)" {
  local f="$TEST_TMP/f.md"; printf 'x\n' > "$f"
  "$SCRIPT" gaia-skill 1 --paths "$f"
  "$SCRIPT" gaia-skill 2 --paths "$f"
  local c1 c2
  c1=$(find "$CHECKPOINT_ROOT/gaia-skill" -name '*-step-1.json' -type f | wc -l | tr -d ' ')
  c2=$(find "$CHECKPOINT_ROOT/gaia-skill" -name '*-step-2.json' -type f | wc -l | tr -d ' ')
  [ "$c1" = "1" ]
  [ "$c2" = "1" ]
}

# ---------- AC-EC9: invalid step_number ----------

@test "AC-EC9: negative step_number is rejected" {
  run "$SCRIPT" gaia-skill -1
  [ "$status" -ne 0 ]
  [[ "$output" == *"step_number"* ]]
  [[ "$output" == *"non-negative integer"* ]]
}

@test "AC-EC9: non-numeric step_number is rejected" {
  run "$SCRIPT" gaia-skill abc
  [ "$status" -ne 0 ]
  [[ "$output" == *"step_number"* ]]
}

# ---------- AC-EC10: symlink output path ----------

@test "AC-EC10: symlink output path is followed and checksum matches target" {
  local target="$TEST_TMP/target.md"
  local link="$TEST_TMP/link.md"
  printf 'linked\n' > "$target"
  ln -s "$target" "$link"
  "$SCRIPT" gaia-skill 1 --paths "$link"
  local json
  json=$(find "$CHECKPOINT_ROOT/gaia-skill" -name '*.json' -type f)
  local expected
  expected=$(shasum -a 256 "$target" | awk '{print $1}')
  run jq -r --arg p "$link" '.file_checksums[$p]' "$json"
  [ "$output" = "sha256:$expected" ]
}

# ---------- AC3 negative: unknown top-level key rejected ----------

@test "AC3: unknown top-level key in --custom is preserved UNDER custom (not promoted)" {
  # --custom contents land under "custom" — any non-schema top-level key MUST
  # NOT be injected at the root. This is enforced implicitly because we only
  # ever place user data under the "custom" key.
  local custom="$TEST_TMP/c.json"
  printf '{"schema_version":999,"rogue":"nope"}' > "$custom"
  "$SCRIPT" gaia-skill 0 --custom "$custom"
  local json
  json=$(find "$CHECKPOINT_ROOT/gaia-skill" -name '*.json' -type f)
  # Root schema_version is still 1 (custom did not override).
  run jq -r '.schema_version' "$json"
  [ "$output" = "1" ]
  # Rogue key only present under .custom, never at root.
  run jq -r '.rogue // "absent"' "$json"
  [ "$output" = "absent" ]
  run jq -r '.custom.rogue' "$json"
  [ "$output" = "nope" ]
}
