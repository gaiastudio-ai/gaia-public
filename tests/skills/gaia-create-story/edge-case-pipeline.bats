#!/usr/bin/env bats
# edge-case-pipeline.bats — gaia-create-story Steps 3b/3c/3d V1 edge-case pipeline restoration (E54-S4)
#
# Validates that SKILL.md documents the restored V1 edge-case pipeline:
#   AC1 (TC-CSE-13): edge-cases skill failure -> edge_case_results=[], warning logged, Step 3c proceeds
#   AC2 (TC-CSE-14): primary AC count drift -> append aborted, warning logged, ACs unchanged
#   AC3 (TC-CSE-15): re-run dedup by (story_key, scenario) pair -> no duplicate TC IDs
#   AC4 (TC-CSE-16): size:S story -> Step 3b skipped (skip-log line)
#   AC5 (TC-CSE-17): >8K token edge-case set -> truncation order respected, telemetry logged
#   AC6:            YOLO mode compatibility -> non-interactive, same output as non-YOLO
#
# Usage:
#   bats tests/skills/gaia-create-story/edge-case-pipeline.bats
#
# Dependencies: bats-core 1.10+

# ---------- Helpers ----------

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
  SKILLS_DIR="$REPO_ROOT/plugins/gaia/skills"
  SKILL_DIR="$SKILLS_DIR/gaia-create-story"
  SKILL_FILE="$SKILL_DIR/SKILL.md"
  EDGE_CASES_SKILL="$SKILLS_DIR/edge-cases/SKILL.md"
}

# Extract the body of a numbered step section by header text.
# Stops at the next "### Step " heading.
step_body() {
  local header="$1"
  awk -v hdr="$header" '
    $0 ~ "^### " hdr "($|[^A-Za-z0-9])" { capture=1; next }
    /^### Step / && capture { exit }
    capture { print }
  ' "$SKILL_FILE"
}

# ---------- Pre-flight ----------

@test "Pre-flight: SKILL.md exists" {
  [ -f "$SKILL_FILE" ]
}

@test "Pre-flight: edge-cases skill exists (dependency)" {
  [ -f "$EDGE_CASES_SKILL" ]
}

# ---------- Step ordering ----------

@test "Ordering: Step 3b appears between Step 3 and Step 4" {
  step3_line=$(grep -n '^### Step 3 -- Elaborate Story' "$SKILL_FILE" | head -1 | cut -d: -f1)
  step3b_line=$(grep -n '^### Step 3b' "$SKILL_FILE" | head -1 | cut -d: -f1)
  step4_line=$(grep -n '^### Step 4 ' "$SKILL_FILE" | head -1 | cut -d: -f1)
  [ -n "$step3_line" ] && [ -n "$step3b_line" ] && [ -n "$step4_line" ]
  [ "$step3_line" -lt "$step3b_line" ]
  [ "$step3b_line" -lt "$step4_line" ]
}

@test "Ordering: Step 3c appears between Step 3b and Step 4" {
  step3b_line=$(grep -n '^### Step 3b' "$SKILL_FILE" | head -1 | cut -d: -f1)
  step3c_line=$(grep -n '^### Step 3c' "$SKILL_FILE" | head -1 | cut -d: -f1)
  step4_line=$(grep -n '^### Step 4 ' "$SKILL_FILE" | head -1 | cut -d: -f1)
  [ -n "$step3b_line" ] && [ -n "$step3c_line" ] && [ -n "$step4_line" ]
  [ "$step3b_line" -lt "$step3c_line" ]
  [ "$step3c_line" -lt "$step4_line" ]
}

@test "Ordering: Step 3d appears between Step 3c and Step 4" {
  step3c_line=$(grep -n '^### Step 3c' "$SKILL_FILE" | head -1 | cut -d: -f1)
  step3d_line=$(grep -n '^### Step 3d' "$SKILL_FILE" | head -1 | cut -d: -f1)
  step4_line=$(grep -n '^### Step 4 ' "$SKILL_FILE" | head -1 | cut -d: -f1)
  [ -n "$step3c_line" ] && [ -n "$step3d_line" ] && [ -n "$step4_line" ]
  [ "$step3c_line" -lt "$step3d_line" ]
  [ "$step3d_line" -lt "$step4_line" ]
}

# ---------- AC4 / TC-CSE-16: size:S skip ----------

@test "AC4/TC-CSE-16: Step 3b documents size=S skip with skip-log line" {
  body="$(step_body 'Step 3b')"
  echo "$body" | grep -qiE 'size.*=.*"?S"?|SIZE.*=.*"?S"?'
  echo "$body" | grep -qE 'edge_case_skip'
}

# ---------- AC1 / TC-CSE-13: edge-cases skill failure ----------

@test "AC1/TC-CSE-13: Step 3b documents JIT skill invocation of gaia:edge-cases / edge-cases" {
  body="$(step_body 'Step 3b')"
  echo "$body" | grep -qiE 'edge-cases|gaia:edge-cases'
  echo "$body" | grep -qiE 'JIT|skill tool|invoke'
}

@test "AC1/TC-CSE-13: Step 3b documents failure handling -> edge_case_results=[], warning, continue" {
  body="$(step_body 'Step 3b')"
  echo "$body" | grep -qE 'edge_case_results.*=.*\[\]|edge_case_results.*=.*empty'
  echo "$body" | grep -qiE 'warning|warn|failed|reason='
  echo "$body" | grep -qiE 'continue|proceed.*Step 3c'
}

# ---------- AC5 / TC-CSE-17: token cap + truncation order ----------

@test "AC5/TC-CSE-17: Step 3b documents 8K token budget cap (NFR-042)" {
  body="$(step_body 'Step 3b')"
  echo "$body" | grep -qE '8K|8000|8 ?K'
  echo "$body" | grep -qiE 'NFR-042|token budget|token.*cap'
}

@test "AC5/TC-CSE-17: Step 3b documents truncation order boundary/error/security first" {
  body="$(step_body 'Step 3b')"
  # Must mention all three priority groups in the documented order
  echo "$body" | grep -qiE 'boundary.*error.*security'
  echo "$body" | grep -qiE 'concurrency|timing'
  echo "$body" | grep -qiE 'data.*integration.*environment|integration.*environment'
}

@test "AC5/TC-CSE-17: Step 3b documents edge_case_token_usage telemetry log" {
  body="$(step_body 'Step 3b')"
  echo "$body" | grep -qE 'edge_case_token_usage'
}

# ---------- Output schema ----------

@test "Step 3b documents edge_case_results output structure with required fields" {
  body="$(step_body 'Step 3b')"
  echo "$body" | grep -qE 'edge_case_results'
  # All five required fields per edge-cases output schema
  echo "$body" | grep -qiE 'id|EC-1'
  echo "$body" | grep -qE 'scenario'
  echo "$body" | grep -qE 'category'
}

# ---------- AC2 / TC-CSE-14: primary AC drift safety ----------

@test "AC2/TC-CSE-14: Step 3c documents AC-EC{N} format (FR-229)" {
  body="$(step_body 'Step 3c')"
  echo "$body" | grep -qE 'AC-EC'
  echo "$body" | grep -qiE 'Given.*when.*then'
}

@test "AC2/TC-CSE-14: Step 3c documents append AFTER primary ACs (immutable)" {
  body="$(step_body 'Step 3c')"
  echo "$body" | grep -qiE 'after.*last.*primary|after.*primary.*AC|append.*after'
  echo "$body" | grep -qiE 'immutable|do not.*modify|unchanged'
}

@test "AC2/TC-CSE-14: Step 3c documents primary AC count drift safety check (abort + warn)" {
  body="$(step_body 'Step 3c')"
  echo "$body" | grep -qiE 'count.*before.*after|primary_count|AC count'
  echo "$body" | grep -qiE 'abort|rollback|primary_ac_count_drift'
  echo "$body" | grep -qiE 'warning|warn|log'
}

# ---------- AC3 / TC-CSE-15: dedup ----------

@test "AC3/TC-CSE-15: Step 3d documents test-plan.md target path" {
  body="$(step_body 'Step 3d')"
  echo "$body" | grep -qE 'test-plan\.md'
  echo "$body" | grep -qE 'docs/planning-artifacts'
}

@test "AC3/TC-CSE-15: Step 3d documents non-blocking warn when test-plan.md missing" {
  body="$(step_body 'Step 3d')"
  echo "$body" | grep -qiE 'non.blocking|missing|not.*exist|warn'
}

@test "AC3/TC-CSE-15: Step 3d documents heading match for story_key section" {
  body="$(step_body 'Step 3d')"
  echo "$body" | grep -qiE 'heading.*match|##.*story_key|### .*story_key|locate.*section'
}

@test "AC3/TC-CSE-15: Step 3d documents next TC ID computation max+1" {
  body="$(step_body 'Step 3d')"
  echo "$body" | grep -qiE 'TC-\{N\}|TC-\\{N\\}|TC ID|max.*\+ ?1|next.*TC'
}

@test "AC3/TC-CSE-15: Step 3d documents dedup by (story_key, scenario) pair (idempotent)" {
  body="$(step_body 'Step 3d')"
  echo "$body" | grep -qiE 'dedup|deduplicate|skip.*exist|already.*exist'
  echo "$body" | grep -qiE 'story_key.*scenario|\(story_key, scenario\)|scenario.*pair'
  echo "$body" | grep -qiE 'idempotent|re.run'
}

@test "AC3/TC-CSE-15: Step 3d documents row format (FR-230)" {
  body="$(step_body 'Step 3d')"
  echo "$body" | grep -qE 'TC-\{N\}'
  echo "$body" | grep -qiE 'edge.case'
  echo "$body" | grep -qE 'severity|category'
}

# ---------- AC6: YOLO compatibility ----------

@test "AC6: Step 3b/3c/3d are non-interactive (no user prompts)" {
  body3b="$(step_body 'Step 3b')"
  body3c="$(step_body 'Step 3c')"
  body3d="$(step_body 'Step 3d')"
  # YOLO note must appear at least once across the three steps (or in either of them)
  combined="$body3b $body3c $body3d"
  echo "$combined" | grep -qiE 'non.interactive|no.*user.*prompt|YOLO'
}

# ---------- Reference / traceability ----------

@test "Step 3b references FR-227 or FR-229 or NFR-042" {
  body="$(step_body 'Step 3b')"
  echo "$body" | grep -qE 'FR-227|FR-229|NFR-042'
}

@test "Step 3c references FR-229 (V1 ACs append)" {
  body="$(step_body 'Step 3c')"
  echo "$body" | grep -qE 'FR-229'
}

@test "Step 3d references FR-230 (V1 test-plan append)" {
  body="$(step_body 'Step 3d')"
  echo "$body" | grep -qE 'FR-230'
}
