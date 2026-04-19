#!/usr/bin/env bats
# brainstorming-parity.bats — E28-S100 parity + structure tests
#
# Validates the conversion of _gaia/core/workflows/brainstorming/ to a native
# SKILL.md file at plugins/gaia/skills/gaia-brainstorming/SKILL.md.
#
#   AC1: SKILL.md frontmatter conforms to canonical skill pattern
#        (name, description, argument-hint, context: fork, allowed-tools)
#   AC2: Session-management flow preserved — 4 phase headings in order,
#        full 8-row technique table, 15–30 ideas target, Impact/Feasibility
#        ranking matrix
#   AC3: Linter compliance (enforced by separate lint-skill-frontmatter.sh run)
#   AC4: bats-core parity assertions (this file) — SKILL.md exists + valid
#        frontmatter, phase ordering, technique table, output path reference,
#        Rex subagent reference, brainstorming-template.md exists + non-empty,
#        _reference-frontmatter.md exists
#
# Refs: E28-S100, NFR-048, NFR-053, ADR-041, FR-323
#
# Usage:
#   bats tests/cluster-13-parity/brainstorming-parity.bats
#
# Dependencies: bats-core 1.10+

# ---------- Helpers ----------

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SKILLS_DIR="$REPO_ROOT/plugins/gaia/skills"

  SKILL="gaia-brainstorming"
  SKILL_DIR="$SKILLS_DIR/$SKILL"
}

# ---------- AC1: Frontmatter conformance ----------

@test "E28-S100: SKILL.md exists" {
  [ -f "$SKILL_DIR/SKILL.md" ]
}

@test "E28-S100: SKILL.md frontmatter has name: gaia-brainstorming" {
  head -20 "$SKILL_DIR/SKILL.md" | grep -q '^name: gaia-brainstorming'
}

@test "E28-S100: SKILL.md frontmatter has description" {
  head -20 "$SKILL_DIR/SKILL.md" | grep -q '^description:'
}

@test "E28-S100: SKILL.md frontmatter has argument-hint" {
  head -20 "$SKILL_DIR/SKILL.md" | grep -q '^argument-hint:'
}

@test "E28-S100: SKILL.md frontmatter has context: fork" {
  head -20 "$SKILL_DIR/SKILL.md" | grep -q '^context: fork'
}

@test "E28-S100: SKILL.md frontmatter allowed-tools contains Read" {
  head -20 "$SKILL_DIR/SKILL.md" | grep -q 'allowed-tools:.*Read'
}

@test "E28-S100: SKILL.md frontmatter allowed-tools contains Write" {
  head -20 "$SKILL_DIR/SKILL.md" | grep -q 'allowed-tools:.*Write'
}

@test "E28-S100: SKILL.md frontmatter allowed-tools contains Glob" {
  head -20 "$SKILL_DIR/SKILL.md" | grep -q 'allowed-tools:.*Glob'
}

# ---------- AC2: Phase headings in order ----------

@test "E28-S100: SKILL.md contains Session Setup heading" {
  grep -q '^## Session Setup' "$SKILL_DIR/SKILL.md"
}

@test "E28-S100: SKILL.md contains Technique Selection heading" {
  grep -q '^## Technique Selection' "$SKILL_DIR/SKILL.md"
}

@test "E28-S100: SKILL.md contains Technique Execution heading" {
  grep -q '^## Technique Execution' "$SKILL_DIR/SKILL.md"
}

@test "E28-S100: SKILL.md contains Idea Organization heading" {
  grep -q '^## Idea Organization' "$SKILL_DIR/SKILL.md"
}

@test "E28-S100: SKILL.md phase headings appear in correct order" {
  # Capture line numbers for each heading and verify ascending order.
  setup_line=$(grep -n '^## Session Setup' "$SKILL_DIR/SKILL.md" | head -1 | cut -d: -f1)
  selection_line=$(grep -n '^## Technique Selection' "$SKILL_DIR/SKILL.md" | head -1 | cut -d: -f1)
  execution_line=$(grep -n '^## Technique Execution' "$SKILL_DIR/SKILL.md" | head -1 | cut -d: -f1)
  organization_line=$(grep -n '^## Idea Organization' "$SKILL_DIR/SKILL.md" | head -1 | cut -d: -f1)

  [ -n "$setup_line" ] && [ -n "$selection_line" ] && [ -n "$execution_line" ] && [ -n "$organization_line" ]
  [ "$setup_line" -lt "$selection_line" ]
  [ "$selection_line" -lt "$execution_line" ]
  [ "$execution_line" -lt "$organization_line" ]
}

# ---------- AC2: Full 8-technique table ----------

@test "E28-S100: technique table contains Mind Mapping" {
  grep -q 'Mind Mapping' "$SKILL_DIR/SKILL.md"
}

@test "E28-S100: technique table contains SCAMPER" {
  grep -q 'SCAMPER' "$SKILL_DIR/SKILL.md"
}

@test "E28-S100: technique table contains Reverse Brainstorming" {
  grep -q 'Reverse Brainstorming' "$SKILL_DIR/SKILL.md"
}

@test "E28-S100: technique table contains Six Thinking Hats" {
  grep -q 'Six Thinking Hats' "$SKILL_DIR/SKILL.md"
}

@test "E28-S100: technique table contains Brainwriting" {
  grep -q 'Brainwriting' "$SKILL_DIR/SKILL.md"
}

@test "E28-S100: technique table contains Worst Possible Idea" {
  grep -q 'Worst Possible Idea' "$SKILL_DIR/SKILL.md"
}

@test "E28-S100: technique table contains SWOT" {
  grep -q 'SWOT' "$SKILL_DIR/SKILL.md"
}

@test "E28-S100: technique table contains How Might We" {
  grep -q 'How Might We' "$SKILL_DIR/SKILL.md"
}

# ---------- AC2: Target idea count and ranking matrix ----------

@test "E28-S100: SKILL.md references the 15-30 idea target" {
  grep -qE '15[-–]30|15 to 30' "$SKILL_DIR/SKILL.md"
}

@test "E28-S100: SKILL.md contains Impact/Feasibility ranking" {
  grep -qi 'impact' "$SKILL_DIR/SKILL.md"
  grep -qi 'feasibility' "$SKILL_DIR/SKILL.md"
}

# ---------- AC4: Output path preserved ----------

@test "E28-S100: SKILL.md references output path docs/creative-artifacts/brainstorming-" {
  grep -q 'docs/creative-artifacts/brainstorming-' "$SKILL_DIR/SKILL.md"
}

# ---------- AC2: Rex / brainstorming-coach subagent reference ----------

@test "E28-S100: SKILL.md references Rex or brainstorming-coach subagent" {
  grep -qi 'rex\|brainstorming-coach' "$SKILL_DIR/SKILL.md"
}

# ---------- AC2: Bundled template ----------

@test "E28-S100: brainstorming-template.md exists in skill directory" {
  [ -f "$SKILL_DIR/brainstorming-template.md" ]
}

@test "E28-S100: brainstorming-template.md is non-empty" {
  [ -s "$SKILL_DIR/brainstorming-template.md" ]
}

@test "E28-S100: brainstorming-template.md contains Session Goal section" {
  grep -q 'Session Goal' "$SKILL_DIR/brainstorming-template.md"
}

@test "E28-S100: brainstorming-template.md contains Ideas Generated section" {
  grep -q 'Ideas Generated' "$SKILL_DIR/brainstorming-template.md"
}

@test "E28-S100: brainstorming-template.md contains Top Ideas ranking table" {
  grep -q 'Top Ideas' "$SKILL_DIR/brainstorming-template.md"
  grep -q 'Rank' "$SKILL_DIR/brainstorming-template.md"
}

# ---------- Reference frontmatter ----------

@test "E28-S100: _reference-frontmatter.md exists" {
  [ -f "$SKILL_DIR/_reference-frontmatter.md" ]
}

@test "E28-S100: _reference-frontmatter.md contains verbatim frontmatter" {
  grep -q 'name: gaia-brainstorming' "$SKILL_DIR/_reference-frontmatter.md"
  grep -q 'context: fork' "$SKILL_DIR/_reference-frontmatter.md"
}

# ---------- Linter compliance (AC3) ----------

@test "E28-S100: lint-skill-frontmatter.sh passes on gaia-brainstorming SKILL.md" {
  cd "$REPO_ROOT"
  bash .github/scripts/lint-skill-frontmatter.sh
}
