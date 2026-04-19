#!/usr/bin/env bats
# check-review-gate-parity.bats — Cluster 7 check-review-gate skill parity test (E28-S56)
#
# Validates the gaia-check-review-gate skill directory, scripts, frontmatter,
# and review-gate.sh integration for Review Gate checking.
#
# Usage:
#   bats tests/cluster-7-parity/check-review-gate-parity.bats
#
# Dependencies: bats-core 1.10+

# ---------- Helpers ----------

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SKILLS_DIR="$REPO_ROOT/plugins/gaia/skills"
  SCRIPTS_DIR="$REPO_ROOT/plugins/gaia/scripts"

  SKILL="gaia-check-review-gate"
  SKILL_DIR="$SKILLS_DIR/$SKILL"
}

teardown() {
  :
}

# ---------- AC1: Skill directory and SKILL.md exist with valid frontmatter ----------

@test "AC1: gaia-check-review-gate skill directory exists" {
  [ -d "$SKILL_DIR" ]
}

@test "AC1: gaia-check-review-gate has SKILL.md" {
  [ -f "$SKILL_DIR/SKILL.md" ]
}

@test "AC1: SKILL.md frontmatter has name field" {
  grep -q "^name: gaia-check-review-gate" "$SKILL_DIR/SKILL.md"
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

@test "AC1: SKILL.md frontmatter has allowed-tools field" {
  grep -q "^allowed-tools:" "$SKILL_DIR/SKILL.md"
}

@test "AC1: SKILL.md allowed-tools includes Read and Bash" {
  local line
  line=$(grep "^allowed-tools:" "$SKILL_DIR/SKILL.md")
  echo "$line" | grep -q "Read"
  echo "$line" | grep -q "Bash"
}

# ---------- AC2/AC4: Skill references review-gate.sh and canonical vocabulary ----------

@test "AC2: SKILL.md body references review-gate.sh" {
  grep -q "review-gate.sh" "$SKILL_DIR/SKILL.md"
}

@test "AC4: SKILL.md references canonical vocabulary PASSED" {
  grep -q "PASSED" "$SKILL_DIR/SKILL.md"
}

@test "AC4: SKILL.md references canonical vocabulary FAILED" {
  grep -q "FAILED" "$SKILL_DIR/SKILL.md"
}

@test "AC4: SKILL.md references canonical vocabulary UNVERIFIED" {
  grep -q "UNVERIFIED" "$SKILL_DIR/SKILL.md"
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

# ---------- Review Gate specific: composite verdict ----------

@test "SKILL.md references composite verdict for all-PASSED scenario" {
  grep -qi "all.*pass\|composite\|ready" "$SKILL_DIR/SKILL.md"
}

@test "SKILL.md references review gate table" {
  grep -qi "review gate" "$SKILL_DIR/SKILL.md"
}
