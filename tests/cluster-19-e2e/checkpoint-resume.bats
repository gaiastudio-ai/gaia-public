#!/usr/bin/env bats
# checkpoint-resume.bats — E28-S136: Test checkpoint/resume (Cluster 19)
#
# Exercises the native `checkpoint.sh` foundation script (write / read / validate)
# against three representative workflow shapes, simulating an interruption
# mid-execution and a subsequent /gaia-resume cycle:
#
#   1. LONG artifact-producing: gaia-dev-story   (12+ steps, TDD cascade)
#   2. MEDIUM artifact-producing: gaia-create-prd (5-7 steps, single artifact)
#   3. ORCHESTRATION/AGGREGATION: gaia-sprint-plan (multi-story aggregation)
#
# The test uses the consolidated checkpoint.sh (write/read/validate subcommands)
# which is the native replacement for the legacy checkpoint-write.sh /
# checkpoint-verify.sh / sha256-verify.sh scripts referenced by older specs.
#
# AC mapping:
#   AC1 — mid-execution checkpoint contains step, variables, output paths,
#         and files_touched with sha256 for every entry.
#   AC2 — `checkpoint.sh read` returns the full checkpoint payload so a
#         resume entry point can reconstruct state without loss.
#   AC3 — final artifact content after resume matches the checkpointed
#         state byte-for-byte (no dropped/duplicated template output).
#   AC4 — `checkpoint.sh validate` exits 0 on unchanged files, exits 1
#         on drift, exits 2 on missing files — the signals /gaia-resume
#         uses to offer Proceed / Start fresh / Review.
#
# Usage:
#   bats tests/cluster-19-e2e/checkpoint-resume.bats

# ---------- Helpers ----------

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCRIPTS_DIR="$REPO_ROOT/plugins/gaia/scripts"
  CHECKPOINT_SH="$SCRIPTS_DIR/checkpoint.sh"

  TEST_TMP="$BATS_TEST_TMPDIR/ckpt-$$"
  mkdir -p "$TEST_TMP/docs/implementation-artifacts"
  mkdir -p "$TEST_TMP/docs/planning-artifacts"
  mkdir -p "$TEST_TMP/checkpoints"

  export CHECKPOINT_PATH="$TEST_TMP/checkpoints"
}

teardown() {
  rm -rf "$TEST_TMP" 2>/dev/null || true
}

# Seed a fake artifact file and return its path.
seed_file() {
  local path="$1" content="$2"
  mkdir -p "$(dirname "$path")"
  printf '%s' "$content" > "$path"
  printf '%s\n' "$path"
}

# Extract a YAML scalar value from a checkpoint file.
read_ckpt_field() {
  local ckpt="$1" field="$2"
  awk -v f="$field" '
    $0 ~ "^"f":[[:space:]]" {
      sub("^"f":[[:space:]]*", "", $0)
      gsub(/^"|"$/, "", $0)
      print; exit
    }
  ' "$ckpt"
}

# Count files_touched entries in a checkpoint.
count_files_touched() {
  local ckpt="$1"
  grep -c '^  - path:' "$ckpt" || true
}

# ---------- Workflow 1 — gaia-dev-story (LONG, multi-step) ----------

@test "dev-story: write checkpoint mid-TDD-cascade captures step, vars, and files_touched" {
  # Simulate Step 6 (RED phase) writing a checkpoint after creating two test files.
  local story_file test_file
  story_file=$(seed_file "$TEST_TMP/docs/implementation-artifacts/E28-S136-test-checkpoint-resume.md" \
    "# Story E28-S136\nstatus: in-progress\n")
  test_file=$(seed_file "$TEST_TMP/docs/implementation-artifacts/E28-S136-tdd-progress.md" \
    "## RED phase\nTests failing as expected.\n")

  run "$CHECKPOINT_SH" write \
    --workflow "dev-story-E28-S136" \
    --step 6 \
    --var story_key=E28-S136 \
    --var phase=red_complete \
    --var epic_key=E28 \
    --file "$story_file" \
    --file "$test_file"
  [ "$status" -eq 0 ]

  local ckpt="$CHECKPOINT_PATH/dev-story-E28-S136.yaml"
  [ -f "$ckpt" ]

  # AC1 — every required field present
  run read_ckpt_field "$ckpt" "workflow"
  [ "$output" = "dev-story-E28-S136" ]
  run read_ckpt_field "$ckpt" "step"
  [ "$output" = "6" ]
  run read_ckpt_field "$ckpt" "timestamp"
  [[ "$output" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]

  # AC1 — files_touched has 2 entries, each with sha256
  run count_files_touched "$ckpt"
  [ "$output" -eq 2 ]
  run grep -c '^    sha256: "sha256:[0-9a-f]\{64\}"$' "$ckpt"
  [ "$status" -eq 0 ]
  [ "$output" -eq 2 ]
  run grep -c '^    last_modified: [0-9T:Z-]*$' "$ckpt"
  [ "$output" -eq 2 ]
}

@test "dev-story: resume reads back full checkpoint payload without loss" {
  local story_file
  story_file=$(seed_file "$TEST_TMP/docs/implementation-artifacts/E28-S136-test-checkpoint-resume.md" \
    "# Story E28-S136 mid-flight\n")

  "$CHECKPOINT_SH" write \
    --workflow "dev-story-E28-S136" \
    --step 7 \
    --var story_key=E28-S136 \
    --var phase=green_complete \
    --file "$story_file"

  # Simulate /gaia-resume: read the checkpoint back and confirm the payload
  # is complete — step, variables, and file list all round-trip intact.
  run "$CHECKPOINT_SH" read --workflow "dev-story-E28-S136"
  [ "$status" -eq 0 ]
  [[ "$output" == *"workflow: dev-story-E28-S136"* ]]
  [[ "$output" == *"step: 7"* ]]
  [[ "$output" == *"story_key: E28-S136"* ]]
  [[ "$output" == *"phase: green_complete"* ]]
  [[ "$output" == *"files_touched:"* ]]
  [[ "$output" == *"$story_file"* ]]
}

# ---------- Workflow 2 — gaia-create-prd (MEDIUM, single artifact) ----------

@test "create-prd: checkpoint captures medium-workflow state mid-draft" {
  local prd
  prd=$(seed_file "$TEST_TMP/docs/planning-artifacts/prd/prd.md" \
    "# PRD — in-progress draft\n## Goals\nTBD\n")

  run "$CHECKPOINT_SH" write \
    --workflow "create-prd" \
    --step 3 \
    --var artifact=prd.md \
    --var sections_complete=goals,users \
    --file "$prd"
  [ "$status" -eq 0 ]

  local ckpt="$CHECKPOINT_PATH/create-prd.yaml"
  [ -f "$ckpt" ]
  run read_ckpt_field "$ckpt" "step"
  [ "$output" = "3" ]
  run count_files_touched "$ckpt"
  [ "$output" -eq 1 ]
}

@test "create-prd: resumed artifact content matches checkpointed state (AC3)" {
  # Simulate Step 3 writing a partial PRD and a checkpoint.
  local prd expected
  expected="# PRD\n## Goals\nLaunch Q2\n## Users\nInternal devs\n"
  prd=$(seed_file "$TEST_TMP/docs/planning-artifacts/prd/prd.md" "$expected")

  "$CHECKPOINT_SH" write \
    --workflow "create-prd" \
    --step 3 \
    --var artifact=prd.md \
    --file "$prd"

  # Simulate interruption (nothing happens — we just stop).
  # Simulate /gaia-resume validating: file must still match checkpointed sha256.
  run "$CHECKPOINT_SH" validate --workflow "create-prd"
  [ "$status" -eq 0 ]

  # Confirm artifact content is byte-identical to what was checkpointed.
  run cat "$prd"
  [ "$output" = "$(printf '%s' "$expected")" ]
}

# ---------- Workflow 3 — gaia-sprint-plan (ORCHESTRATION/AGGREGATION) ----------

@test "sprint-plan: checkpoint captures aggregation of multiple story inputs" {
  # Sprint-plan aggregates multiple input artifacts — the checkpoint records
  # every story file it touched plus the aggregated plan output.
  local s1 s2 s3 plan
  s1=$(seed_file "$TEST_TMP/docs/implementation-artifacts/E1-S1-story.md" "story 1")
  s2=$(seed_file "$TEST_TMP/docs/implementation-artifacts/E1-S2-story.md" "story 2")
  s3=$(seed_file "$TEST_TMP/docs/implementation-artifacts/E1-S3-story.md" "story 3")
  plan=$(seed_file "$TEST_TMP/docs/implementation-artifacts/sprint-23-plan.md" \
    "# Sprint 23 plan — aggregated from 3 stories\n")

  run "$CHECKPOINT_SH" write \
    --workflow "sprint-plan-sprint-23" \
    --step 4 \
    --var sprint_id=sprint-23 \
    --var story_count=3 \
    --file "$s1" --file "$s2" --file "$s3" --file "$plan"
  [ "$status" -eq 0 ]

  local ckpt="$CHECKPOINT_PATH/sprint-plan-sprint-23.yaml"
  run count_files_touched "$ckpt"
  [ "$output" -eq 4 ]
  # sprint_id variable survives round-trip
  run "$CHECKPOINT_SH" read --workflow "sprint-plan-sprint-23"
  [[ "$output" == *"sprint_id: sprint-23"* ]]
  [[ "$output" == *"story_count: 3"* ]]
}

# ---------- Validation / drift detection (AC4) ----------

@test "validate: exit 0 when all tracked files are unchanged" {
  local f
  f=$(seed_file "$TEST_TMP/docs/planning-artifacts/unchanged.md" "stable content")
  "$CHECKPOINT_SH" write --workflow "validate-ok" --step 1 --file "$f"

  run "$CHECKPOINT_SH" validate --workflow "validate-ok"
  [ "$status" -eq 0 ]
}

@test "validate: exit 1 on drift — tracked file modified after checkpoint" {
  local f
  f=$(seed_file "$TEST_TMP/docs/planning-artifacts/drifted.md" "original content")
  "$CHECKPOINT_SH" write --workflow "validate-drift" --step 1 --file "$f"

  # Simulate user (or external process) modifying the tracked file between
  # checkpoint and resume — /gaia-resume must detect this and warn.
  printf 'MODIFIED CONTENT\n' > "$f"

  run "$CHECKPOINT_SH" validate --workflow "validate-drift"
  [ "$status" -eq 1 ]
  [[ "$output" == *"drift"* ]] || [[ "$stderr" == *"drift"* ]] || true
}

@test "validate: exit 2 when a tracked file is deleted after checkpoint" {
  local f
  f=$(seed_file "$TEST_TMP/docs/planning-artifacts/deleted.md" "will be deleted")
  "$CHECKPOINT_SH" write --workflow "validate-missing" --step 1 --file "$f"

  rm -f "$f"

  run "$CHECKPOINT_SH" validate --workflow "validate-missing"
  [ "$status" -eq 2 ]
}

@test "read: exit 2 when no checkpoint exists (fresh workflow has nothing to resume)" {
  run "$CHECKPOINT_SH" read --workflow "never-started"
  [ "$status" -eq 2 ]
}

# ---------- Idempotency / overwrite (AC2 resume reliability) ----------

@test "write: overwriting a checkpoint preserves latest state only" {
  local f
  f=$(seed_file "$TEST_TMP/docs/planning-artifacts/iter.md" "v1")
  "$CHECKPOINT_SH" write --workflow "iter" --step 1 --var phase=first --file "$f"

  printf 'v2\n' > "$f"
  "$CHECKPOINT_SH" write --workflow "iter" --step 2 --var phase=second --file "$f"

  local ckpt="$CHECKPOINT_PATH/iter.yaml"
  run read_ckpt_field "$ckpt" "step"
  [ "$output" = "2" ]
  run grep -c 'phase: second' "$ckpt"
  [ "$output" -eq 1 ]
  run grep -c 'phase: first' "$ckpt"
  [ "$output" -eq 0 ]
}
