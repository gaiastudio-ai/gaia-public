#!/usr/bin/env bats
# triage-findings-parity.bats — Cluster 8 triage-findings skill parity test (E28-S63)
#
# Validates the gaia-triage-findings skill directory, scripts, frontmatter,
# and findings triage logic instructions.
#
# Usage:
#   bats tests/cluster-8-parity/triage-findings-parity.bats
#
# Dependencies: bats-core 1.10+

# ---------- Helpers ----------

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SKILLS_DIR="$REPO_ROOT/plugins/gaia/skills"
  SCRIPTS_DIR="$REPO_ROOT/plugins/gaia/scripts"

  SKILL="gaia-triage-findings"
  SKILL_DIR="$SKILLS_DIR/$SKILL"
}

teardown() {
  :
}

# ---------- AC1: Skill directory and SKILL.md exist with valid frontmatter ----------

@test "AC1: gaia-triage-findings skill directory exists" {
  [ -d "$SKILL_DIR" ]
}

@test "AC1: gaia-triage-findings has SKILL.md" {
  [ -f "$SKILL_DIR/SKILL.md" ]
}

@test "AC1: SKILL.md frontmatter has name field" {
  grep -q "^name: gaia-triage-findings" "$SKILL_DIR/SKILL.md"
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

@test "AC1: SKILL.md tools includes Read Write Bash" {
  local line
  line=$(grep "^tools:" "$SKILL_DIR/SKILL.md")
  echo "$line" | grep -q "Read"
  echo "$line" | grep -q "Write"
  echo "$line" | grep -q "Bash"
}

@test "AC1: SKILL.md frontmatter has version field" {
  grep -q "^version:" "$SKILL_DIR/SKILL.md"
}

# ---------- AC3: triage-findings emits new backlog story files ----------

@test "AC3: SKILL.md describes scanning for findings tables" {
  grep -qi "findings.*table\|scan.*findings\|finding.*row" "$SKILL_DIR/SKILL.md"
}

@test "AC3: SKILL.md describes creating backlog stories" {
  grep -qi "backlog.*stor\|create.*stor\|new.*stor.*file" "$SKILL_DIR/SKILL.md"
}

@test "AC3: SKILL.md describes 15 required frontmatter fields" {
  grep -qi "frontmatter\|15.*field\|required.*field" "$SKILL_DIR/SKILL.md"
}

@test "AC3: SKILL.md sets status backlog and sprint_id null for new stories" {
  grep -q "status: backlog" "$SKILL_DIR/SKILL.md" || grep -qi "status.*backlog" "$SKILL_DIR/SKILL.md"
  grep -q "sprint_id: null" "$SKILL_DIR/SKILL.md" || grep -qi "sprint_id.*null" "$SKILL_DIR/SKILL.md"
}

@test "AC3: SKILL.md never mutates source story findings table" {
  grep -qi "never.*mutate\|intact\|do not.*modify.*source\|source.*stay" "$SKILL_DIR/SKILL.md"
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
  grep -q '!${CLAUDE_PLUGIN_ROOT}/skills/gaia-triage-findings/scripts/setup.sh' "$SKILL_DIR/SKILL.md"
}

@test "AC4: SKILL.md has Finalize section with finalize.sh invocation" {
  grep -q '!${CLAUDE_PLUGIN_ROOT}/skills/gaia-triage-findings/scripts/finalize.sh' "$SKILL_DIR/SKILL.md"
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
