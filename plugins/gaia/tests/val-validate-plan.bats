#!/usr/bin/env bats
# val-validate-plan.bats — unit tests for gaia-val-validate-plan skill (E28-S77)
#
# Covers: SKILL.md frontmatter validation, setup.sh/finalize.sh contract,
# memory-loader.sh ground-truth integration, edge cases (AC-EC1..AC-EC7).
#
# Refs: E28-S77, FR-323, FR-330, FR-331, ADR-041, ADR-045, ADR-046

load 'test_helper.bash'

SKILL_DIR=""
SKILL_MD=""

setup() {
  common_setup
  SKILL_DIR="$BATS_TEST_DIRNAME/../skills/gaia-val-validate-plan"
  SKILL_MD="$SKILL_DIR/SKILL.md"
  export MEMORY_PATH="$TEST_TMP/_memory"
  mkdir -p "$MEMORY_PATH"
}
teardown() { common_teardown; }

# ---------- AC1: SKILL.md exists with context: fork frontmatter ----------

@test "val-validate-plan: SKILL.md exists" {
  [ -f "$SKILL_MD" ]
}

@test "val-validate-plan: SKILL.md frontmatter declares context: fork" {
  run head -20 "$SKILL_MD"
  [ "$status" -eq 0 ]
  [[ "$output" == *"context: fork"* ]]
}

@test "val-validate-plan: SKILL.md frontmatter declares name: gaia-val-validate-plan" {
  run head -10 "$SKILL_MD"
  [ "$status" -eq 0 ]
  [[ "$output" == *"name: gaia-val-validate-plan"* ]]
}

# ---------- AC2: memory-loader.sh loads ground-truth for validator ----------

@test "val-validate-plan: SKILL.md references memory-loader.sh" {
  run grep -c "memory-loader.sh" "$SKILL_MD"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "val-validate-plan: memory-loader.sh loads validator ground-truth" {
  mkdir -p "$MEMORY_PATH/validator-sidecar"
  printf 'GROUND-TRUTH-CONTENT\n' > "$MEMORY_PATH/validator-sidecar/ground-truth.md"
  run "$SCRIPTS_DIR/memory-loader.sh" validator ground-truth
  [ "$status" -eq 0 ]
  [[ "$output" == *"GROUND-TRUTH-CONTENT"* ]]
}

# ---------- AC3: Findings use CRITICAL/WARNING/INFO severities ----------

@test "val-validate-plan: SKILL.md body mentions CRITICAL severity" {
  run grep -c "CRITICAL" "$SKILL_MD"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "val-validate-plan: SKILL.md body mentions WARNING severity" {
  run grep -c "WARNING" "$SKILL_MD"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "val-validate-plan: SKILL.md body mentions INFO severity" {
  run grep -c "INFO" "$SKILL_MD"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

# ---------- AC4: setup.sh/finalize.sh follow shared pattern ----------

@test "val-validate-plan: setup.sh exists and is executable" {
  [ -x "$SKILL_DIR/scripts/setup.sh" ]
}

@test "val-validate-plan: finalize.sh exists and is executable" {
  [ -x "$SKILL_DIR/scripts/finalize.sh" ]
}

@test "val-validate-plan: setup.sh references resolve-config.sh" {
  run grep -c "resolve-config.sh" "$SKILL_DIR/scripts/setup.sh"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "val-validate-plan: finalize.sh references checkpoint.sh" {
  run grep -c "checkpoint.sh" "$SKILL_DIR/scripts/finalize.sh"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

# ---------- AC5: bats test verifies ground-truth via memory-loader.sh in fork ----------

@test "val-validate-plan: validator receives ground-truth via memory-loader.sh in forked context" {
  # Simulate the forked context: memory-loader.sh loads ground-truth for validator
  mkdir -p "$MEMORY_PATH/validator-sidecar"
  printf '## Ground Truth\n\nValidator ground truth data.\n' > "$MEMORY_PATH/validator-sidecar/ground-truth.md"
  printf '## Decision Log\n\nSome decisions.\n' > "$MEMORY_PATH/validator-sidecar/decision-log.md"

  # Path 2 (ADR-046): memory-loader.sh loads all memory for validator
  run "$SCRIPTS_DIR/memory-loader.sh" validator all
  [ "$status" -eq 0 ]
  [[ "$output" == *"Ground Truth"* ]]
  [[ "$output" == *"Validator ground truth data"* ]]
  [[ "$output" == *"Decision Log"* ]]
}

# ---------- AC-EC1: missing ground-truth.md → graceful empty ----------

@test "val-validate-plan: AC-EC1 missing ground-truth.md → empty output, exit 0" {
  mkdir -p "$MEMORY_PATH/validator-sidecar"
  # No ground-truth.md file
  run "$SCRIPTS_DIR/memory-loader.sh" validator ground-truth
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# ---------- AC-EC2: empty plan → handled in SKILL.md ----------

@test "val-validate-plan: AC-EC2 SKILL.md documents empty plan handling" {
  run grep -c "no steps to validate" "$SKILL_MD"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

# ---------- AC-EC3: nonexistent file references → documented ----------

@test "val-validate-plan: AC-EC3 SKILL.md documents file-not-found handling" {
  run grep -c "does not exist" "$SKILL_MD"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

# ---------- AC-EC5: oversized ground-truth → truncation ----------

@test "val-validate-plan: AC-EC5 memory-loader.sh truncates oversized ground-truth" {
  mkdir -p "$MEMORY_PATH/validator-sidecar"
  # Create a large ground-truth file (10000 chars)
  python3 -c "print('X' * 10000)" > "$MEMORY_PATH/validator-sidecar/ground-truth.md"
  # Request max 100 tokens (approx 400 chars at 4 chars/token)
  run "$SCRIPTS_DIR/memory-loader.sh" validator ground-truth --max-tokens 100
  [ "$status" -eq 0 ]
  # Output should be truncated to ~400 chars
  [ "${#output}" -le 500 ]
}

# ---------- AC-EC6: setup.sh exit on missing resolve-config.sh ----------

@test "val-validate-plan: AC-EC6 setup.sh fails when resolve-config.sh missing" {
  # Run setup.sh in an environment where resolve-config.sh doesn't exist
  # by overriding the plugin scripts path
  local tmp_scripts="$TEST_TMP/fake-scripts"
  mkdir -p "$tmp_scripts"
  # Copy setup.sh but point to nonexistent resolve-config.sh
  cp "$SKILL_DIR/scripts/setup.sh" "$tmp_scripts/setup.sh"
  chmod +x "$tmp_scripts/setup.sh"
  # Replace the PLUGIN_SCRIPTS_DIR resolution to point to empty dir
  run env PLUGIN_SCRIPTS_DIR_OVERRIDE="$TEST_TMP/nonexistent" "$tmp_scripts/setup.sh"
  [ "$status" -ne 0 ]
}

# ---------- AC-EC7: plan with prior findings ----------

@test "val-validate-plan: AC-EC7 SKILL.md documents prior-findings exclusion" {
  run grep -c "prior findings" "$SKILL_MD"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

# ---------- AC-EC4: subagent not registered ----------

@test "val-validate-plan: AC-EC4 SKILL.md documents subagent registration failure" {
  run grep -c "not registered" "$SKILL_MD"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}
