#!/usr/bin/env bats
# gaia-mobile-testing.bats — mobile-testing skill structural tests (E28-S88)
#
# Validates:
#   AC2: SKILL.md exists with valid YAML frontmatter and mobile testing content
#   AC5: setup.sh/finalize.sh follow shared pattern
#   AC6: Bats-core structural verification
#
# Usage:
#   bats tests/skills/gaia-mobile-testing.bats
#
# Dependencies: bats-core 1.10+

# ---------- Helpers ----------

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SKILLS_DIR="$REPO_ROOT/plugins/gaia/skills"
  SCRIPTS_DIR="$REPO_ROOT/plugins/gaia/scripts"
  SKILL_DIR="$SKILLS_DIR/gaia-mobile-testing"
  SKILL_FILE="$SKILL_DIR/SKILL.md"
  SETUP_SCRIPT="$SKILL_DIR/scripts/setup.sh"
  FINALIZE_SCRIPT="$SKILL_DIR/scripts/finalize.sh"
}

# ---------- AC2: SKILL.md exists with valid frontmatter ----------

@test "AC2: SKILL.md exists at gaia-mobile-testing skill directory" {
  [ -f "$SKILL_FILE" ]
}

@test "AC2: SKILL.md has YAML frontmatter delimiters" {
  head -1 "$SKILL_FILE" | grep -q "^---$"
  awk 'NR>1 && /^---$/{found=1; exit} END{exit !found}' "$SKILL_FILE"
}

@test "AC2: SKILL.md frontmatter contains name: gaia-mobile-testing" {
  awk '/^---$/{n++; next} n==1{print}' "$SKILL_FILE" | grep -q "^name: gaia-mobile-testing"
}

@test "AC2: SKILL.md frontmatter contains description field" {
  awk '/^---$/{n++; next} n==1{print}' "$SKILL_FILE" | grep -q "^description:"
}

@test "AC2: SKILL.md body contains device matrix section" {
  grep -qi "device.*matrix\|platform.*matrix\|target.*device" "$SKILL_FILE"
}

@test "AC2: SKILL.md body contains Appium section" {
  grep -qi "appium" "$SKILL_FILE"
}

@test "AC2: SKILL.md body contains responsive testing section" {
  grep -qi "responsive.*test\|viewport\|breakpoint" "$SKILL_FILE"
}

@test "AC2: SKILL.md body contains React Native or cross-platform section" {
  grep -qi "react.*native\|detox\|cross.*platform\|native.*testing" "$SKILL_FILE"
}

@test "AC2: SKILL.md body contains platform-specific checks section" {
  grep -qi "platform.*specific\|permission.*handling\|deep.*link\|push.*notification" "$SKILL_FILE"
}

@test "AC2: SKILL.md references mobile test plan output" {
  grep -q "mobile-test-plan\|test-artifacts" "$SKILL_FILE"
}

# ---------- AC5: Shared setup.sh/finalize.sh pattern ----------

@test "AC5: setup.sh exists and is executable" {
  [ -x "$SETUP_SCRIPT" ]
}

@test "AC5: finalize.sh exists and is executable" {
  [ -x "$FINALIZE_SCRIPT" ]
}

@test "AC5: setup.sh calls resolve-config.sh" {
  grep -q "resolve-config.sh" "$SETUP_SCRIPT"
}

@test "AC5: setup.sh calls validate-gate.sh" {
  grep -q "validate-gate.sh" "$SETUP_SCRIPT"
}

@test "AC5: setup.sh loads checkpoint" {
  grep -q "checkpoint" "$SETUP_SCRIPT"
}

@test "AC5: finalize.sh writes checkpoint" {
  grep -q "checkpoint" "$FINALIZE_SCRIPT"
}

@test "AC5: finalize.sh emits lifecycle event" {
  grep -q "lifecycle-event" "$FINALIZE_SCRIPT"
}

@test "AC5: SKILL.md invokes setup.sh at entry" {
  grep -q '!.*setup\.sh' "$SKILL_FILE"
}

@test "AC5: SKILL.md invokes finalize.sh at exit" {
  grep -q '!.*finalize\.sh' "$SKILL_FILE"
}

# ---------- AC6: Output format verification ----------

@test "AC6: SKILL.md references output to docs/test-artifacts/" {
  grep -q "docs/test-artifacts\|test-artifacts/" "$SKILL_FILE"
}

# ---------- Knowledge bundling (NFR-048) ----------

@test "NFR-048: knowledge directory contains react-native-testing.md" {
  [ -f "$SKILL_DIR/knowledge/react-native-testing.md" ]
}

@test "NFR-048: knowledge directory contains appium-patterns.md" {
  [ -f "$SKILL_DIR/knowledge/appium-patterns.md" ]
}

@test "NFR-048: knowledge directory contains responsive-testing.md" {
  [ -f "$SKILL_DIR/knowledge/responsive-testing.md" ]
}
