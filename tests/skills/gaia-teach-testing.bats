#!/usr/bin/env bats
# gaia-teach-testing.bats — teach-testing skill structural tests (E28-S89)
#
# Validates:
#   AC1: SKILL.md exists with valid YAML frontmatter and lesson generation logic
#   AC2: SKILL.md contains progressive skill-level branching (beginner/intermediate/expert)
#   AC3: setup.sh calls resolve-config.sh, validate-gate.sh; finalize.sh writes checkpoint + lifecycle event
#   AC4: Bats-core structural verification
#
# Usage:
#   bats tests/skills/gaia-teach-testing.bats
#
# Dependencies: bats-core 1.10+

# ---------- Helpers ----------

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SKILLS_DIR="$REPO_ROOT/plugins/gaia/skills"
  SCRIPTS_DIR="$REPO_ROOT/plugins/gaia/scripts"
  SKILL_DIR="$SKILLS_DIR/gaia-teach-testing"
  SKILL_FILE="$SKILL_DIR/SKILL.md"
  SETUP_SCRIPT="$SKILL_DIR/scripts/setup.sh"
  FINALIZE_SCRIPT="$SKILL_DIR/scripts/finalize.sh"
}

# ---------- AC1: SKILL.md exists with valid frontmatter ----------

@test "AC1: SKILL.md exists at gaia-teach-testing skill directory" {
  [ -f "$SKILL_FILE" ]
}

@test "AC1: SKILL.md has YAML frontmatter delimiters" {
  head -1 "$SKILL_FILE" | grep -q "^---$"
  awk 'NR>1 && /^---$/{found=1; exit} END{exit !found}' "$SKILL_FILE"
}

@test "AC1: SKILL.md frontmatter contains name: gaia-teach-testing" {
  awk '/^---$/{n++; next} n==1{print}' "$SKILL_FILE" | grep -q "^name: gaia-teach-testing"
}

@test "AC1: SKILL.md frontmatter contains description field" {
  awk '/^---$/{n++; next} n==1{print}' "$SKILL_FILE" | grep -q "^description:"
}

@test "AC1: SKILL.md body contains lesson generation logic" {
  grep -qi "lesson\|session\|teach\|learn" "$SKILL_FILE"
}

@test "AC1: SKILL.md body contains skill level assessment" {
  grep -qi "assess.*level\|skill.*level\|experience" "$SKILL_FILE"
}

# ---------- AC2: Progressive skill-level branching ----------

@test "AC2: SKILL.md contains beginner-level content" {
  grep -qi "beginner" "$SKILL_FILE"
  grep -qi "unit.*test\|test.*basics\|assertions\|AAA.*pattern\|test.*pyramid" "$SKILL_FILE"
}

@test "AC2: SKILL.md contains intermediate-level content" {
  grep -qi "intermediate" "$SKILL_FILE"
  grep -qi "mock\|integration.*test\|test.*double\|coverage\|fixture" "$SKILL_FILE"
}

@test "AC2: SKILL.md contains expert-level content" {
  grep -qi "expert\|advanced" "$SKILL_FILE"
  grep -qi "property.based\|mutation.*test\|test.*architecture\|contract.*test" "$SKILL_FILE"
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

@test "AC4: SKILL.md contains structured lesson format" {
  grep -qi "objective\|concept\|example\|exercise\|summary" "$SKILL_FILE"
}

@test "AC4: SKILL.md contains step structure" {
  grep -q "^### Step" "$SKILL_FILE"
}
