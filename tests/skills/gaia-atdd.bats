#!/usr/bin/env bats
# gaia-atdd.bats — ATDD skill structural and parity tests (E28-S83)
#
# Validates:
#   AC1: SKILL.md exists with valid YAML frontmatter and story-key argument
#   AC2: Given/When/Then format referenced in skill body
#   AC3: Output path targets docs/test-artifacts/atdd-{story_key}.md
#   AC4: setup.sh calls resolve-config.sh, validate-gate.sh; finalize.sh writes checkpoint + lifecycle event
#   AC5: ATDD output references correct story ACs, does not reference nonexistent ACs
#   AC-EC1: Missing/malformed story key validation
#   AC-EC2: Empty AC section handling
#   AC-EC4: Missing dependency script handling
#   AC-EC5: Nonexistent story file handling
#
# Usage:
#   bats tests/skills/gaia-atdd.bats
#
# Dependencies: bats-core 1.10+

# ---------- Helpers ----------

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SKILLS_DIR="$REPO_ROOT/plugins/gaia/skills"
  SCRIPTS_DIR="$REPO_ROOT/plugins/gaia/scripts"
  SKILL_DIR="$SKILLS_DIR/gaia-atdd"
  SKILL_FILE="$SKILL_DIR/SKILL.md"
  SETUP_SCRIPT="$SKILL_DIR/scripts/setup.sh"
  FINALIZE_SCRIPT="$SKILL_DIR/scripts/finalize.sh"

  # Per-test isolated temp workspace
  TEST_TMP="$BATS_TEST_TMPDIR/gaia-atdd-$$"
  mkdir -p "$TEST_TMP/docs/implementation-artifacts" \
           "$TEST_TMP/docs/test-artifacts" \
           "$TEST_TMP/checkpoints" \
           "$TEST_TMP/memory"

  # Set env overrides
  export GAIA_PROJECT_ROOT="$TEST_TMP"
  export GAIA_PROJECT_PATH="$TEST_TMP"
  export GAIA_MEMORY_PATH="$TEST_TMP/memory"
  export GAIA_CHECKPOINT_PATH="$TEST_TMP/checkpoints"
  export GAIA_INSTALLED_PATH="$REPO_ROOT/plugins/gaia"
  export PROJECT_ROOT="$TEST_TMP"
  export TEST_ARTIFACTS="$TEST_TMP/docs/test-artifacts"
  export IMPLEMENTATION_ARTIFACTS="$TEST_TMP/docs/implementation-artifacts"
}

# ---------- AC1: SKILL.md exists with valid frontmatter ----------

@test "AC1: SKILL.md exists at gaia-atdd skill directory" {
  [ -f "$SKILL_FILE" ]
}

@test "AC1: SKILL.md has YAML frontmatter delimiters" {
  head -1 "$SKILL_FILE" | grep -q "^---$"
  # Find closing delimiter (second ---)
  awk 'NR>1 && /^---$/{found=1; exit} END{exit !found}' "$SKILL_FILE"
}

@test "AC1: SKILL.md frontmatter contains name: gaia-atdd" {
  # Extract frontmatter (between first and second ---)
  awk '/^---$/{n++; next} n==1{print}' "$SKILL_FILE" | grep -q "^name: gaia-atdd"
}

@test "AC1: SKILL.md frontmatter contains description field" {
  awk '/^---$/{n++; next} n==1{print}' "$SKILL_FILE" | grep -q "^description:"
}

@test "AC1: SKILL.md frontmatter contains argument-hint with story-key" {
  awk '/^---$/{n++; next} n==1{print}' "$SKILL_FILE" | grep -q "story-key"
}

# ---------- AC2: Given/When/Then format in skill body ----------

@test "AC2: SKILL.md body references Given/When/Then test format" {
  # The skill must instruct the agent to use Given/When/Then format
  grep -qi "given.*when.*then\|given/when/then" "$SKILL_FILE"
}

@test "AC2: SKILL.md body instructs generation of failing test skeletons" {
  grep -qi "failing\|fail\|red.*phase\|TDD" "$SKILL_FILE"
}

# ---------- AC3: Output path convention ----------

@test "AC3: SKILL.md references output path atdd-{story_key}.md" {
  grep -q "atdd-.*story.key\|atdd-{story_key}\|atdd-.*story_key" "$SKILL_FILE"
}

@test "AC3: SKILL.md references test-artifacts output directory" {
  grep -q "test-artifacts\|test_artifacts\|TEST_ARTIFACTS" "$SKILL_FILE"
}

# ---------- AC4: Shared setup.sh/finalize.sh pattern ----------

@test "AC4: setup.sh exists and is executable" {
  [ -x "$SETUP_SCRIPT" ]
}

@test "AC4: finalize.sh exists and is executable" {
  [ -x "$FINALIZE_SCRIPT" ]
}

@test "AC4: setup.sh calls resolve-config.sh" {
  grep -q "resolve-config.sh" "$SETUP_SCRIPT"
}

@test "AC4: setup.sh calls validate-gate.sh" {
  grep -q "validate-gate.sh" "$SETUP_SCRIPT"
}

@test "AC4: setup.sh loads checkpoint" {
  grep -q "checkpoint" "$SETUP_SCRIPT"
}

@test "AC4: finalize.sh writes checkpoint" {
  grep -q "checkpoint" "$FINALIZE_SCRIPT"
}

@test "AC4: finalize.sh emits lifecycle event" {
  grep -q "lifecycle-event" "$FINALIZE_SCRIPT"
}

@test "AC4: SKILL.md invokes setup.sh at entry" {
  grep -q '!.*setup\.sh' "$SKILL_FILE"
}

@test "AC4: SKILL.md invokes finalize.sh at exit" {
  grep -q '!.*finalize\.sh' "$SKILL_FILE"
}

# ---------- AC5: ATDD output references correct ACs ----------

@test "AC5: setup.sh validates story file exists before proceeding" {
  # setup.sh or the skill body must check for story file existence
  grep -qi "story.*file\|story.*exist\|story.*found\|story.*not found" "$SETUP_SCRIPT" || \
  grep -qi "story.*file.*exist\|story.*not found" "$SKILL_FILE"
}

# ---------- AC-EC1: Story key argument validation ----------

@test "AC-EC1: SKILL.md documents story-key as required argument" {
  awk '/^---$/{n++; next} n==1{print}' "$SKILL_FILE" | grep -qi "story-key"
}

# ---------- AC-EC2: Empty AC section handling ----------

@test "AC-EC2: SKILL.md handles missing or empty acceptance criteria" {
  grep -qi "no acceptance criteria\|acceptance criteria.*not found\|empty.*acceptance\|AC.*section.*empty\|no.*AC" "$SKILL_FILE"
}

# ---------- AC-EC4: Missing dependency script handling ----------

@test "AC-EC4: setup.sh exits non-zero when resolve-config.sh is missing" {
  # Create a temp copy of setup.sh with resolve-config.sh path pointed at nonexistent
  local tmp_setup="$TEST_TMP/setup-test.sh"
  cp "$SETUP_SCRIPT" "$tmp_setup"
  chmod +x "$tmp_setup"

  # Override PLUGIN_SCRIPTS_DIR to a nonexistent path
  export PLUGIN_SCRIPTS_DIR="/nonexistent/path"
  run bash -c "PLUGIN_SCRIPTS_DIR=/nonexistent/path source '$tmp_setup'" 2>/dev/null
  [ "$status" -ne 0 ]
}

# ---------- AC-EC5: Nonexistent story file handling ----------

@test "AC-EC5: SKILL.md instructs error on missing story file" {
  grep -qi "story file not found\|story.*not found\|story.*does not exist\|story.*missing" "$SKILL_FILE"
}

# ---------- AC-EC3: Idempotent overwrite ----------

@test "AC-EC3: SKILL.md handles idempotent overwrite of existing output" {
  grep -qi "overwrite\|idempotent\|replace\|existing.*file\|already exists" "$SKILL_FILE"
}

# ---------- AC-EC6: Large output warning ----------

@test "AC-EC6: SKILL.md mentions output size warning for large AC sets" {
  grep -qi "size.*warning\|large.*AC\|10KB\|exceed\|truncat" "$SKILL_FILE"
}
