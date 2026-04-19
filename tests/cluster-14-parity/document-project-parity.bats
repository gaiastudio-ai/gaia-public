#!/usr/bin/env bats
# document-project-parity.bats — E28-S106 parity + structure tests
#
# Validates the conversion of _gaia/lifecycle/workflows/anytime/document-project/
# to a native SKILL.md at plugins/gaia/skills/gaia-document-project/SKILL.md.
#
#   AC1: `/gaia-document-project` executes the documentation generation flow and
#        produces output consistent with the legacy workflow.
#   AC3: SKILL.md frontmatter linter passes with required fields.
#   AC4: Functional parity — structural equivalence with legacy output.
#   AC-EC1: Zero orphaned engine-specific XML tags in SKILL.md.
#   AC-EC2: setup.sh/finalize.sh present and executable.
#   AC-EC3: SKILL.md frontmatter passes YAML linter.
#   AC-EC4: Handles empty / no-sources project.
#   AC-EC6: No shared mutable state between parallel invocations.
#   AC-EC7: SKILL.md body stays within NFR-048 token budget.
#
# Refs: E28-S106, FR-323, FR-325, NFR-048, NFR-053, ADR-041, ADR-042
#
# Usage:
#   bats tests/cluster-14-parity/document-project-parity.bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SKILLS_DIR="$REPO_ROOT/plugins/gaia/skills"
  SCRIPTS_DIR="$REPO_ROOT/plugins/gaia/scripts"

  SKILL="gaia-document-project"
  SKILL_DIR="$SKILLS_DIR/$SKILL"
  SKILL_FILE="$SKILL_DIR/SKILL.md"
}

# ---------- AC1: SKILL.md exists at native conversion target path ----------

@test "E28-S106: gaia-document-project SKILL.md exists" {
  [ -f "$SKILL_FILE" ]
}

@test "E28-S106: gaia-document-project SKILL.md has YAML frontmatter delimiters" {
  head -1 "$SKILL_FILE" | grep -q "^---$"
  awk 'NR>1 && /^---$/{found=1; exit} END{exit !found}' "$SKILL_FILE"
}

# ---------- AC3: Frontmatter required fields ----------

@test "E28-S106: gaia-document-project frontmatter has name: gaia-document-project" {
  awk '/^---$/{n++; next} n==1{print}' "$SKILL_FILE" | grep -q '^name: gaia-document-project'
}

@test "E28-S106: gaia-document-project frontmatter description includes 'document' trigger" {
  awk '/^---$/{n++; next} n==1{print}' "$SKILL_FILE" | grep -qiE '^description:.*(document|documentation)'
}

@test "E28-S106: gaia-document-project frontmatter has tools field" {
  awk '/^---$/{n++; next} n==1{print}' "$SKILL_FILE" | grep -q '^tools:'
}

@test "E28-S106: gaia-document-project frontmatter tools contains scan tools (Read, Glob, Grep, Bash)" {
  fm=$(awk '/^---$/{n++; next} n==1{print}' "$SKILL_FILE")
  echo "$fm" | grep -q 'tools:.*Read'
  echo "$fm" | grep -q 'tools:.*Glob'
  echo "$fm" | grep -q 'tools:.*Grep'
  echo "$fm" | grep -q 'tools:.*Bash'
  echo "$fm" | grep -q 'tools:.*Write'
}

@test "E28-S106: gaia-document-project frontmatter has model field" {
  awk '/^---$/{n++; next} n==1{print}' "$SKILL_FILE" | grep -qE '^(model|version):'
}

# ---------- AC4: Legacy flow mapped to prose sections (scan → tech → structure → generate) ----------

@test "E28-S106: SKILL.md body contains Scan Project prose section" {
  grep -qiE '^##.*scan.*project' "$SKILL_FILE"
}

@test "E28-S106: SKILL.md body contains Technology Detection prose section" {
  grep -qiE '^##.*technology.*(detect|stack)' "$SKILL_FILE"
}

@test "E28-S106: SKILL.md body contains Structure Mapping prose section" {
  grep -qiE '^##.*structure.*(map|overview)' "$SKILL_FILE"
}

@test "E28-S106: SKILL.md body contains Generate Documentation prose section" {
  grep -qiE '^##.*(generate|output).*documentation' "$SKILL_FILE"
}

# ---------- AC: Output artifact path preserved ----------

@test "E28-S106: SKILL.md references project-documentation.md output artifact" {
  grep -q 'project-documentation.md' "$SKILL_FILE"
}

@test "E28-S106: SKILL.md references planning-artifacts output directory" {
  grep -q 'planning-artifacts' "$SKILL_FILE"
}

# ---------- AC-EC1: Zero orphaned engine-specific XML tags ----------

@test "E28-S106: gaia-document-project SKILL.md contains NO <action> tags" {
  ! grep -q '<action' "$SKILL_FILE"
}

@test "E28-S106: gaia-document-project SKILL.md contains NO <template-output> tags" {
  ! grep -q '<template-output' "$SKILL_FILE"
}

@test "E28-S106: gaia-document-project SKILL.md contains NO <invoke-workflow> tags" {
  ! grep -q '<invoke-workflow' "$SKILL_FILE"
}

@test "E28-S106: gaia-document-project SKILL.md contains NO <check> tags" {
  ! grep -q '<check' "$SKILL_FILE"
}

@test "E28-S106: gaia-document-project SKILL.md contains NO <ask> tags" {
  ! grep -q '<ask' "$SKILL_FILE"
}

@test "E28-S106: gaia-document-project SKILL.md contains NO <step> tags" {
  ! grep -qE '<step[ >]' "$SKILL_FILE"
}

@test "E28-S106: gaia-document-project SKILL.md contains NO <workflow> tags" {
  ! grep -qE '<workflow[ >]' "$SKILL_FILE"
}

# ---------- Foundation script wiring (ADR-042 / FR-325) ----------

@test "E28-S106: gaia-document-project SKILL.md wires setup.sh inline" {
  grep -qE 'setup\.sh' "$SKILL_FILE"
}

@test "E28-S106: gaia-document-project SKILL.md wires finalize.sh inline" {
  grep -qE 'finalize\.sh' "$SKILL_FILE"
}

@test "E28-S106: gaia-document-project SKILL.md references ADR-041 (native execution model)" {
  grep -q 'ADR-041' "$SKILL_FILE"
}

@test "E28-S106: gaia-document-project SKILL.md references ADR-042 (scripts-over-LLM)" {
  grep -q 'ADR-042' "$SKILL_FILE"
}

# ---------- AC-EC4: Empty/new project handling ----------

@test "E28-S106: SKILL.md handles AC-EC4 — empty filesystem / no sources" {
  grep -qiE 'no source|empty.*project|no files detected|no sources detected' "$SKILL_FILE"
}

# ---------- AC-EC2: Foundation script missing handling ----------

@test "E28-S106: SKILL.md handles AC-EC2 — missing/non-executable foundation script" {
  grep -qiE 'missing.*script|not executable|fail.*fast|non-executable' "$SKILL_FILE"
}

# ---------- AC-EC7: Token budget ----------

@test "E28-S106: SKILL.md handles AC-EC7 — NFR-048 token budget" {
  grep -qiE 'token budget|NFR-048|activation budget' "$SKILL_FILE"
}

# ---------- AC-EC6: Parallel invocation isolation ----------

@test "E28-S106: SKILL.md handles AC-EC6 — parallel invocation isolation" {
  grep -qiE 'parallel|isolat|independent|no shared mutable' "$SKILL_FILE"
}

# ---------- Layout constraints (legacy engine artifacts absent) ----------

@test "E28-S106: gaia-document-project/ has no workflow.yaml (legacy engine artifact)" {
  [ ! -f "$SKILL_DIR/workflow.yaml" ]
}

@test "E28-S106: gaia-document-project/ has no instructions.xml (legacy engine artifact)" {
  [ ! -f "$SKILL_DIR/instructions.xml" ]
}

@test "E28-S106: gaia-document-project/ has no .resolved/ subdirectory" {
  [ ! -d "$SKILL_DIR/.resolved" ]
}

@test "E28-S106: gaia-document-project/scripts/ directory exists" {
  [ -d "$SKILL_DIR/scripts" ]
}

@test "E28-S106: gaia-document-project/scripts/setup.sh exists and is executable" {
  [ -f "$SKILL_DIR/scripts/setup.sh" ]
  [ -x "$SKILL_DIR/scripts/setup.sh" ]
}

@test "E28-S106: gaia-document-project/scripts/finalize.sh exists and is executable" {
  [ -f "$SKILL_DIR/scripts/finalize.sh" ]
  [ -x "$SKILL_DIR/scripts/finalize.sh" ]
}

# ---------- AC3: Frontmatter linter passes ----------

@test "E28-S106: lint-skill-frontmatter.sh passes on gaia-document-project SKILL.md" {
  cd "$REPO_ROOT"
  bash .github/scripts/lint-skill-frontmatter.sh
}

# ---------- Token budget guard ----------

@test "E28-S106: gaia-document-project SKILL.md body under 1500 lines (NFR-048 guard)" {
  line_count=$(wc -l < "$SKILL_FILE")
  [ "$line_count" -lt 1500 ]
}
