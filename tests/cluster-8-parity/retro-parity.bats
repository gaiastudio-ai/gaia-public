#!/usr/bin/env bats
# retro-parity.bats — Cluster 8 retrospective skill parity test (E28-S64)
#
# Validates the gaia-retro skill directory, scripts, frontmatter,
# and retro facilitation instructions.
#
# Usage:
#   bats tests/cluster-8-parity/retro-parity.bats
#
# Dependencies: bats-core 1.10+

# ---------- Helpers ----------

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SKILLS_DIR="$REPO_ROOT/plugins/gaia/skills"
  SCRIPTS_DIR="$REPO_ROOT/plugins/gaia/scripts"

  SKILL="gaia-retro"
  SKILL_DIR="$SKILLS_DIR/$SKILL"
}

teardown() {
  :
}

# ---------- AC1: Skill directory and SKILL.md exist with valid frontmatter ----------

@test "AC1: gaia-retro skill directory exists" {
  [ -d "$SKILL_DIR" ]
}

@test "AC1: gaia-retro has SKILL.md" {
  [ -f "$SKILL_DIR/SKILL.md" ]
}

@test "AC1: SKILL.md frontmatter has name field" {
  grep -q "^name: gaia-retro" "$SKILL_DIR/SKILL.md"
}

@test "AC1: SKILL.md frontmatter has description field" {
  grep -q "^description:" "$SKILL_DIR/SKILL.md"
}

@test "AC1: SKILL.md frontmatter has argument-hint field" {
  grep -q "^argument-hint:" "$SKILL_DIR/SKILL.md"
}

@test "AC1: SKILL.md argument-hint references sprint-id" {
  grep -q "sprint-id" "$SKILL_DIR/SKILL.md"
}

@test "AC1: SKILL.md frontmatter has allowed-tools field" {
  grep -q "^allowed-tools:" "$SKILL_DIR/SKILL.md"
}

@test "AC1: SKILL.md allowed-tools includes Read Write and Bash" {
  local line
  line=$(grep "^allowed-tools:" "$SKILL_DIR/SKILL.md")
  echo "$line" | grep -q "Read"
  echo "$line" | grep -q "Write"
  echo "$line" | grep -q "Bash"
}

@test "AC1: SKILL.md frontmatter has version field" {
  grep -q "^version:" "$SKILL_DIR/SKILL.md"
}

# ---------- AC2: Retro facilitation and artifact output ----------

@test "AC2: SKILL.md references sprint-status.yaml" {
  grep -q "sprint-status.yaml" "$SKILL_DIR/SKILL.md"
}

@test "AC2: SKILL.md describes went-well section" {
  grep -qi "went.well\|went well" "$SKILL_DIR/SKILL.md"
}

@test "AC2: SKILL.md describes didn't-go-well section" {
  grep -qi "didn.*go.well\|could.*improve\|improvement" "$SKILL_DIR/SKILL.md"
}

@test "AC2: SKILL.md describes action-items section" {
  grep -qi "action.item" "$SKILL_DIR/SKILL.md"
}

@test "AC2: SKILL.md references retrospective artifact output path" {
  grep -q "retrospective-" "$SKILL_DIR/SKILL.md"
}

@test "AC2: SKILL.md describes write-once guard for existing retros" {
  grep -qi "clobber\|overwrite\|already exists\|suffix\|timestamp" "$SKILL_DIR/SKILL.md"
}

# ---------- AC3: Cluster 8 shared scripts ----------

@test "AC3: setup.sh exists and is executable" {
  [ -f "$SKILL_DIR/scripts/setup.sh" ]
  [ -x "$SKILL_DIR/scripts/setup.sh" ]
}

@test "AC3: finalize.sh exists and is executable" {
  [ -f "$SKILL_DIR/scripts/finalize.sh" ]
  [ -x "$SKILL_DIR/scripts/finalize.sh" ]
}

@test "AC3: setup.sh references resolve-config.sh" {
  grep -q "resolve-config.sh" "$SKILL_DIR/scripts/setup.sh"
}

@test "AC3: setup.sh references validate-gate.sh" {
  grep -q "validate-gate.sh" "$SKILL_DIR/scripts/setup.sh"
}

@test "AC3: setup.sh references checkpoint.sh" {
  grep -q "checkpoint.sh" "$SKILL_DIR/scripts/setup.sh"
}

@test "AC3: setup.sh references lifecycle-event.sh" {
  grep -q "lifecycle-event.sh" "$SKILL_DIR/scripts/setup.sh"
}

@test "AC3: finalize.sh references checkpoint.sh" {
  grep -q "checkpoint.sh" "$SKILL_DIR/scripts/finalize.sh"
}

@test "AC3: finalize.sh references lifecycle-event.sh" {
  grep -q "lifecycle-event.sh" "$SKILL_DIR/scripts/finalize.sh"
}

@test "AC3: SKILL.md has Setup section with setup.sh invocation" {
  grep -q '!${CLAUDE_PLUGIN_ROOT}/skills/gaia-retro/scripts/setup.sh' "$SKILL_DIR/SKILL.md"
}

@test "AC3: SKILL.md has Finalize section with finalize.sh invocation" {
  grep -q '!${CLAUDE_PLUGIN_ROOT}/skills/gaia-retro/scripts/finalize.sh' "$SKILL_DIR/SKILL.md"
}

# ---------- AC4: Frontmatter linter conformance ----------

@test "AC4: SKILL.md frontmatter is YAML-delimited with ---" {
  head -1 "$SKILL_DIR/SKILL.md" | grep -q "^---$"
  # Second delimiter must appear within first 10 lines
  sed -n '2,10p' "$SKILL_DIR/SKILL.md" | grep -q "^---$"
}

@test "AC4: SKILL.md has no Edit in allowed-tools (write-once skill)" {
  local line
  line=$(grep "^allowed-tools:" "$SKILL_DIR/SKILL.md")
  ! echo "$line" | grep -q "Edit"
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
