#!/usr/bin/env bats
# correct-course-parity.bats — Cluster 8 correct-course skill parity test (E28-S63)
#
# Validates the gaia-correct-course skill directory, scripts, frontmatter,
# and scope-change handling instructions.
#
# Usage:
#   bats tests/cluster-8-parity/correct-course-parity.bats
#
# Dependencies: bats-core 1.10+

# ---------- Helpers ----------

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SKILLS_DIR="$REPO_ROOT/plugins/gaia/skills"
  SCRIPTS_DIR="$REPO_ROOT/plugins/gaia/scripts"

  SKILL="gaia-correct-course"
  SKILL_DIR="$SKILLS_DIR/$SKILL"
}

teardown() {
  :
}

# ---------- AC1: Skill directory and SKILL.md exist with valid frontmatter ----------

@test "AC1: gaia-correct-course skill directory exists" {
  [ -d "$SKILL_DIR" ]
}

@test "AC1: gaia-correct-course has SKILL.md" {
  [ -f "$SKILL_DIR/SKILL.md" ]
}

@test "AC1: SKILL.md frontmatter has name field" {
  grep -q "^name: gaia-correct-course" "$SKILL_DIR/SKILL.md"
}

@test "AC1: SKILL.md frontmatter has description field" {
  grep -q "^description:" "$SKILL_DIR/SKILL.md"
}

@test "AC1: SKILL.md frontmatter has argument-hint field" {
  grep -q "^argument-hint:" "$SKILL_DIR/SKILL.md"
}

@test "AC1: SKILL.md argument-hint references story-key and change-type" {
  local line
  line=$(grep "^argument-hint:" "$SKILL_DIR/SKILL.md")
  echo "$line" | grep -q "story-key"
  echo "$line" | grep -q "change-type"
}

@test "AC1: SKILL.md frontmatter has allowed-tools field" {
  grep -q "^allowed-tools:" "$SKILL_DIR/SKILL.md"
}

@test "AC1: SKILL.md allowed-tools includes Read Edit Bash" {
  local line
  line=$(grep "^allowed-tools:" "$SKILL_DIR/SKILL.md")
  echo "$line" | grep -q "Read"
  echo "$line" | grep -q "Edit"
  echo "$line" | grep -q "Bash"
}

@test "AC1: SKILL.md allowed-tools does NOT include Write" {
  local line
  line=$(grep "^allowed-tools:" "$SKILL_DIR/SKILL.md")
  ! echo "$line" | grep -q "Write"
}

@test "AC1: SKILL.md frontmatter has version field" {
  grep -q "^version:" "$SKILL_DIR/SKILL.md"
}

# ---------- AC2: correct-course uses sprint-state.sh (never direct YAML write) ----------

@test "AC2: SKILL.md references sprint-state.sh" {
  grep -q "sprint-state.sh" "$SKILL_DIR/SKILL.md"
}

@test "AC2: SKILL.md enforces story-file-is-source-of-truth rule" {
  grep -qi "source of truth\|story file.*source\|story.*source.*truth" "$SKILL_DIR/SKILL.md"
}

@test "AC2: SKILL.md forbids direct sprint-status.yaml writes" {
  grep -qi "never.*write.*sprint-status\|never.*modify.*sprint-status\|do not.*write.*sprint-status" "$SKILL_DIR/SKILL.md"
}

@test "AC2: SKILL.md describes scope change types" {
  grep -qi "scope.*change\|priority.*shift\|blocker\|story.*injection" "$SKILL_DIR/SKILL.md"
}

# ---------- AC4: Cluster 8 shared scripts ----------

@test "AC4: setup.sh exists and is executable" {
  [ -f "$SKILL_DIR/scripts/setup.sh" ]
  [ -x "$SKILL_DIR/scripts/setup.sh" ]
}

@test "AC4: finalize.sh exists and is executable" {
  [ -f "$SKILL_DIR/scripts/finalize.sh" ]
  [ -x "$SKILL_DIR/scripts/finalize.sh" ]
}

@test "AC4: setup.sh references resolve-config.sh" {
  grep -q "resolve-config.sh" "$SKILL_DIR/scripts/setup.sh"
}

@test "AC4: setup.sh references validate-gate.sh" {
  grep -q "validate-gate.sh" "$SKILL_DIR/scripts/setup.sh"
}

@test "AC4: setup.sh references checkpoint.sh" {
  grep -q "checkpoint.sh" "$SKILL_DIR/scripts/setup.sh"
}

@test "AC4: setup.sh references lifecycle-event.sh" {
  grep -q "lifecycle-event.sh" "$SKILL_DIR/scripts/setup.sh"
}

@test "AC4: finalize.sh references checkpoint.sh" {
  grep -q "checkpoint.sh" "$SKILL_DIR/scripts/finalize.sh"
}

@test "AC4: finalize.sh references lifecycle-event.sh" {
  grep -q "lifecycle-event.sh" "$SKILL_DIR/scripts/finalize.sh"
}

@test "AC4: SKILL.md has Setup section with setup.sh invocation" {
  grep -q '!${CLAUDE_PLUGIN_ROOT}/skills/gaia-correct-course/scripts/setup.sh' "$SKILL_DIR/SKILL.md"
}

@test "AC4: SKILL.md has Finalize section with finalize.sh invocation" {
  grep -q '!${CLAUDE_PLUGIN_ROOT}/skills/gaia-correct-course/scripts/finalize.sh' "$SKILL_DIR/SKILL.md"
}

# ---------- AC5: Frontmatter linter conformance ----------

@test "AC5: SKILL.md frontmatter is YAML-delimited with ---" {
  head -1 "$SKILL_DIR/SKILL.md" | grep -q "^---$"
  sed -n '2,10p' "$SKILL_DIR/SKILL.md" | grep -q "^---$"
}

# ---------- Structural consistency with sibling Cluster 8 skills ----------

@test "Structure: SKILL.md has Mission section" {
  grep -q "## Mission" "$SKILL_DIR/SKILL.md"
}

@test "Structure: SKILL.md has Critical Rules section" {
  grep -q "## Critical Rules" "$SKILL_DIR/SKILL.md"
}

@test "Structure: SKILL.md has Steps section" {
  grep -q "## Steps" "$SKILL_DIR/SKILL.md" || grep -q "### Step" "$SKILL_DIR/SKILL.md"
}
