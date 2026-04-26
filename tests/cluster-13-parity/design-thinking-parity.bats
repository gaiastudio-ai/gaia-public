#!/usr/bin/env bats
# design-thinking-parity.bats — E47-S1 parity + structure tests for
# gaia-design-thinking (new native skill restoring V1 /gaia-design-thinking
# under ADR-065).
#
# Refs: E47-S1, FR-360, ADR-041, ADR-042, ADR-045, ADR-063, ADR-065, ADR-067,
#       NFR-046, NFR-053
#
# Shell idioms: the `awk '/^## References/ { in_refs = 1 } !in_refs { print }'`
# pattern used below for trailing-section removal follows the state-machine
# convention codified in `gaia-shell-idioms`. Do NOT rewrite as
# `awk '/^## References/,0'` — see the skill for why that idiom fails when
# start and end patterns can match the same line.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SKILLS_DIR="$REPO_ROOT/plugins/gaia/skills"
  AGENTS_DIR="$REPO_ROOT/plugins/gaia/agents"
  KNOWLEDGE_DIR="$REPO_ROOT/plugins/gaia/knowledge"
  SKILL="gaia-design-thinking"
  SKILL_DIR="$SKILLS_DIR/$SKILL"
  SKILL_FILE="$SKILL_DIR/SKILL.md"
  CSV_FILE="$KNOWLEDGE_DIR/design-methods.csv"
}

# ---------- AC1, AC7: SKILL.md exists with valid frontmatter ----------

@test "E47-S1: design-thinking SKILL.md exists" {
  [ -f "$SKILL_FILE" ]
}

@test "E47-S1: design-thinking frontmatter has name: gaia-design-thinking" {
  head -20 "$SKILL_FILE" | grep -q '^name: gaia-design-thinking'
}

@test "E47-S1: design-thinking frontmatter has description" {
  head -20 "$SKILL_FILE" | grep -q '^description:'
}

@test "E47-S1: design-thinking frontmatter has argument-hint" {
  head -20 "$SKILL_FILE" | grep -q '^argument-hint:'
}

@test "E47-S1: design-thinking frontmatter has context: fork" {
  head -20 "$SKILL_FILE" | grep -q '^context: fork'
}

@test "E47-S1: design-thinking frontmatter allowed-tools includes Agent" {
  head -20 "$SKILL_FILE" | grep -q '^allowed-tools:.*Agent'
}

# ---------- AC1: 5-phase pipeline preserved ----------

@test "E47-S1: design-thinking declares Phase 1 Empathize" {
  grep -qE '^## Phase 1.*Empathize|^### Phase 1.*Empathize' "$SKILL_FILE"
}

@test "E47-S1: design-thinking declares Phase 2 Define" {
  grep -qE '^## Phase 2.*Define|^### Phase 2.*Define' "$SKILL_FILE"
}

@test "E47-S1: design-thinking declares Phase 3 Ideate" {
  grep -qE '^## Phase 3.*Ideate|^### Phase 3.*Ideate' "$SKILL_FILE"
}

@test "E47-S1: design-thinking declares Phase 4 Prototype" {
  grep -qE '^## Phase 4.*Prototype|^### Phase 4.*Prototype' "$SKILL_FILE"
}

@test "E47-S1: design-thinking declares Phase 5 Test" {
  grep -qE '^## Phase 5.*Test|^### Phase 5.*Test' "$SKILL_FILE"
}

# ---------- AC2: V1 PoV template preserved ----------

@test "E47-S1: design-thinking preserves V1 PoV template (User... needs... because...)" {
  grep -qE 'User.*needs.*because' "$SKILL_FILE"
}

# ---------- AC3: How-Might-We minimum ----------

@test "E47-S1: design-thinking mandates >=3 How-Might-We questions" {
  grep -qiE 'how[- ]might[- ]we|HMW' "$SKILL_FILE"
  grep -qE '(at least|minimum|>=|≥)\s*3.*(HMW|How-Might-We|how might we)' "$SKILL_FILE" \
    || grep -qE '3.*(HMW questions|how-might-we questions|how might we questions)' "$SKILL_FILE"
}

# ---------- AC4: minimum 10 ideas mandate ----------

@test "E47-S1: design-thinking mandates minimum 10 ideas before convergence" {
  grep -qE '(at least|minimum|>=|≥|min(\.|imum)?)\s*(of\s*)?10\s*ideas|10\+\s*ideas|>=\s*10\s*ideas|≥\s*10\s*ideas' "$SKILL_FILE"
}

# ---------- AC5: design-methods CSV reference ----------

@test "E47-S1: design-thinking references design-methods.csv" {
  grep -q 'design-methods.csv' "$SKILL_FILE"
}

@test "E47-S1: design-thinking uses CLAUDE_PLUGIN_ROOT path for CSV (no legacy {data_path})" {
  grep -qE '\$\{?CLAUDE_PLUGIN_ROOT\}?/knowledge/design-methods\.csv' "$SKILL_FILE"
}

@test "E47-S1: design-thinking does NOT reference legacy {data_path}/design-methods.csv" {
  ! grep -qE '\{data_path\}/design-methods\.csv' "$SKILL_FILE"
}

# ---------- AC6: output artifact path ----------

@test "E47-S1: design-thinking output path is docs/creative-artifacts/design-thinking-{date}.md" {
  grep -qE 'docs/creative-artifacts/design-thinking-\{date\}\.md' "$SKILL_FILE"
}

# ---------- ADR-063: Subagent Dispatch Contract section ----------

@test "E47-S1: design-thinking includes Subagent Dispatch Contract section" {
  grep -qE '^## Subagent Dispatch Contract|^### Subagent Dispatch Contract' "$SKILL_FILE"
}

@test "E47-S1: design-thinking surfaces verdict (PASS/WARNING/CRITICAL)" {
  grep -q 'CRITICAL' "$SKILL_FILE"
  grep -q 'WARNING' "$SKILL_FILE"
  grep -qE 'PASS|status' "$SKILL_FILE"
}

@test "E47-S1: design-thinking codifies halt-on-CRITICAL behavior" {
  grep -qiE 'halt.*CRITICAL|CRITICAL.*halt' "$SKILL_FILE"
}

@test "E47-S1: design-thinking references ADR-037 structured return schema" {
  grep -q 'ADR-037' "$SKILL_FILE"
}

# ---------- ADR-067: YOLO Behavior section ----------

@test "E47-S1: design-thinking includes YOLO Behavior section" {
  grep -qE '^## YOLO Behavior|^### YOLO Behavior|^## YOLO Mode|^### YOLO Mode' "$SKILL_FILE"
}

@test "E47-S1: design-thinking codifies auto-confirm template-output in YOLO" {
  grep -qiE 'auto[- ]confirm.*template[- ]output|template[- ]output.*auto[- ]continue|auto[- ]continue.*template[- ]output' "$SKILL_FILE"
}

@test "E47-S1: design-thinking codifies never-auto-skip open questions in YOLO" {
  grep -qiE 'never auto[- ]skip.*open[- ]question|open[- ]question.*require human|never.*auto[- ]answer' "$SKILL_FILE"
}

# ---------- AC1: Lyra subagent delegation ----------

@test "E47-S1: design-thinking references Lyra by name" {
  grep -q 'Lyra' "$SKILL_FILE"
}

@test "E47-S1: design-thinking references design-thinking-coach subagent" {
  grep -q 'design-thinking-coach' "$SKILL_FILE"
}

@test "E47-S1: design-thinking uses context: fork pattern" {
  grep -qE 'context: fork|context:fork|`context: fork`' "$SKILL_FILE"
}

# ---------- ADR refs and traceability ----------

@test "E47-S1: design-thinking references ADR-041 (Native Execution)" {
  grep -q 'ADR-041' "$SKILL_FILE"
}

@test "E47-S1: design-thinking references ADR-042 (Scripts-over-LLM)" {
  grep -q 'ADR-042' "$SKILL_FILE"
}

@test "E47-S1: design-thinking references ADR-063 (Subagent Dispatch Contract)" {
  grep -q 'ADR-063' "$SKILL_FILE"
}

@test "E47-S1: design-thinking references ADR-065 (New Skills Wiring)" {
  grep -q 'ADR-065' "$SKILL_FILE"
}

@test "E47-S1: design-thinking references ADR-067 (YOLO Mode Contract)" {
  grep -q 'ADR-067' "$SKILL_FILE"
}

# ---------- AC5: design-methods.csv exists in plugin knowledge dir ----------

@test "E47-S1: design-methods.csv exists in plugin knowledge directory" {
  [ -f "$CSV_FILE" ]
}

@test "E47-S1: design-methods.csv has expected header columns" {
  head -1 "$CSV_FILE" | grep -qE 'method_id.*name.*category.*phase'
}

@test "E47-S1: design-methods.csv contains empathy methods" {
  grep -qE '"em-0[0-9]"' "$CSV_FILE"
}

@test "E47-S1: design-methods.csv contains define methods" {
  grep -qE '"df-0[0-9]"' "$CSV_FILE"
}

# ---------- Linter compliance ----------

@test "E47-S1: lint-skill-frontmatter.sh passes on gaia-design-thinking SKILL.md" {
  cd "$REPO_ROOT"
  bash .github/scripts/lint-skill-frontmatter.sh
}

# ---------- Layout constraints ----------

@test "E47-S1: gaia-design-thinking/ has no workflow.yaml (native skill)" {
  [ ! -f "$SKILL_DIR/workflow.yaml" ]
}

@test "E47-S1: gaia-design-thinking/ has no instructions.xml (native skill)" {
  [ ! -f "$SKILL_DIR/instructions.xml" ]
}

# ---------- Subagent registration ----------

@test "E47-S1: required subagent design-thinking-coach exists" {
  [ -f "$AGENTS_DIR/design-thinking-coach.md" ]
}
