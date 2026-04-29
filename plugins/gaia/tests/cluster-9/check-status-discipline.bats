#!/usr/bin/env bats
# check-status-discipline.bats — Cluster 9 unit test (E59-S5)
#
# Asserts the contract of the pre-commit script `check-status-discipline.sh`,
# which scans staged changes for direct `status:` edits in story frontmatter,
# `sprint-status.yaml`, or `epics-and-stories.md` per-story status indicators
# that did NOT also invoke `transition-story-status.sh` in the same change-set.
#
# Test scenarios (per story §Test Scenarios):
#   1. Clean diff — no status edits → exit 0, silent
#   2. Manual status edit in story file (no transition marker) → non-zero, names file:line
#   3. Status edit + transition-script marker present → exit 0
#   4. Mixed diff — status edit + unrelated changes (no marker) → non-zero
#   5. Pre-commit hook integration — temp git repo, hook blocks commit
#   6. Sprint-boundary exception — new sprint block in sprint-status.yaml → exit 0
#   7. epics-and-stories.md status edit (no marker) → non-zero
#   8. sprint-status.yaml mid-sprint edit (no marker) → non-zero
#
# Refs: AF-2026-04-28-7, ADR-074 contract C3, Work Item 1 AC6/AC7/AC8.
# Story: E59-S5.

load 'test_helper.bash'

# ---------- Paths ----------

CLUSTER9_DIR="${BATS_TEST_DIRNAME}"
FIXTURES_DIR="${CLUSTER9_DIR}/fixtures/check-status-discipline"
SCRIPTS_DIR="$(cd "${BATS_TEST_DIRNAME}/../../scripts" && pwd)"

DISCIPLINE_SH="$SCRIPTS_DIR/check-status-discipline.sh"

# ---------- Helpers ----------

setup() {
  common_setup
  TEST_PROJECT="$TEST_TMP"
  mkdir -p "$TEST_PROJECT"
  export PROJECT_PATH="$TEST_PROJECT"

  # Build a synthetic git repo so .git/<marker> resolves cleanly
  ( cd "$TEST_PROJECT" && git init -q && git config user.email t@t && git config user.name t )

  # Marker location used by the discipline check
  export STATUS_TRANSITION_MARKER="$TEST_PROJECT/.git/gaia-status-transition.marker"
}

teardown() {
  common_teardown
}

# Stage a synthetic file change. Args: <relative_file_path> <content>
stage_file() {
  local rel="$1" content="$2"
  local abs="$TEST_PROJECT/$rel"
  mkdir -p "$(dirname "$abs")"
  printf '%s' "$content" > "$abs"
  ( cd "$TEST_PROJECT" && git add -- "$rel" )
}

# Modify a tracked file and re-stage. Args: <rel> <new_content>
modify_staged_file() {
  local rel="$1" content="$2"
  local abs="$TEST_PROJECT/$rel"
  mkdir -p "$(dirname "$abs")"
  printf '%s' "$content" > "$abs"
  ( cd "$TEST_PROJECT" && git add -- "$rel" )
}

# Initial commit so subsequent modifications produce real "status:" line diffs
seed_initial_commit() {
  local rel="$1" content="$2"
  local abs="$TEST_PROJECT/$rel"
  mkdir -p "$(dirname "$abs")"
  printf '%s' "$content" > "$abs"
  ( cd "$TEST_PROJECT" && git add -- "$rel" && git commit -q -m initial )
}

# Story frontmatter content — base + variants
story_with_status() {
  local status="$1"
  cat <<EOF
---
key: "E1-S1"
status: ${status}
---

# Story

> **Status:** ${status}

Body
EOF
}

# Sprint-status.yaml content with a per-story status entry
sprint_status_yaml() {
  local status="$1"
  cat <<EOF
sprint_id: sprint-1
stories:
  E1-S1:
    status: ${status}
EOF
}

# Sprint-status.yaml content with a freshly seeded sprint block (boundary)
sprint_status_yaml_new_sprint() {
  cat <<EOF
sprint_id: sprint-2
stories:
  E1-S2:
    status: ready-for-dev
EOF
}

# epics-and-stories.md content with a per-story status indicator
epics_and_stories_md() {
  local status="$1"
  cat <<EOF
# Epics & Stories

### Story E1-S1

- **Status:** ${status}
EOF
}

# Write a fresh transition marker for the given story key
write_marker() {
  local story_key="$1"
  printf 'story_key=%s\ntimestamp=%s\nfrom=ready-for-dev\nto=in-progress\n' \
    "$story_key" "$(date -u +%s)" > "$STATUS_TRANSITION_MARKER"
}

# ---------- Tests ----------

@test "AC3: clean diff with no status edits → exit 0, silent" {
  stage_file "README.md" "hello world"
  run "$DISCIPLINE_SH"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "AC1: manual status edit in story file without marker → non-zero, names file:line" {
  local rel="docs/implementation-artifacts/E1-S1-test.md"
  seed_initial_commit "$rel" "$(story_with_status 'ready-for-dev')"
  modify_staged_file "$rel" "$(story_with_status 'in-progress')"
  rm -f "$STATUS_TRANSITION_MARKER"
  run "$DISCIPLINE_SH"
  [ "$status" -ne 0 ]
  [[ "$output" == *"$rel"* ]]
  [[ "$output" == *":"* ]]  # line number suffix
}

@test "AC4: status edit accompanied by transition marker → exit 0" {
  local rel="docs/implementation-artifacts/E1-S1-test.md"
  seed_initial_commit "$rel" "$(story_with_status 'ready-for-dev')"
  modify_staged_file "$rel" "$(story_with_status 'in-progress')"
  write_marker "E1-S1"
  run "$DISCIPLINE_SH"
  [ "$status" -eq 0 ]
}

@test "Scenario 4: mixed diff (story status edit + unrelated change) without marker → non-zero" {
  local rel="docs/implementation-artifacts/E1-S1-test.md"
  seed_initial_commit "$rel" "$(story_with_status 'ready-for-dev')"
  seed_initial_commit "README.md" "v1"
  modify_staged_file "$rel" "$(story_with_status 'in-progress')"
  modify_staged_file "README.md" "v2"
  rm -f "$STATUS_TRANSITION_MARKER"
  run "$DISCIPLINE_SH"
  [ "$status" -ne 0 ]
  [[ "$output" == *"$rel"* ]]
}

@test "Scenario 6: sprint-boundary exception — new sprint block → exit 0" {
  local rel="docs/implementation-artifacts/sprint-status.yaml"
  # No prior file — staging adds a brand new sprint block (boundary case)
  stage_file "$rel" "$(sprint_status_yaml_new_sprint)"
  rm -f "$STATUS_TRANSITION_MARKER"
  run "$DISCIPLINE_SH"
  [ "$status" -eq 0 ]
}

@test "Scenario 7: epics-and-stories.md status edit without marker → non-zero" {
  local rel="docs/planning-artifacts/epics-and-stories.md"
  seed_initial_commit "$rel" "$(epics_and_stories_md 'ready-for-dev')"
  modify_staged_file "$rel" "$(epics_and_stories_md 'in-progress')"
  rm -f "$STATUS_TRANSITION_MARKER"
  run "$DISCIPLINE_SH"
  [ "$status" -ne 0 ]
  [[ "$output" == *"$rel"* ]]
}

@test "Scenario 8: sprint-status.yaml mid-sprint edit without marker → non-zero" {
  local rel="docs/implementation-artifacts/sprint-status.yaml"
  seed_initial_commit "$rel" "$(sprint_status_yaml 'ready-for-dev')"
  modify_staged_file "$rel" "$(sprint_status_yaml 'in-progress')"
  rm -f "$STATUS_TRANSITION_MARKER"
  run "$DISCIPLINE_SH"
  [ "$status" -ne 0 ]
  [[ "$output" == *"$rel"* ]]
}

@test "Scenario 5: pre-commit hook integration — hook blocks commit on violation" {
  # Simulate husky hook chain by invoking the discipline script directly
  # in a subshell with a pre-commit-hook-style wrapper, then check exit status.
  local rel="docs/implementation-artifacts/E2-S2-hook.md"
  seed_initial_commit "$rel" "$(story_with_status 'ready-for-dev')"
  modify_staged_file "$rel" "$(story_with_status 'in-progress')"
  rm -f "$STATUS_TRANSITION_MARKER"

  # Build a hook script that mirrors `.husky/pre-commit`
  local hook="$TEST_PROJECT/.husky/pre-commit"
  mkdir -p "$(dirname "$hook")"
  cat > "$hook" <<EOF
#!/usr/bin/env bash
set -e
"$DISCIPLINE_SH"
EOF
  chmod +x "$hook"

  run "$hook"
  [ "$status" -ne 0 ]
}

@test "--staged-files override: synthetic file list works" {
  local rel="docs/implementation-artifacts/E3-S3-synthetic.md"
  local abs="$TEST_PROJECT/$rel"
  mkdir -p "$(dirname "$abs")"
  printf '%s' "$(story_with_status 'in-progress')" > "$abs"
  # Build a synthetic staged-diff file (the hunk format the script expects)
  local staged_list="$TEST_PROJECT/.staged.txt"
  printf '%s\n' "$rel" > "$staged_list"
  rm -f "$STATUS_TRANSITION_MARKER"

  # Provide a fake `git diff --cached` payload via STAGED_DIFF_FILE override
  local diff_payload="$TEST_PROJECT/.staged-diff.txt"
  cat > "$diff_payload" <<EOF
diff --git a/$rel b/$rel
--- a/$rel
+++ b/$rel
@@ -2,1 +2,1 @@
-status: ready-for-dev
+status: in-progress
EOF

  STAGED_DIFF_FILE="$diff_payload" run "$DISCIPLINE_SH" --staged-files "$staged_list"
  [ "$status" -ne 0 ]
  [[ "$output" == *"$rel"* ]]
}
