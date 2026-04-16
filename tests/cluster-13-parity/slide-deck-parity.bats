#!/usr/bin/env bats
# slide-deck-parity.bats — E28-S104 parity + structure tests for
# gaia-slide-deck (converted from _gaia/creative/workflows/slide-deck/).
#
# Refs: E28-S104, FR-323, NFR-048, NFR-053, ADR-041

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SKILLS_DIR="$REPO_ROOT/plugins/gaia/skills"
  AGENTS_DIR="$REPO_ROOT/plugins/gaia/agents"
  SKILL="gaia-slide-deck"
  SKILL_DIR="$SKILLS_DIR/$SKILL"
  SKILL_FILE="$SKILL_DIR/SKILL.md"
}

# ---------- AC2: Frontmatter conformance ----------

@test "E28-S104: slide-deck SKILL.md exists" {
  [ -f "$SKILL_FILE" ]
}

@test "E28-S104: slide-deck frontmatter has name: gaia-slide-deck" {
  head -20 "$SKILL_FILE" | grep -q '^name: gaia-slide-deck'
}

@test "E28-S104: slide-deck frontmatter has description" {
  head -20 "$SKILL_FILE" | grep -q '^description:'
}

@test "E28-S104: slide-deck frontmatter has argument-hint" {
  head -20 "$SKILL_FILE" | grep -q '^argument-hint:'
}

@test "E28-S104: slide-deck frontmatter has context: fork" {
  head -20 "$SKILL_FILE" | grep -q '^context: fork'
}

@test "E28-S104: slide-deck frontmatter allowed-tools present" {
  head -20 "$SKILL_FILE" | grep -q '^allowed-tools:'
}

# ---------- AC2: Narrative-arc slide structure preserved ----------

@test "E28-S104: slide-deck references Vermeer subagent" {
  grep -q 'Vermeer' "$SKILL_FILE"
}

@test "E28-S104: slide-deck references presentation-designer subagent" {
  grep -q 'presentation-designer' "$SKILL_FILE"
}

@test "E28-S104: slide-deck preserves narrative arc instructions (hook, build, payoff)" {
  grep -qi 'narrative arc' "$SKILL_FILE"
  grep -qiE 'hook.*build.*payoff|hook,.*build,.*payoff' "$SKILL_FILE"
}

@test "E28-S104: slide-deck preserves one-slide-one-idea rule" {
  grep -qiE 'one slide.*one idea|one key message' "$SKILL_FILE"
}

@test "E28-S104: slide-deck preserves visual-design guidance" {
  grep -qiE 'visual design|color palette|typography' "$SKILL_FILE"
}

# ---------- AC2: Output contract preserved ----------

@test "E28-S104: slide-deck references output path docs/creative-artifacts/slide-deck-" {
  grep -q 'docs/creative-artifacts/slide-deck-' "$SKILL_FILE"
}

@test "E28-S104: slide-deck references date-suffixed output filename" {
  grep -qE 'slide-deck-\{date\}\.md' "$SKILL_FILE"
}

# ---------- AC5: Linter compliance ----------

@test "E28-S104: lint-skill-frontmatter.sh passes on gaia-slide-deck SKILL.md" {
  cd "$REPO_ROOT"
  bash .github/scripts/lint-skill-frontmatter.sh
}

# ---------- Layout constraints ----------

@test "E28-S104: gaia-slide-deck/ has no workflow.yaml" {
  [ ! -f "$SKILL_DIR/workflow.yaml" ]
}

@test "E28-S104: gaia-slide-deck/ has no instructions.xml" {
  [ ! -f "$SKILL_DIR/instructions.xml" ]
}

# ---------- Legacy path zero references ----------

@test "E28-S104: slide-deck SKILL.md does NOT reference legacy _gaia/creative/workflows/ in body" {
  body=$(awk '/^## References/ { in_refs = 1 } !in_refs { print }' "$SKILL_FILE")
  ! echo "$body" | grep -q '_gaia/creative/workflows/slide-deck'
}

@test "E28-S104: slide-deck SKILL.md does NOT reference invoke-workflow tag" {
  ! grep -q 'invoke-workflow' "$SKILL_FILE"
}

# ---------- Subagent registration ----------

@test "E28-S104: required subagent presentation-designer exists" {
  [ -f "$AGENTS_DIR/presentation-designer.md" ]
}
