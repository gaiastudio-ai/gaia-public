#!/usr/bin/env bats
# problem-solving-parity.bats — E28-S104 parity + structure tests for
# gaia-problem-solving (converted from _gaia/creative/workflows/problem-solving/).
#
# Refs: E28-S104, FR-323, NFR-048, NFR-053, ADR-041, ADR-042 (planning gate)

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SKILLS_DIR="$REPO_ROOT/plugins/gaia/skills"
  AGENTS_DIR="$REPO_ROOT/plugins/gaia/agents"
  SKILL="gaia-problem-solving"
  SKILL_DIR="$SKILLS_DIR/$SKILL"
  SKILL_FILE="$SKILL_DIR/SKILL.md"
}

# ---------- AC4: Frontmatter conformance ----------

@test "E28-S104: problem-solving SKILL.md exists" {
  [ -f "$SKILL_FILE" ]
}

@test "E28-S104: problem-solving frontmatter has name: gaia-problem-solving" {
  head -20 "$SKILL_FILE" | grep -q '^name: gaia-problem-solving'
}

@test "E28-S104: problem-solving frontmatter has description" {
  head -20 "$SKILL_FILE" | grep -q '^description:'
}

@test "E28-S104: problem-solving frontmatter has argument-hint" {
  head -20 "$SKILL_FILE" | grep -q '^argument-hint:'
}

@test "E28-S104: problem-solving frontmatter has context: fork" {
  head -20 "$SKILL_FILE" | grep -q '^context: fork'
}

@test "E28-S104: problem-solving frontmatter allowed-tools present" {
  head -25 "$SKILL_FILE" | grep -q '^allowed-tools:'
}

# ---------- AC4: Planning gate contract preserved ----------

@test "E28-S104: problem-solving preserves Planning Gate section" {
  grep -qiE '^##.*Planning Gate' "$SKILL_FILE"
}

@test "E28-S104: problem-solving preserves plan-approve-execute contract" {
  grep -qiE 'plan.*approv|approve.*plan|wait for (user )?approval' "$SKILL_FILE"
}

# ---------- AC4: Context budget preserved (30K + six sub-budgets) ----------

@test "E28-S104: problem-solving declares 30K context budget" {
  grep -qE '30K|30000|30,000' "$SKILL_FILE"
}

@test "E28-S104: problem-solving declares stories sub-budget 8K" {
  grep -qiE 'stories.*8K|stories.*8000|8K.*stories|8000.*stories' "$SKILL_FILE"
}

@test "E28-S104: problem-solving declares architecture sub-budget 5K" {
  grep -qiE 'architecture.*5K|architecture.*5000' "$SKILL_FILE"
}

@test "E28-S104: problem-solving declares prd sub-budget 5K" {
  grep -qiE 'prd.*5K|prd.*5000' "$SKILL_FILE"
}

@test "E28-S104: problem-solving declares decision_logs sub-budget 3K" {
  grep -qiE 'decision.log.*3K|decision.log.*3000' "$SKILL_FILE"
}

@test "E28-S104: problem-solving declares codebase sub-budget 5K" {
  grep -qiE 'codebase.*5K|codebase.*5000' "$SKILL_FILE"
}

@test "E28-S104: problem-solving declares test_artifacts sub-budget 4K" {
  grep -qiE 'test.artifact.*4K|test.artifact.*4000' "$SKILL_FILE"
}

# ---------- AC4: Input patterns preserved (five SELECTIVE_LOAD patterns) ----------

@test "E28-S104: problem-solving references prd.md input" {
  grep -q 'planning-artifacts/prd.md\|{planning_artifacts}/prd.md' "$SKILL_FILE"
}

@test "E28-S104: problem-solving references architecture.md input" {
  grep -q 'architecture.md' "$SKILL_FILE"
}

@test "E28-S104: problem-solving references sprint-status input" {
  grep -q 'sprint-status' "$SKILL_FILE"
}

@test "E28-S104: problem-solving references test-plan input" {
  grep -q 'test-plan' "$SKILL_FILE"
}

@test "E28-S104: problem-solving references traceability-matrix input" {
  grep -q 'traceability' "$SKILL_FILE"
}

# ---------- AC4: Tiered resolution routing preserved ----------

@test "E28-S104: problem-solving preserves quick-fix / bug / enhancement / systemic classification" {
  grep -qi 'quick.fix' "$SKILL_FILE"
  grep -qi 'enhancement' "$SKILL_FILE"
  grep -qi 'systemic' "$SKILL_FILE"
}

@test "E28-S104: problem-solving preserves solving-methods.csv data file reference" {
  grep -q 'solving-methods.csv' "$SKILL_FILE"
}

@test "E28-S104: problem-solving references data_path template" {
  grep -qE '\{data_path\}' "$SKILL_FILE"
}

# ---------- AC4: Subagent delegation preserved ----------

@test "E28-S104: problem-solving references Nova subagent" {
  grep -q 'Nova' "$SKILL_FILE"
}

@test "E28-S104: problem-solving references problem-solver subagent" {
  grep -q 'problem-solver' "$SKILL_FILE"
}

# ---------- AC4: Output contract preserved ----------

@test "E28-S104: problem-solving references output path docs/creative-artifacts/problem-solving-" {
  grep -q 'docs/creative-artifacts/problem-solving-' "$SKILL_FILE"
}

@test "E28-S104: problem-solving references date-suffixed output filename" {
  grep -qE 'problem-solving-\{date\}\.md' "$SKILL_FILE"
}

# ---------- AC-EC1: User does not approve plan → halt cleanly ----------

@test "E28-S104: problem-solving handles AC-EC1 — plan not approved → no artifact written" {
  grep -qiE 'not approved|plan.*halt|halt.*planning gate|does not approve' "$SKILL_FILE"
}

# ---------- AC-EC2: Missing subagent fails fast ----------

@test "E28-S104: problem-solving handles AC-EC2 — missing required subagent" {
  grep -qiE 'required subagent.*not.*found|subagent.*missing|not installed' "$SKILL_FILE"
}

# ---------- AC-EC3: Missing data file → actionable error ----------

@test "E28-S104: problem-solving handles AC-EC3 — missing solving-methods.csv" {
  grep -qiE 'missing data file|solving-methods.csv.*(missing|not found|unreadable)|data file.*not.*found' "$SKILL_FILE"
}

# ---------- AC5: Linter compliance ----------

@test "E28-S104: lint-skill-frontmatter.sh passes on gaia-problem-solving SKILL.md" {
  cd "$REPO_ROOT"
  bash .github/scripts/lint-skill-frontmatter.sh
}

# ---------- Layout constraints ----------

@test "E28-S104: gaia-problem-solving/ has no workflow.yaml" {
  [ ! -f "$SKILL_DIR/workflow.yaml" ]
}

@test "E28-S104: gaia-problem-solving/ has no instructions.xml" {
  [ ! -f "$SKILL_DIR/instructions.xml" ]
}

# ---------- Legacy path zero references ----------

@test "E28-S104: problem-solving SKILL.md does NOT reference legacy _gaia/creative/workflows/ in body" {
  body=$(awk '/^## References/ { in_refs = 1 } !in_refs { print }' "$SKILL_FILE")
  ! echo "$body" | grep -q '_gaia/creative/workflows/problem-solving'
}

@test "E28-S104: problem-solving SKILL.md does NOT reference invoke-workflow tag" {
  ! grep -q 'invoke-workflow' "$SKILL_FILE"
}
