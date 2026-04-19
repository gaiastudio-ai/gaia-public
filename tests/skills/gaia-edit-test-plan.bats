#!/usr/bin/env bats
# gaia-edit-test-plan.bats — edit-test-plan skill structural tests (E28-S87)
#
# Validates:
#   AC2: SKILL.md exists with valid YAML frontmatter and expected sections
#   AC3: setup.sh calls resolve-config.sh, validate-gate.sh; finalize.sh writes checkpoint + lifecycle event
#   AC4: Bats-core structural verification
#
# Usage:
#   bats tests/skills/gaia-edit-test-plan.bats
#
# Dependencies: bats-core 1.10+

# ---------- Helpers ----------

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SKILLS_DIR="$REPO_ROOT/plugins/gaia/skills"
  SCRIPTS_DIR="$REPO_ROOT/plugins/gaia/scripts"
  SKILL_DIR="$SKILLS_DIR/gaia-edit-test-plan"
  SKILL_FILE="$SKILL_DIR/SKILL.md"
  SETUP_SCRIPT="$SKILL_DIR/scripts/setup.sh"
  FINALIZE_SCRIPT="$SKILL_DIR/scripts/finalize.sh"
}

# ---------- AC2: SKILL.md exists with valid frontmatter ----------

@test "AC2: SKILL.md exists at gaia-edit-test-plan skill directory" {
  [ -f "$SKILL_FILE" ]
}

@test "AC2: SKILL.md has YAML frontmatter delimiters" {
  head -1 "$SKILL_FILE" | grep -q "^---$"
  awk 'NR>1 && /^---$/{found=1; exit} END{exit !found}' "$SKILL_FILE"
}

@test "AC2: SKILL.md frontmatter contains name: gaia-edit-test-plan" {
  awk '/^---$/{n++; next} n==1{print}' "$SKILL_FILE" | grep -q "^name: gaia-edit-test-plan"
}

@test "AC2: SKILL.md frontmatter contains description field" {
  awk '/^---$/{n++; next} n==1{print}' "$SKILL_FILE" | grep -q "^description:"
}

@test "AC2: SKILL.md body references test-plan.md editing" {
  grep -qi "test-plan.md\|test plan" "$SKILL_FILE"
}

@test "AC2: SKILL.md body contains load existing test plan section" {
  grep -qi "load.*existing\|read.*test.*plan\|existing.*test.*plan" "$SKILL_FILE"
}

@test "AC2: SKILL.md body contains change scope section" {
  grep -qi "change.*scope\|identify.*change\|what.*test.*cases\|capture.*change" "$SKILL_FILE"
}

@test "AC2: SKILL.md body contains define new test cases section" {
  grep -qi "define.*test.*case\|new.*test.*case\|test.*case.*id" "$SKILL_FILE"
}

@test "AC2: SKILL.md body preserves existing content mandate" {
  grep -qi "preserve.*existing\|never.*remove\|no.*reordering\|existing.*content" "$SKILL_FILE"
}

@test "AC2: SKILL.md body contains version note section" {
  grep -qi "version.*note\|version.*history" "$SKILL_FILE"
}

@test "AC2: SKILL.md body references test-plan.md as output" {
  grep -q "test-plan.md" "$SKILL_FILE"
}

# ---------- AC3: Shared setup.sh/finalize.sh pattern ----------

@test "AC3: setup.sh exists and is executable" {
  [ -x "$SETUP_SCRIPT" ]
}

@test "AC3: finalize.sh exists and is executable" {
  [ -x "$FINALIZE_SCRIPT" ]
}

@test "AC3: setup.sh calls resolve-config.sh" {
  grep -q "resolve-config.sh" "$SETUP_SCRIPT"
}

@test "AC3: setup.sh calls validate-gate.sh" {
  grep -q "validate-gate.sh" "$SETUP_SCRIPT"
}

@test "AC3: setup.sh loads checkpoint" {
  grep -q "checkpoint" "$SETUP_SCRIPT"
}

@test "AC3: finalize.sh writes checkpoint" {
  grep -q "checkpoint" "$FINALIZE_SCRIPT"
}

@test "AC3: finalize.sh emits lifecycle event" {
  grep -q "lifecycle-event" "$FINALIZE_SCRIPT"
}

@test "AC3: SKILL.md invokes setup.sh at entry" {
  grep -q '!.*setup\.sh' "$SKILL_FILE"
}

@test "AC3: SKILL.md invokes finalize.sh at exit" {
  grep -q '!.*finalize\.sh' "$SKILL_FILE"
}

# ---------- AC4: Output format verification ----------

@test "AC4: SKILL.md references test-plan.md gate" {
  grep -qi "test-plan.md.*not found\|test-plan.md.*missing\|gaia-test-design" "$SKILL_FILE"
}
