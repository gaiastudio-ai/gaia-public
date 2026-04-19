#!/usr/bin/env bats
# storytelling-parity.bats — E28-S104 parity + structure tests for
# gaia-storytelling (converted from _gaia/creative/workflows/storytelling/).
#
# Refs: E28-S104, FR-323, NFR-048, NFR-053, ADR-041
#
# Shell idioms: the `awk '/^## References/ { in_refs = 1 } !in_refs { print }'`
# pattern used below for trailing-section removal follows the state-machine
# convention codified in `gaia-shell-idioms` (see E28-S168 and the
# gaia-shell-idioms/SKILL.md "awk range bug" section). Do NOT rewrite it as
# `awk '/^## References/,0'` or any `/start/,/end/` range — see the skill for
# why that idiom fails when start and end patterns can match the same line.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SKILLS_DIR="$REPO_ROOT/plugins/gaia/skills"
  AGENTS_DIR="$REPO_ROOT/plugins/gaia/agents"
  SKILL="gaia-storytelling"
  SKILL_DIR="$SKILLS_DIR/$SKILL"
  SKILL_FILE="$SKILL_DIR/SKILL.md"
}

# ---------- AC1: Frontmatter conformance ----------

@test "E28-S104: storytelling SKILL.md exists" {
  [ -f "$SKILL_FILE" ]
}

@test "E28-S104: storytelling frontmatter has name: gaia-storytelling" {
  head -20 "$SKILL_FILE" | grep -q '^name: gaia-storytelling'
}

@test "E28-S104: storytelling frontmatter has description" {
  head -20 "$SKILL_FILE" | grep -q '^description:'
}

@test "E28-S104: storytelling frontmatter has argument-hint" {
  head -20 "$SKILL_FILE" | grep -q '^argument-hint:'
}

@test "E28-S104: storytelling frontmatter has context: fork" {
  head -20 "$SKILL_FILE" | grep -q '^context: fork'
}

@test "E28-S104: storytelling frontmatter tools is present" {
  head -20 "$SKILL_FILE" | grep -q '^tools:'
}

# ---------- AC1: Story framework pipeline preserved ----------

@test "E28-S104: storytelling references Elara subagent" {
  grep -q 'Elara' "$SKILL_FILE"
}

@test "E28-S104: storytelling references storyteller subagent path" {
  grep -q 'storyteller' "$SKILL_FILE"
}

@test "E28-S104: storytelling preserves narrative arc instruction" {
  grep -qiE 'narrative arc|transformation arc' "$SKILL_FILE"
}

@test "E28-S104: storytelling preserves emotional beats instruction" {
  grep -qi 'emotional beats' "$SKILL_FILE"
}

@test "E28-S104: storytelling references story-types.csv data file" {
  grep -q 'story-types.csv' "$SKILL_FILE"
}

@test "E28-S104: storytelling references data_path template" {
  grep -qE '\{data_path\}|\$\{data_path\}' "$SKILL_FILE"
}

@test "E28-S104: storytelling preserves 3-second hook rule" {
  grep -qi '3-second' "$SKILL_FILE"
}

# ---------- AC1: Output contract preserved ----------

@test "E28-S104: storytelling references output path docs/creative-artifacts/story-" {
  grep -q 'docs/creative-artifacts/story-' "$SKILL_FILE"
}

@test "E28-S104: storytelling references date-suffixed output filename" {
  grep -qE 'story-\{date\}\.md' "$SKILL_FILE"
}

# ---------- AC5: Linter compliance ----------

@test "E28-S104: lint-skill-frontmatter.sh passes on gaia-storytelling SKILL.md" {
  cd "$REPO_ROOT"
  bash .github/scripts/lint-skill-frontmatter.sh
}

# ---------- Layout constraints ----------

@test "E28-S104: gaia-storytelling/ has no workflow.yaml" {
  [ ! -f "$SKILL_DIR/workflow.yaml" ]
}

@test "E28-S104: gaia-storytelling/ has no instructions.xml" {
  [ ! -f "$SKILL_DIR/instructions.xml" ]
}

# ---------- Legacy path zero references (Test Scenario 10) ----------

@test "E28-S104: storytelling SKILL.md does NOT reference legacy _gaia/creative/workflows/ in body" {
  body=$(awk '/^## References/ { in_refs = 1 } !in_refs { print }' "$SKILL_FILE")
  ! echo "$body" | grep -q '_gaia/creative/workflows/storytelling'
}

@test "E28-S104: storytelling SKILL.md does NOT reference invoke-workflow tag" {
  ! grep -q 'invoke-workflow' "$SKILL_FILE"
}

# ---------- Subagent registration ----------

@test "E28-S104: required subagent storyteller exists" {
  [ -f "$AGENTS_DIR/storyteller.md" ]
}
