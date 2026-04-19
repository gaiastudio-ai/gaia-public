#!/usr/bin/env bats
# pitch-deck-parity.bats — E28-S104 parity + structure tests for
# gaia-pitch-deck (converted from _gaia/creative/workflows/pitch-deck/).
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
  SKILL="gaia-pitch-deck"
  SKILL_DIR="$SKILLS_DIR/$SKILL"
  SKILL_FILE="$SKILL_DIR/SKILL.md"
}

# ---------- AC3: Frontmatter conformance ----------

@test "E28-S104: pitch-deck SKILL.md exists" {
  [ -f "$SKILL_FILE" ]
}

@test "E28-S104: pitch-deck frontmatter has name: gaia-pitch-deck" {
  head -20 "$SKILL_FILE" | grep -q '^name: gaia-pitch-deck'
}

@test "E28-S104: pitch-deck frontmatter has description" {
  head -20 "$SKILL_FILE" | grep -q '^description:'
}

@test "E28-S104: pitch-deck frontmatter has argument-hint" {
  head -20 "$SKILL_FILE" | grep -q '^argument-hint:'
}

@test "E28-S104: pitch-deck frontmatter has context: fork" {
  head -20 "$SKILL_FILE" | grep -q '^context: fork'
}

@test "E28-S104: pitch-deck frontmatter allowed-tools present" {
  head -20 "$SKILL_FILE" | grep -q '^allowed-tools:'
}

# ---------- AC3: Standard pitch structure preserved ----------

@test "E28-S104: pitch-deck references Vermeer subagent" {
  grep -q 'Vermeer' "$SKILL_FILE"
}

@test "E28-S104: pitch-deck references presentation-designer subagent" {
  grep -q 'presentation-designer' "$SKILL_FILE"
}

@test "E28-S104: pitch-deck preserves Problem section" {
  grep -qE '^[#-].*Problem' "$SKILL_FILE"
}

@test "E28-S104: pitch-deck preserves Solution section" {
  grep -qE '^[#-].*Solution' "$SKILL_FILE"
}

@test "E28-S104: pitch-deck preserves Market section" {
  grep -qE '^[#-].*Market' "$SKILL_FILE"
}

@test "E28-S104: pitch-deck preserves Traction section" {
  grep -qE '^[#-].*Traction' "$SKILL_FILE"
}

@test "E28-S104: pitch-deck preserves Team section" {
  grep -qE '^[#-].*Team' "$SKILL_FILE"
}

@test "E28-S104: pitch-deck preserves Ask section" {
  grep -qE '^[#-].*Ask' "$SKILL_FILE"
}

@test "E28-S104: pitch-deck preserves Business Model / Model section" {
  grep -qiE 'business model|revenue model' "$SKILL_FILE"
}

# ---------- AC3: Output contract preserved ----------

@test "E28-S104: pitch-deck references output path docs/creative-artifacts/pitch-deck-" {
  grep -q 'docs/creative-artifacts/pitch-deck-' "$SKILL_FILE"
}

@test "E28-S104: pitch-deck references date-suffixed output filename" {
  grep -qE 'pitch-deck-\{date\}\.md' "$SKILL_FILE"
}

# ---------- AC5: Linter compliance ----------

@test "E28-S104: lint-skill-frontmatter.sh passes on gaia-pitch-deck SKILL.md" {
  cd "$REPO_ROOT"
  bash .github/scripts/lint-skill-frontmatter.sh
}

# ---------- Layout constraints ----------

@test "E28-S104: gaia-pitch-deck/ has no workflow.yaml" {
  [ ! -f "$SKILL_DIR/workflow.yaml" ]
}

@test "E28-S104: gaia-pitch-deck/ has no instructions.xml" {
  [ ! -f "$SKILL_DIR/instructions.xml" ]
}

# ---------- Legacy path zero references ----------

@test "E28-S104: pitch-deck SKILL.md does NOT reference legacy _gaia/creative/workflows/ in body" {
  body=$(awk '/^## References/ { in_refs = 1 } !in_refs { print }' "$SKILL_FILE")
  ! echo "$body" | grep -q '_gaia/creative/workflows/pitch-deck'
}

@test "E28-S104: pitch-deck SKILL.md does NOT reference invoke-workflow tag" {
  ! grep -q 'invoke-workflow' "$SKILL_FILE"
}
