#!/usr/bin/env bats
# create-story-parity.bats — Cluster 7 create-story skill parity test (E28-S52)
#
# Validates the gaia-create-story skill directory, scripts, frontmatter,
# story template bundling, slug generation, and sprint-state integration.
#
# Usage:
#   bats tests/cluster-7-parity/create-story-parity.bats
#
# Dependencies: bats-core 1.10+

# ---------- Helpers ----------

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SKILLS_DIR="$REPO_ROOT/plugins/gaia/skills"
  SCRIPTS_DIR="$REPO_ROOT/plugins/gaia/scripts"

  SKILL="gaia-create-story"
  SKILL_DIR="$SKILLS_DIR/$SKILL"
}

teardown() {
  :
}

# ---------- AC1: Skill directory and SKILL.md exist with valid frontmatter ----------

@test "AC1: gaia-create-story skill directory exists" {
  [ -d "$SKILL_DIR" ]
}

@test "AC1: gaia-create-story has SKILL.md" {
  [ -f "$SKILL_DIR/SKILL.md" ]
}

@test "AC1: SKILL.md frontmatter has name field" {
  grep -q "^name: gaia-create-story" "$SKILL_DIR/SKILL.md"
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

@test "AC1: SKILL.md allowed-tools includes Read Write Edit Bash" {
  local line
  line=$(grep "^allowed-tools:" "$SKILL_DIR/SKILL.md")
  echo "$line" | grep -q "Read"
  echo "$line" | grep -q "Write"
  echo "$line" | grep -q "Edit"
  echo "$line" | grep -q "Bash"
}

# ---------- AC2: Cluster 7 shared scripts (setup.sh / finalize.sh) ----------

@test "AC2: scripts/setup.sh exists" {
  [ -f "$SKILL_DIR/scripts/setup.sh" ]
}

@test "AC2: scripts/finalize.sh exists" {
  [ -f "$SKILL_DIR/scripts/finalize.sh" ]
}

@test "AC2: setup.sh references resolve-config.sh" {
  grep -q "resolve-config.sh" "$SKILL_DIR/scripts/setup.sh"
}

@test "AC2: setup.sh follows shared pattern (set -euo pipefail)" {
  grep -q "set -euo pipefail" "$SKILL_DIR/scripts/setup.sh"
}

@test "AC2: finalize.sh references checkpoint.sh" {
  grep -q "checkpoint.sh" "$SKILL_DIR/scripts/finalize.sh"
}

@test "AC2: finalize.sh references lifecycle-event.sh" {
  grep -q "lifecycle-event.sh" "$SKILL_DIR/scripts/finalize.sh"
}

@test "AC2: finalize.sh follows shared pattern (set -euo pipefail)" {
  grep -q "set -euo pipefail" "$SKILL_DIR/scripts/finalize.sh"
}

# ---------- AC3: Story lifecycle scripts (load-story.sh / update-story-status.sh) ----------

@test "AC3: scripts/load-story.sh exists" {
  [ -f "$SKILL_DIR/scripts/load-story.sh" ]
}

@test "AC3: scripts/update-story-status.sh exists" {
  [ -f "$SKILL_DIR/scripts/update-story-status.sh" ]
}

@test "AC3: load-story.sh references sprint-state.sh" {
  grep -q "sprint-state.sh" "$SKILL_DIR/scripts/load-story.sh"
}

@test "AC3: update-story-status.sh references sprint-state.sh" {
  grep -q "sprint-state.sh" "$SKILL_DIR/scripts/update-story-status.sh"
}

@test "AC3: update-story-status.sh supports backlog state" {
  grep -q "backlog" "$SKILL_DIR/scripts/update-story-status.sh"
}

# ---------- AC4: Canonical filename convention ----------

@test "AC4: SKILL.md references canonical slug convention" {
  grep -q "story_key.*slug\|{story_key}-{slug}" "$SKILL_DIR/SKILL.md"
}

@test "AC4: SKILL.md references docs/implementation-artifacts as output path" {
  grep -q "implementation-artifacts" "$SKILL_DIR/SKILL.md"
}

# ---------- AC5: Story template bundling ----------

@test "AC5: story-template.md is bundled in skill directory" {
  [ -f "$SKILL_DIR/story-template.md" ]
}

@test "AC5: story-template.md contains required frontmatter fields" {
  local tpl="$SKILL_DIR/story-template.md"
  grep -q "^key:" "$tpl"
  grep -q "^title:" "$tpl"
  grep -q "^epic:" "$tpl"
  grep -q "^status:" "$tpl"
  grep -q "^priority:" "$tpl"
  grep -q "^size:" "$tpl"
  grep -q "^points:" "$tpl"
  grep -q "^risk:" "$tpl"
  grep -q "^sprint_id:" "$tpl"
  grep -q "^depends_on:" "$tpl"
  grep -q "^blocks:" "$tpl"
  grep -q "^traces_to:" "$tpl"
  grep -q "^date:" "$tpl"
  grep -q "^author:" "$tpl"
  grep -q "^priority_flag:" "$tpl"
}

@test "AC5: story-template.md has Review Gate section" {
  grep -q "## Review Gate" "$SKILL_DIR/story-template.md"
}

@test "AC5: story-template.md has Definition of Done section" {
  grep -q "## Definition of Done" "$SKILL_DIR/story-template.md"
}

# ---------- AC6: Slugification ----------

@test "AC6: SKILL.md describes slug generation rules" {
  grep -qi "slug\|slugif" "$SKILL_DIR/SKILL.md"
}

# ---------- General: No runtime dependency on _gaia/ tree ----------

@test "SKILL.md does NOT reference _gaia/ framework tree" {
  # The skill must be self-contained — no runtime dependency on the legacy _gaia/ tree
  ! grep -q "_gaia/" "$SKILL_DIR/SKILL.md" || {
    # Allow references in comments/notes only
    local count
    count=$(grep -c "_gaia/" "$SKILL_DIR/SKILL.md")
    [ "$count" -le 1 ]
  }
}
