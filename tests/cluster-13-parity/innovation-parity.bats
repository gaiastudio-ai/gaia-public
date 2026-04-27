#!/usr/bin/env bats
# innovation-parity.bats — E47-S2 parity + structure tests for
# gaia-innovation (new native skill restoring V1 /gaia-innovation
# under ADR-065).
#
# Refs: E47-S2, FR-361, ADR-041, ADR-042, ADR-045, ADR-063, ADR-065, ADR-067,
#       NFR-046, NFR-053
#
# Mirrors design-thinking-parity.bats (E47-S1). Innovation pipeline phases:
# Market Context → JTBD → Blue Ocean/ERRC → Business Model → Strategic Roadmap.
# V1 templates preserved: JTBD (with non-consumer identification), ERRC grid,
# Business Model Canvas (BMC), Value Proposition Canvas (VPC), beachhead
# market identification (TAM/SAM/SOM), tech-adoption-lifecycle mapping.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SKILLS_DIR="$REPO_ROOT/plugins/gaia/skills"
  AGENTS_DIR="$REPO_ROOT/plugins/gaia/agents"
  KNOWLEDGE_DIR="$REPO_ROOT/plugins/gaia/knowledge"
  SKILL="gaia-innovation"
  SKILL_DIR="$SKILLS_DIR/$SKILL"
  SKILL_FILE="$SKILL_DIR/SKILL.md"
  CSV_FILE="$KNOWLEDGE_DIR/innovation-frameworks.csv"
}

# ---------- AC1, AC7: SKILL.md exists with valid frontmatter ----------

@test "E47-S2: innovation SKILL.md exists" {
  [ -f "$SKILL_FILE" ]
}

@test "E47-S2: innovation frontmatter has name: gaia-innovation" {
  head -20 "$SKILL_FILE" | grep -q '^name: gaia-innovation'
}

@test "E47-S2: innovation frontmatter has description" {
  head -20 "$SKILL_FILE" | grep -q '^description:'
}

@test "E47-S2: innovation frontmatter has argument-hint" {
  head -20 "$SKILL_FILE" | grep -q '^argument-hint:'
}

@test "E47-S2: innovation frontmatter has context: fork" {
  head -20 "$SKILL_FILE" | grep -q '^context: fork'
}

@test "E47-S2: innovation frontmatter allowed-tools includes Agent" {
  head -20 "$SKILL_FILE" | grep -q '^allowed-tools:.*Agent'
}

# ---------- AC1-5: 5-phase pipeline preserved ----------

@test "E47-S2: innovation declares Phase 1 Market Context" {
  grep -qE '^## Phase 1.*Market Context|^### Phase 1.*Market Context' "$SKILL_FILE"
}

@test "E47-S2: innovation declares Phase 2 Jobs-to-be-Done" {
  grep -qE '^## Phase 2.*Jobs-to-be-Done|^### Phase 2.*Jobs-to-be-Done|^## Phase 2.*JTBD|^### Phase 2.*JTBD' "$SKILL_FILE"
}

@test "E47-S2: innovation declares Phase 3 Blue Ocean" {
  grep -qE '^## Phase 3.*Blue Ocean|^### Phase 3.*Blue Ocean' "$SKILL_FILE"
}

@test "E47-S2: innovation declares Phase 4 Business Model" {
  grep -qE '^## Phase 4.*Business Model|^### Phase 4.*Business Model' "$SKILL_FILE"
}

@test "E47-S2: innovation declares Phase 5 Strategic Roadmap" {
  grep -qE '^## Phase 5.*Strategic Roadmap|^### Phase 5.*Strategic Roadmap|^## Phase 5.*Roadmap|^### Phase 5.*Roadmap' "$SKILL_FILE"
}

# ---------- AC2: V1 JTBD with non-consumer identification ----------

@test "E47-S2: innovation Phase 2 includes functional/emotional/social jobs" {
  grep -qiE 'functional.*emotional.*social|emotional.*functional.*social|functional jobs.*emotional jobs.*social jobs' "$SKILL_FILE" \
    || (grep -qi 'functional jobs' "$SKILL_FILE" && grep -qi 'emotional jobs' "$SKILL_FILE" && grep -qi 'social jobs' "$SKILL_FILE")
}

@test "E47-S2: innovation Phase 2 mandates non-consumer identification" {
  grep -qiE 'non-consumer|non consumer|nonconsumer' "$SKILL_FILE"
}

# ---------- AC3: Blue Ocean strategy canvas + ERRC grid ----------

@test "E47-S2: innovation Phase 3 references strategy canvas" {
  grep -qi 'strategy canvas' "$SKILL_FILE"
}

@test "E47-S2: innovation Phase 3 includes ERRC grid (Eliminate/Reduce/Raise/Create)" {
  grep -qi 'ERRC' "$SKILL_FILE"
  grep -qi 'Eliminate' "$SKILL_FILE"
  grep -qi 'Reduce' "$SKILL_FILE"
  grep -qi 'Raise' "$SKILL_FILE"
  grep -qi 'Create' "$SKILL_FILE"
}

# ---------- AC4: Business Model Canvas (BMC) + Value Proposition Canvas (VPC) ----------

@test "E47-S2: innovation Phase 4 includes Business Model Canvas (BMC)" {
  grep -qiE 'Business Model Canvas|\bBMC\b' "$SKILL_FILE"
}

@test "E47-S2: innovation Phase 4 references all 9 BMC blocks" {
  grep -qiE '9.block|nine.block|9 blocks|nine blocks' "$SKILL_FILE"
}

@test "E47-S2: innovation Phase 4 includes Value Proposition Canvas (VPC)" {
  grep -qiE 'Value Proposition Canvas|\bVPC\b' "$SKILL_FILE"
}

@test "E47-S2: innovation Phase 4 maps jobs/pains/gains" {
  grep -qi 'jobs' "$SKILL_FILE"
  grep -qi 'pains' "$SKILL_FILE"
  grep -qi 'gains' "$SKILL_FILE"
}

@test "E47-S2: innovation Phase 4 identifies beachhead market" {
  grep -qi 'beachhead' "$SKILL_FILE"
}

# ---------- AC5: Strategic Roadmap with tech-adoption-lifecycle ----------

@test "E47-S2: innovation Phase 5 includes tech-adoption-lifecycle mapping" {
  grep -qiE 'tech.adoption.lifecycle|technology adoption lifecycle|adoption lifecycle' "$SKILL_FILE"
}

@test "E47-S2: innovation Phase 5 maps Rogers diffusion segments" {
  grep -qi 'innovators' "$SKILL_FILE"
  grep -qi 'early adopters' "$SKILL_FILE"
  grep -qiE 'early majority|late majority' "$SKILL_FILE"
  grep -qi 'laggards' "$SKILL_FILE"
}

# ---------- AC4/AC5: innovation-frameworks.csv reference (ADR-065 plugin-local) ----------

@test "E47-S2: innovation references innovation-frameworks.csv" {
  grep -q 'innovation-frameworks.csv' "$SKILL_FILE"
}

@test "E47-S2: innovation uses CLAUDE_PLUGIN_ROOT path for CSV (no legacy {data_path})" {
  grep -qE '\$\{?CLAUDE_PLUGIN_ROOT\}?/knowledge/innovation-frameworks\.csv' "$SKILL_FILE"
}

@test "E47-S2: innovation does NOT reference legacy {data_path}/innovation-frameworks.csv" {
  ! grep -qE '\{data_path\}/innovation-frameworks\.csv' "$SKILL_FILE"
}

# ---------- AC6: output artifact path ----------

@test "E47-S2: innovation output path is docs/creative-artifacts/innovation-strategy-{date}.md" {
  grep -qE 'docs/creative-artifacts/innovation-strategy-\{date\}\.md' "$SKILL_FILE"
}

# ---------- ADR-063: Subagent Dispatch Contract section ----------

@test "E47-S2: innovation includes Subagent Dispatch Contract section" {
  grep -qE '^## Subagent Dispatch Contract|^### Subagent Dispatch Contract' "$SKILL_FILE"
}

@test "E47-S2: innovation surfaces verdict (PASS/WARNING/CRITICAL)" {
  grep -q 'CRITICAL' "$SKILL_FILE"
  grep -q 'WARNING' "$SKILL_FILE"
  grep -qE 'PASS|status' "$SKILL_FILE"
}

@test "E47-S2: innovation codifies halt-on-CRITICAL behavior" {
  grep -qiE 'halt.*CRITICAL|CRITICAL.*halt' "$SKILL_FILE"
}

@test "E47-S2: innovation references ADR-037 structured return schema" {
  grep -q 'ADR-037' "$SKILL_FILE"
}

# ---------- ADR-067: YOLO Behavior section ----------

@test "E47-S2: innovation includes YOLO Behavior section" {
  grep -qE '^## YOLO Behavior|^### YOLO Behavior|^## YOLO Mode|^### YOLO Mode' "$SKILL_FILE"
}

@test "E47-S2: innovation codifies auto-confirm template-output in YOLO" {
  grep -qiE 'auto[- ]confirm.*template[- ]output|template[- ]output.*auto[- ]continue|auto[- ]continue.*template[- ]output' "$SKILL_FILE"
}

@test "E47-S2: innovation codifies never-auto-skip open questions in YOLO" {
  grep -qiE 'never auto[- ]skip.*open[- ]question|open[- ]question.*require human|never.*auto[- ]answer' "$SKILL_FILE"
}

# ---------- AC1: Orion subagent delegation ----------

@test "E47-S2: innovation references Orion by name" {
  grep -q 'Orion' "$SKILL_FILE"
}

@test "E47-S2: innovation references innovation-strategist subagent" {
  grep -q 'innovation-strategist' "$SKILL_FILE"
}

@test "E47-S2: innovation uses context: fork pattern" {
  grep -qE 'context: fork|context:fork|`context: fork`' "$SKILL_FILE"
}

# ---------- ADR refs and traceability ----------

@test "E47-S2: innovation references ADR-041 (Native Execution)" {
  grep -q 'ADR-041' "$SKILL_FILE"
}

@test "E47-S2: innovation references ADR-042 (Scripts-over-LLM)" {
  grep -q 'ADR-042' "$SKILL_FILE"
}

@test "E47-S2: innovation references ADR-063 (Subagent Dispatch Contract)" {
  grep -q 'ADR-063' "$SKILL_FILE"
}

@test "E47-S2: innovation references ADR-065 (New Skills Wiring)" {
  grep -q 'ADR-065' "$SKILL_FILE"
}

@test "E47-S2: innovation references ADR-067 (YOLO Mode Contract)" {
  grep -q 'ADR-067' "$SKILL_FILE"
}

# ---------- AC4-5: innovation-frameworks.csv exists in plugin knowledge dir ----------

@test "E47-S2: innovation-frameworks.csv exists in plugin knowledge directory" {
  [ -f "$CSV_FILE" ]
}

@test "E47-S2: innovation-frameworks.csv has expected header columns" {
  head -1 "$CSV_FILE" | grep -qE 'framework_id.*name.*category.*description.*best_for'
}

@test "E47-S2: innovation-frameworks.csv contains JTBD framework (bf-01)" {
  grep -qE '"bf-01"' "$CSV_FILE"
  grep -qi 'Jobs-to-be-Done' "$CSV_FILE"
}

@test "E47-S2: innovation-frameworks.csv contains Blue Ocean (bf-02)" {
  grep -qE '"bf-02"' "$CSV_FILE"
  grep -qi 'Blue Ocean' "$CSV_FILE"
}

@test "E47-S2: innovation-frameworks.csv contains Business Model Canvas (bf-04)" {
  grep -qE '"bf-04"' "$CSV_FILE"
  grep -qi 'Business Model Canvas' "$CSV_FILE"
}

# ---------- Linter compliance ----------

@test "E47-S2: lint-skill-frontmatter.sh passes on gaia-innovation SKILL.md" {
  cd "$REPO_ROOT"
  bash .github/scripts/lint-skill-frontmatter.sh
}

# ---------- Layout constraints ----------

@test "E47-S2: gaia-innovation/ has no workflow.yaml (native skill)" {
  [ ! -f "$SKILL_DIR/workflow.yaml" ]
}

@test "E47-S2: gaia-innovation/ has no instructions.xml (native skill)" {
  [ ! -f "$SKILL_DIR/instructions.xml" ]
}

# ---------- Subagent registration ----------

@test "E47-S2: required subagent innovation-strategist exists" {
  [ -f "$AGENTS_DIR/innovation-strategist.md" ]
}
