#!/usr/bin/env bats
# gaia-release-plan.bats — release plan skill structural tests (E28-S93)
#
# Validates:
#   AC1: SKILL.md produces staged rollout plan with environment progression
#   AC2: SKILL.md includes rollback criteria and success metrics
#   AC3: Shared setup.sh/finalize.sh pattern applied
#   AC4: Structural verification of release plan output format
#
# Usage:
#   bats tests/skills/gaia-release-plan.bats
#
# Dependencies: bats-core 1.10+

# ---------- Helpers ----------

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SKILLS_DIR="$REPO_ROOT/plugins/gaia/skills"
  SCRIPTS_DIR="$REPO_ROOT/plugins/gaia/scripts"
  SKILL_DIR="$SKILLS_DIR/gaia-release-plan"
  SKILL_FILE="$SKILL_DIR/SKILL.md"
  SETUP_SCRIPT="$SKILL_DIR/scripts/setup.sh"
  FINALIZE_SCRIPT="$SKILL_DIR/scripts/finalize.sh"
}

# ---------- AC1: SKILL.md exists with valid frontmatter and release plan content ----------

@test "AC1: SKILL.md exists at gaia-release-plan skill directory" {
  [ -f "$SKILL_FILE" ]
}

@test "AC1: SKILL.md has YAML frontmatter delimiters" {
  head -1 "$SKILL_FILE" | grep -q "^---$"
  awk 'NR>1 && /^---$/{found=1; exit} END{exit !found}' "$SKILL_FILE"
}

@test "AC1: SKILL.md frontmatter contains name: gaia-release-plan" {
  awk '/^---$/{n++; next} n==1{print}' "$SKILL_FILE" | grep -q "^name: gaia-release-plan"
}

@test "AC1: SKILL.md frontmatter contains description field" {
  awk '/^---$/{n++; next} n==1{print}' "$SKILL_FILE" | grep -q "^description:"
}

@test "AC1: SKILL.md contains staged rollout section" {
  grep -qi "staged.*rollout\|rollout.*stage\|rollout.*plan" "$SKILL_FILE"
}

@test "AC1: SKILL.md contains environment progression" {
  grep -qi "environment.*progression\|percentage.*target\|1%.*10%.*50%.*100%\|canary\|rolling\|blue.green" "$SKILL_FILE"
}

@test "AC1: SKILL.md contains deployment strategy selection" {
  grep -qi "deployment.*strategy\|blue.green\|canary\|rolling\|big.bang" "$SKILL_FILE"
}

# ---------- AC2: Rollback criteria and success metrics ----------

@test "AC2: SKILL.md contains rollback criteria" {
  grep -qi "rollback.*criteria\|rollback.*trigger\|abort.*criteria" "$SKILL_FILE"
}

@test "AC2: SKILL.md contains success metrics" {
  grep -qi "success.*metric\|success.*criteria\|observation.*window\|metric.*monitor" "$SKILL_FILE"
}

@test "AC2: SKILL.md contains release scope section" {
  grep -qi "release.*scope\|what.*included\|version.*number\|semantic.*version" "$SKILL_FILE"
}

@test "AC2: SKILL.md contains communication plan" {
  grep -qi "communication.*plan\|stakeholder.*notification\|changelog\|release.*notes" "$SKILL_FILE"
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

@test "AC4: SKILL.md references output file path with release-plan naming" {
  grep -qi "release-plan\|release.*plan.*\.md" "$SKILL_FILE"
}

@test "AC4: SKILL.md references architecture.md as input" {
  grep -qi "architecture\.md" "$SKILL_FILE"
}

@test "AC4: SKILL.md contains version assignment guidance" {
  grep -qi "version.*number\|semantic.*version\|semver" "$SKILL_FILE"
}

@test "AC4: SKILL.md contains monitoring metrics per stage" {
  grep -qi "monitor\|metric\|observe" "$SKILL_FILE"
}

@test "AC4: SKILL.md contains abort criteria per stage" {
  grep -qi "abort\|halt\|stop.*rollout\|rollback.*trigger" "$SKILL_FILE"
}
