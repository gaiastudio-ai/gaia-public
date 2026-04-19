#!/usr/bin/env bats
# check-dod-parity.bats — Cluster 7 check-dod skill parity test (E28-S56)
#
# Validates the gaia-check-dod skill directory, scripts, frontmatter,
# and review-gate.sh integration for DoD checking.
#
# Usage:
#   bats tests/cluster-7-parity/check-dod-parity.bats
#
# Dependencies: bats-core 1.10+

# ---------- Helpers ----------

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SKILLS_DIR="$REPO_ROOT/plugins/gaia/skills"
  SCRIPTS_DIR="$REPO_ROOT/plugins/gaia/scripts"

  SKILL="gaia-check-dod"
  SKILL_DIR="$SKILLS_DIR/$SKILL"
}

teardown() {
  :
}

# ---------- AC1: Skill directory and SKILL.md exist with valid frontmatter ----------

@test "AC1: gaia-check-dod skill directory exists" {
  [ -d "$SKILL_DIR" ]
}

@test "AC1: gaia-check-dod has SKILL.md" {
  [ -f "$SKILL_DIR/SKILL.md" ]
}

@test "AC1: SKILL.md frontmatter has name field" {
  grep -q "^name: gaia-check-dod" "$SKILL_DIR/SKILL.md"
}

@test "AC1: SKILL.md frontmatter has description field" {
  grep -q "^description:" "$SKILL_DIR/SKILL.md"
}

@test "AC1: SKILL.md frontmatter has argument-hint field" {
  grep -q "^argument-hint:" "$SKILL_DIR/SKILL.md"
}

@test "AC1: SKILL.md argument-hint references story-key" {
  grep -q "story-key" "$SKILL_DIR/SKILL.md"
}

@test "AC1: SKILL.md frontmatter has tools field" {
  grep -q "^tools:" "$SKILL_DIR/SKILL.md"
}

@test "AC1: SKILL.md tools includes Read and Bash" {
  local line
  line=$(grep "^tools:" "$SKILL_DIR/SKILL.md")
  echo "$line" | grep -q "Read"
  echo "$line" | grep -q "Bash"
}

# ---------- AC2: Skill references review-gate.sh ----------

@test "AC2: SKILL.md body references review-gate.sh" {
  grep -q "review-gate.sh" "$SKILL_DIR/SKILL.md"
}

@test "AC2: SKILL.md references dod mode" {
  # The skill should instruct the LLM to parse DoD or invoke review-gate.sh
  grep -qi "definition of done\|dod\|checklist" "$SKILL_DIR/SKILL.md"
}

# ---------- AC3: Cluster 7 shared scripts ----------

@test "AC3: setup.sh exists and is executable" {
  [ -f "$SKILL_DIR/scripts/setup.sh" ]
}

@test "AC3: finalize.sh exists and is executable" {
  [ -f "$SKILL_DIR/scripts/finalize.sh" ]
}

@test "AC3: load-story.sh exists" {
  [ -f "$SKILL_DIR/scripts/load-story.sh" ]
}

@test "AC3: setup.sh references resolve-config.sh" {
  grep -q "resolve-config.sh" "$SKILL_DIR/scripts/setup.sh"
}

@test "AC3: setup.sh references checkpoint.sh" {
  grep -q "checkpoint.sh" "$SKILL_DIR/scripts/setup.sh"
}

@test "AC3: finalize.sh references checkpoint.sh" {
  grep -q "checkpoint.sh" "$SKILL_DIR/scripts/finalize.sh"
}

@test "AC3: finalize.sh references lifecycle-event.sh" {
  grep -q "lifecycle-event.sh" "$SKILL_DIR/scripts/finalize.sh"
}

@test "AC3: load-story.sh references sprint-state.sh" {
  grep -q "sprint-state.sh" "$SKILL_DIR/scripts/load-story.sh"
}

# ---------- AC5: SKILL.md frontmatter structure is valid ----------

@test "AC5: SKILL.md starts with YAML frontmatter delimiters" {
  head -1 "$SKILL_DIR/SKILL.md" | grep -q "^---"
}

@test "AC5: SKILL.md has closing frontmatter delimiter" {
  # Count --- lines: should be at least 2 (open + close)
  local count
  count=$(grep -c "^---" "$SKILL_DIR/SKILL.md")
  [ "$count" -ge 2 ]
}

@test "AC5: SKILL.md has Setup section referencing scripts/setup.sh" {
  grep -q "setup.sh" "$SKILL_DIR/SKILL.md"
}

@test "AC5: SKILL.md has Finalize section referencing scripts/finalize.sh" {
  grep -q "finalize.sh" "$SKILL_DIR/SKILL.md"
}
