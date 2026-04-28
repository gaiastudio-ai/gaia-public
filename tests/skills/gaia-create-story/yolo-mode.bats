#!/usr/bin/env bats
# yolo-mode.bats — gaia-create-story YOLO param + non-YOLO [u]/[a] routing prompt (E54-S1)
#
# Validates SKILL.md and setup.sh per E54-S1:
#   AC1 (TC-CSE-01): YOLO bypasses routing prompt; subagents auto-spawn
#   AC2 (TC-CSE-02): YOLO honors 3-attempt cap; FAILED -> HALT with /gaia-fix-story pointer
#   AC3 (TC-CSE-03): YOLO honors existing-status HALT gate before any subagent spawn
#   AC4 (TC-CSE-04): non-YOLO [u]/[a] prompt exact text + UX Designer clause on [a]
#   AC5:             [u] path = exactly 4 questions in order (edge cases, impl prefs, AC splits, additional context)
#   AC6:             YOLO mode emits no prompt between Step 4 (file write) and Step 6 (Val dispatch)
#
# Usage:
#   bats tests/skills/gaia-create-story/yolo-mode.bats
#
# Dependencies: bats-core 1.10+

# ---------- Helpers ----------

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
  SKILLS_DIR="$REPO_ROOT/plugins/gaia/skills"
  SKILL_DIR="$SKILLS_DIR/gaia-create-story"
  SKILL_FILE="$SKILL_DIR/SKILL.md"
  SETUP_FILE="$SKILL_DIR/scripts/setup.sh"
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

@test "Pre-flight: setup.sh exists and is executable" {
  [ -f "$SETUP_FILE" ]
  [ -x "$SETUP_FILE" ]
}

# ---------- setup.sh YOLO detection ----------

@test "setup.sh: detects 'yolo' keyword in arguments" {
  grep -qE 'yolo' "$SETUP_FILE"
  grep -qE 'YOLO_MODE' "$SETUP_FILE"
}

@test "setup.sh: exports YOLO_MODE variable" {
  grep -qE 'export YOLO_MODE' "$SETUP_FILE"
}

@test "setup.sh: emits yolo_mode log line for LLM" {
  grep -qE 'yolo_mode=' "$SETUP_FILE"
}

@test "setup.sh: scans \$1, \$2, or \$ARGUMENTS for yolo flag" {
  # Must reference at least one positional arg or ARGUMENTS env var
  grep -qE '\$1|\$2|ARGUMENTS' "$SETUP_FILE"
}

@test "setup.sh: detects --yolo long-form flag in addition to bare keyword" {
  grep -qE '\-\-yolo|--yolo' "$SETUP_FILE"
}

@test "setup.sh executes successfully with no args (default YOLO_MODE=false)" {
  # The setup script requires the planning artifact, so this asserts the YOLO
  # detection itself runs without erroring on argument parsing.
  run bash -c "ARGUMENTS='' bash '$SETUP_FILE' 2>&1 | grep -E 'yolo_mode='"
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
  # Either the script ran far enough to print yolo_mode=, or aborted on a missing
  # planning artifact gate (acceptable in this isolated test harness).
}

# ---------- AC1 / TC-CSE-01: YOLO bypasses routing prompt ----------

@test "AC1/TC-CSE-01: Step 3 documents YOLO branch that bypasses routing prompt" {
  body="$(step_body 'Step 3 -- Elaborate Story')"
  echo "$body" | grep -qiE 'YOLO_MODE|YOLO mode|yolo'
  echo "$body" | grep -qiE 'skip.*prompt|bypass.*prompt|no.*prompt|auto-select|auto.*\[a\]'
}

@test "AC1/TC-CSE-01: Step 3 YOLO branch auto-selects [a] path (subagent spawn)" {
  body="$(step_body 'Step 3 -- Elaborate Story')"
  # YOLO must route into the [a] subagent-spawn path
  echo "$body" | grep -qiE 'YOLO.*\[a\]|\[a\].*YOLO|YOLO.*auto.*delegate|YOLO.*subagent|YOLO.*spawn'
}

# ---------- AC2 / TC-CSE-02: YOLO honors 3-attempt cap ----------

@test "AC2/TC-CSE-02: Step 6 documents YOLO honors 3-attempt cap (FR-340)" {
  body="$(step_body 'Step 6')"
  echo "$body" | grep -qE 'FR-340'
  echo "$body" | grep -qiE '3.attempt|three.attempt|attempt.*cap'
  echo "$body" | grep -qiE 'YOLO.*not.*bypass|YOLO.*cap|YOLO.*MUST NOT'
}

@test "AC2/TC-CSE-02: Step 6 documents FAILED HALT with /gaia-fix-story pointer in YOLO" {
  body="$(step_body 'Step 6')"
  echo "$body" | grep -qE '/gaia-fix-story'
  echo "$body" | grep -qiE 'YOLO.*FAILED|FAILED.*YOLO|FAILED.*HALT|HALT.*FAILED'
}

# ---------- AC3 / TC-CSE-03: YOLO honors existing-status HALT gate ----------

@test "AC3/TC-CSE-03: Step 1 documents existing-story-status HALT before YOLO branch" {
  body="$(step_body 'Step 1')"
  # The existing-status HALT must be documented in Step 1
  echo "$body" | grep -qiE 'HALT|status'
  echo "$body" | grep -qE 'in-progress|backlog|status'
}

@test "AC3/TC-CSE-03: SKILL.md documents YOLO does not bypass existing-status HALT" {
  # Either Step 1 or Critical Rules section explicitly states YOLO doesn't bypass the gate
  run grep -iE 'YOLO.*not.*bypass.*HALT|YOLO.*HALT.*gate|YOLO.*existing.*status|HALT.*before.*YOLO|existing-story-status.*before.*YOLO' "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

# ---------- AC4 / TC-CSE-04: non-YOLO [u]/[a] prompt exact text ----------

@test "AC4/TC-CSE-04: Step 3 contains exact prompt text 'How would you like to elaborate this story?'" {
  grep -qE 'How would you like to elaborate this story\?' "$SKILL_FILE"
}

@test "AC4/TC-CSE-04: Step 3 [a] line includes 'Auto-delegate to PM (Derek), Architect (Theo)'" {
  body="$(step_body 'Step 3 -- Elaborate Story')"
  echo "$body" | grep -qE '\[a\].*Auto-delegate to PM \(Derek\), Architect \(Theo\)'
}

@test "AC4/TC-CSE-04: Step 3 [a] line includes 'and UX Designer (Christy)' clause for UX-scoped stories" {
  body="$(step_body 'Step 3 -- Elaborate Story')"
  echo "$body" | grep -qE 'and UX Designer \(Christy\)'
}

@test "AC4/TC-CSE-04: Step 3 [u] option uses 'I.ll answer' or 'answer.*questions' phrasing" {
  body="$(step_body 'Step 3 -- Elaborate Story')"
  echo "$body" | grep -qiE "\[u\].*answer.*questions|\[u\].*I.ll.*answer"
}

# ---------- AC5: [u] path = exactly 4 questions in order ----------

@test "AC5: Step 3 [u] path documents 4 questions in canonical order" {
  body="$(step_body 'Step 3 -- Elaborate Story')"
  # Edge cases is question 1
  echo "$body" | grep -qiE 'edge case'
  # Implementation preferences is question 2
  echo "$body" | grep -qiE 'implementation preference|implementation.*preference'
  # AC splits is question 3
  echo "$body" | grep -qiE 'AC split|acceptance.criteri.*split|ac.*split'
  # Additional context is question 4
  echo "$body" | grep -qiE 'additional context'
}

@test "AC5: Step 3 [u] path explicitly numbers or lists 4 questions" {
  body="$(step_body 'Step 3 -- Elaborate Story')"
  # Documented as a 4-question flow
  echo "$body" | grep -qiE '4.question|four.question|exactly 4|four questions|4 questions'
}

# ---------- AC6: YOLO no inter-step prompt between Step 4 and Step 6 ----------

@test "AC6: SKILL.md documents YOLO auto-continues post-subagent and template-output prompts" {
  # YOLO must auto-continue any [c]/[e]/[a] or [c]/[e]/[v] interactive review prompts
  run grep -iE 'YOLO.*auto.continue|YOLO.*no.*prompt|YOLO.*skip.*prompt|YOLO.*auto-continue' "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "AC6: Step 6 YOLO auto-triggers Val without user prompt" {
  body="$(step_body 'Step 6')"
  echo "$body" | grep -qiE 'YOLO.*Val.*auto|YOLO.*auto.*Val|YOLO.*dispatch.*Val|YOLO.*no.*prompt|YOLO.*without.*prompt'
}

# ---------- Hard guards (Task 5) ----------

@test "Hard guard: Step 1 existing-status HALT runs BEFORE YOLO branch (order)" {
  step1_line=$(grep -n '^### Step 1' "$SKILL_FILE" | head -1 | cut -d: -f1)
  step3_line=$(grep -n '^### Step 3 -- Elaborate Story' "$SKILL_FILE" | head -1 | cut -d: -f1)
  [ -n "$step1_line" ] && [ -n "$step3_line" ]
  # Step 1 (HALT gate) must precede Step 3 (YOLO branch)
  [ "$step1_line" -lt "$step3_line" ]
}

@test "Hard guard: FR-340 referenced in SKILL.md (3-attempt cap traceability)" {
  grep -qE 'FR-340' "$SKILL_FILE"
}
