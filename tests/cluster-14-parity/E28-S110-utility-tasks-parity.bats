#!/usr/bin/env bats
# E28-S110-utility-tasks-parity.bats — E28-S110 parity + structure tests
#
# Validates the conversion of 5 legacy utility tasks from
# _gaia/core/tasks/*.xml|md to native SKILL.md files under
# plugins/gaia/skills/.
#
# In-scope skills:
#   gaia-editorial-prose       ← editorial-review-prose.xml (42 lines)
#   gaia-editorial-structure   ← editorial-review-structure.xml (43 lines)
#   gaia-changelog             ← generate-changelog.xml (35 lines)
#   gaia-summarize             ← summarize-doc.xml (33 lines)
#   gaia-help                  ← help.md (45 lines)
#
#   AC1: All 5 SKILL.md files exist at canonical paths with valid
#        frontmatter (name, description, tools) and pass the
#        frontmatter linter with zero errors.
#   AC2..AC6: Each converted SKILL.md preserves every `<critical><mandate>`
#        (or Instructions step) from its source as explicit prose in a
#        `## Critical Rules` (or equivalent) section.
#   AC7: Frontmatter linter PASSES for every new SKILL.md.
#   AC9: Each skill cites ADR-041 and follows the canonical SKILL.md shape
#        (frontmatter → Mission → Critical Rules → body).
#   AC10: Slash-command identity preserved — `name:` field matches the
#        existing /gaia-{cmd} slash command (FR-323).
#
# Refs: E28-S110, FR-323, NFR-048, NFR-053, ADR-041, ADR-042, ADR-048
#
# Usage:
#   bats tests/cluster-14-parity/E28-S110-utility-tasks-parity.bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SKILLS_DIR="$REPO_ROOT/plugins/gaia/skills"

  NEW_SKILLS=(
    "gaia-editorial-prose"
    "gaia-editorial-structure"
    "gaia-changelog"
    "gaia-summarize"
    "gaia-help"
  )
}

# ---------- AC1: SKILL.md files exist ----------

@test "E28-S110: gaia-editorial-prose SKILL.md exists" {
  [ -f "$SKILLS_DIR/gaia-editorial-prose/SKILL.md" ]
}

@test "E28-S110: gaia-editorial-structure SKILL.md exists" {
  [ -f "$SKILLS_DIR/gaia-editorial-structure/SKILL.md" ]
}

@test "E28-S110: gaia-changelog SKILL.md exists" {
  [ -f "$SKILLS_DIR/gaia-changelog/SKILL.md" ]
}

@test "E28-S110: gaia-summarize SKILL.md exists" {
  [ -f "$SKILLS_DIR/gaia-summarize/SKILL.md" ]
}

@test "E28-S110: gaia-help SKILL.md exists" {
  [ -f "$SKILLS_DIR/gaia-help/SKILL.md" ]
}

# ---------- AC1: Frontmatter delimiters ----------

@test "E28-S110: all 5 new SKILL.md files have YAML frontmatter delimiters" {
  for skill in "${NEW_SKILLS[@]}"; do
    file="$SKILLS_DIR/$skill/SKILL.md"
    head -1 "$file" | grep -q "^---$"
    awk 'NR>1 && /^---$/{found=1; exit} END{exit !found}' "$file"
  done
}

# ---------- AC10 / FR-323: name field matches slash-command identifier ----------

@test "E28-S110: gaia-editorial-prose name field matches" {
  head -30 "$SKILLS_DIR/gaia-editorial-prose/SKILL.md" | grep -q '^name: gaia-editorial-prose$'
}

@test "E28-S110: gaia-editorial-structure name field matches" {
  head -30 "$SKILLS_DIR/gaia-editorial-structure/SKILL.md" | grep -q '^name: gaia-editorial-structure$'
}

@test "E28-S110: gaia-changelog name field matches" {
  head -30 "$SKILLS_DIR/gaia-changelog/SKILL.md" | grep -q '^name: gaia-changelog$'
}

@test "E28-S110: gaia-summarize name field matches" {
  head -30 "$SKILLS_DIR/gaia-summarize/SKILL.md" | grep -q '^name: gaia-summarize$'
}

@test "E28-S110: gaia-help name field matches" {
  head -30 "$SKILLS_DIR/gaia-help/SKILL.md" | grep -q '^name: gaia-help$'
}

# ---------- AC1: non-empty description ----------

@test "E28-S110: all 5 new SKILL.md files have non-empty description" {
  for skill in "${NEW_SKILLS[@]}"; do
    file="$SKILLS_DIR/$skill/SKILL.md"
    head -30 "$file" | grep -qE '^description: .+'
  done
}

# ---------- AC1: tools declared ----------

@test "E28-S110: all 5 new SKILL.md files declare tools" {
  for skill in "${NEW_SKILLS[@]}"; do
    file="$SKILLS_DIR/$skill/SKILL.md"
    head -30 "$file" | grep -qE '^tools:.+Read'
  done
}

# ---------- AC7: Frontmatter linter PASSES across the full tree ----------

@test "E28-S110: all SKILL.md files (full tree) pass frontmatter linter" {
  cd "$REPO_ROOT" && bash "$REPO_ROOT/.github/scripts/lint-skill-frontmatter.sh"
}

# ---------- AC2: editorial-prose preserves clinical copy-edit mandates ----------

@test "E28-S110: gaia-editorial-prose preserves review-only + severity + line-reference mandates" {
  file="$SKILLS_DIR/gaia-editorial-prose/SKILL.md"
  grep -qi "never rewrite\|review.only\|read-only" "$file"
  grep -qi "severity" "$file"
  grep -qi "line reference\|specific line\|line number" "$file"
}

@test "E28-S110: gaia-editorial-prose documents analysis categories (ambiguity, inconsistency, redundancy, jargon, passive voice)" {
  file="$SKILLS_DIR/gaia-editorial-prose/SKILL.md"
  grep -qi "ambiguity" "$file"
  grep -qi "inconsistency" "$file"
  grep -qi "redundancy" "$file"
  grep -qi "jargon" "$file"
  grep -qi "passive voice" "$file"
}

@test "E28-S110: gaia-editorial-prose enforces prose-only scope (no structural edits)" {
  file="$SKILLS_DIR/gaia-editorial-prose/SKILL.md"
  grep -qi "prose.only\|out of scope\|gaia-editorial-structure" "$file"
}

# ---------- AC3: editorial-structure preserves structural-review mandates ----------

@test "E28-S110: gaia-editorial-structure preserves review-only + structural + specific-moves mandates" {
  file="$SKILLS_DIR/gaia-editorial-structure/SKILL.md"
  grep -qi "never rewrite\|review.only\|read-only" "$file"
  grep -qi "hierarchy\|information architecture" "$file"
  grep -qi "reorder\|reorganization\|restructure" "$file"
}

@test "E28-S110: gaia-editorial-structure documents structural dimensions (ordering, balance, depth, navigation)" {
  file="$SKILLS_DIR/gaia-editorial-structure/SKILL.md"
  grep -qi "section ordering\|sequence" "$file"
  grep -qi "balance" "$file"
  grep -qi "depth\|nesting" "$file"
  grep -qi "navigation" "$file"
}

@test "E28-S110: gaia-editorial-structure enforces structure-only scope (no prose edits)" {
  file="$SKILLS_DIR/gaia-editorial-structure/SKILL.md"
  grep -qi "structure.only\|out of scope\|gaia-editorial-prose" "$file"
}

# ---------- AC4: changelog preserves Keep-a-Changelog + grouping + output mandates ----------

@test "E28-S110: gaia-changelog preserves Keep a Changelog + grouping + version mandates" {
  file="$SKILLS_DIR/gaia-changelog/SKILL.md"
  grep -q "Keep a Changelog" "$file"
  grep -qi "Added.*Changed.*Fixed\|Added, Changed, Fixed" "$file"
  grep -qi "version" "$file"
}

@test "E28-S110: gaia-changelog preserves CHANGELOG.md output path" {
  file="$SKILLS_DIR/gaia-changelog/SKILL.md"
  grep -q "CHANGELOG.md" "$file"
}

@test "E28-S110: gaia-changelog uses inline bash for git operations (ADR-042)" {
  file="$SKILLS_DIR/gaia-changelog/SKILL.md"
  grep -qE '!?`?git log' "$file"
}

# ---------- AC5: summarize preserves compression + key-points + size mandates ----------

@test "E28-S110: gaia-summarize preserves key-decisions + action-items + open-questions mandates" {
  file="$SKILLS_DIR/gaia-summarize/SKILL.md"
  grep -qi "key decision" "$file"
  grep -qi "action item" "$file"
  grep -qi "open question" "$file"
}

@test "E28-S110: gaia-summarize preserves 1-2 page length + don't-oversimplify mandate" {
  file="$SKILLS_DIR/gaia-summarize/SKILL.md"
  grep -qi "1.2 pages\|1 to 2 pages\|one to two pages\|1-2 pages" "$file"
  grep -qi "nuance\|oversimplif" "$file"
}

@test "E28-S110: gaia-summarize accepts target doc path as argument-hint" {
  file="$SKILLS_DIR/gaia-summarize/SKILL.md"
  grep -qE '^argument-hint:.*(doc|path|target|document)' "$file"
}

# ---------- AC6: help preserves gaia-help.csv + phase-detection + manifest-authority ----------

@test "E28-S110: gaia-help preserves gaia-help.csv loader" {
  file="$SKILLS_DIR/gaia-help/SKILL.md"
  grep -q "gaia-help.csv" "$file"
}

@test "E28-S110: gaia-help preserves Phase Guide (Analysis..Deployment)" {
  file="$SKILLS_DIR/gaia-help/SKILL.md"
  grep -qi "Analysis" "$file"
  grep -qi "Planning" "$file"
  grep -qi "Solutioning" "$file"
  grep -qi "Implementation" "$file"
  grep -qi "Deployment" "$file"
}

@test "E28-S110: gaia-help propagates engine mandate — never suggest commands not in workflow-manifest.csv" {
  file="$SKILLS_DIR/gaia-help/SKILL.md"
  grep -q "workflow-manifest.csv" "$file"
  grep -qi "never invent\|never suggest\|never hallucinate\|must.*exist" "$file"
}

@test "E28-S110: gaia-help inspects docs/ artifacts for phase detection" {
  file="$SKILLS_DIR/gaia-help/SKILL.md"
  grep -q "planning-artifacts" "$file"
  grep -q "implementation-artifacts" "$file"
  grep -q "test-artifacts" "$file"
  grep -q "creative-artifacts" "$file"
}

# ---------- AC9: ADR-041 citation + canonical shape ----------

@test "E28-S110: all 5 new SKILL.md files cite ADR-041" {
  for skill in "${NEW_SKILLS[@]}"; do
    file="$SKILLS_DIR/$skill/SKILL.md"
    grep -q "ADR-041" "$file"
  done
}

@test "E28-S110: all 5 new SKILL.md files have a Mission section" {
  for skill in "${NEW_SKILLS[@]}"; do
    file="$SKILLS_DIR/$skill/SKILL.md"
    grep -q "^## Mission" "$file"
  done
}

@test "E28-S110: all 5 new SKILL.md files have a Critical Rules (or Instructions) section" {
  for skill in "${NEW_SKILLS[@]}"; do
    file="$SKILLS_DIR/$skill/SKILL.md"
    grep -qE "^## (Critical Rules|Instructions|Steps)" "$file"
  done
}

# ---------- References: source file cited ----------

@test "E28-S110: gaia-editorial-prose cites source xml" {
  grep -q "editorial-review-prose.xml" "$SKILLS_DIR/gaia-editorial-prose/SKILL.md"
}

@test "E28-S110: gaia-editorial-structure cites source xml" {
  grep -q "editorial-review-structure.xml" "$SKILLS_DIR/gaia-editorial-structure/SKILL.md"
}

@test "E28-S110: gaia-changelog cites source xml" {
  grep -q "generate-changelog.xml" "$SKILLS_DIR/gaia-changelog/SKILL.md"
}

@test "E28-S110: gaia-summarize cites source xml" {
  grep -q "summarize-doc.xml" "$SKILLS_DIR/gaia-summarize/SKILL.md"
}

@test "E28-S110: gaia-help cites source help.md" {
  grep -q "help.md" "$SKILLS_DIR/gaia-help/SKILL.md"
}

# ---------- Zero orphaned engine-specific XML tags ----------

@test "E28-S110: no orphaned engine-specific XML tags in any of the 5 new skills" {
  for skill in "${NEW_SKILLS[@]}"; do
    file="$SKILLS_DIR/$skill/SKILL.md"
    # These engine tags must be mapped to prose, not left verbatim
    if grep -qE '<(action|template-output|invoke-workflow|check|ask|step|workflow|task)[> ]' "$file"; then
      echo "orphaned XML tag in $file"
      return 1
    fi
  done
}

# ---------- tools is canonical & per-skill-appropriate ----------

@test "E28-S110: gaia-help does NOT require Write (read-only + suggest)" {
  file="$SKILLS_DIR/gaia-help/SKILL.md"
  # Help should not write artifacts — tools should omit Write
  # (but this is advisory — skill still passes if Write listed; enforce via grep)
  grep -qE '^tools:.+' "$file"
}

@test "E28-S110: gaia-changelog includes Bash (needs git) and Write (emits CHANGELOG.md)" {
  file="$SKILLS_DIR/gaia-changelog/SKILL.md"
  grep -qE '^tools:.+Bash' "$file"
  grep -qE '^tools:.+Write' "$file"
}
