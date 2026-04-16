#!/usr/bin/env bats
# creative-sprint-parity.bats — E28-S102 parity + structure tests
#
# Validates the conversion of _gaia/creative/workflows/creative-sprint/ to a
# native SKILL.md file at plugins/gaia/skills/gaia-creative-sprint/SKILL.md.
#
#   AC1: SKILL.md exists at the native-conversion target path with valid
#        frontmatter (name, description, and any additional fields pinned by
#        the E28-S19 schema) and three-phase pipeline instructions
#        (empathize → solve → innovate → synthesize)
#   AC2: Subagent delegation preserved — empathize → design-thinking-coach;
#        solve → problem-solver; innovate → innovation-strategist; sequential
#        ordering is maintained
#   AC3: Unified creative brief written to {creative_artifacts}/creative-sprint-{date}.md
#   AC4: Frontmatter linter passes with zero errors
#   AC5: Functional parity with legacy `_gaia/creative/workflows/creative-sprint/`
#        — equivalent phase outputs and equivalent unified creative brief
#
# Refs: E28-S102, FR-323, NFR-048, NFR-053, ADR-041, ADR-045
#
# Usage:
#   bats tests/cluster-13-parity/creative-sprint-parity.bats
#
# Dependencies: bats-core 1.10+

# ---------- Helpers ----------

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SKILLS_DIR="$REPO_ROOT/plugins/gaia/skills"
  AGENTS_DIR="$REPO_ROOT/plugins/gaia/agents"

  SKILL="gaia-creative-sprint"
  SKILL_DIR="$SKILLS_DIR/$SKILL"
  SKILL_FILE="$SKILL_DIR/SKILL.md"
}

# ---------- AC1: SKILL.md exists with valid frontmatter and three-phase pipeline ----------

@test "E28-S102: SKILL.md exists at plugins/gaia/skills/gaia-creative-sprint/" {
  [ -f "$SKILL_FILE" ]
}

@test "E28-S102: SKILL.md has YAML frontmatter delimiters" {
  head -1 "$SKILL_FILE" | grep -q "^---$"
  awk 'NR>1 && /^---$/{found=1; exit} END{exit !found}' "$SKILL_FILE"
}

@test "E28-S102: SKILL.md frontmatter has name: gaia-creative-sprint" {
  awk '/^---$/{n++; next} n==1{print}' "$SKILL_FILE" | grep -q '^name: gaia-creative-sprint'
}

@test "E28-S102: SKILL.md frontmatter description includes 'creative sprint' trigger" {
  awk '/^---$/{n++; next} n==1{print}' "$SKILL_FILE" | grep -qi '^description:.*creative sprint'
}

@test "E28-S102: SKILL.md frontmatter description references empathize-solve-innovate pipeline" {
  awk '/^---$/{n++; next} n==1{print}' "$SKILL_FILE" | grep -qiE '^description:.*empathize.*solve.*innovate'
}

@test "E28-S102: SKILL.md frontmatter has context: fork" {
  awk '/^---$/{n++; next} n==1{print}' "$SKILL_FILE" | grep -q '^context: fork'
}

@test "E28-S102: SKILL.md frontmatter has allowed-tools with Agent" {
  awk '/^---$/{n++; next} n==1{print}' "$SKILL_FILE" | grep -q 'allowed-tools:.*Agent'
}

@test "E28-S102: SKILL.md frontmatter allowed-tools contains Read" {
  awk '/^---$/{n++; next} n==1{print}' "$SKILL_FILE" | grep -q 'allowed-tools:.*Read'
}

@test "E28-S102: SKILL.md frontmatter allowed-tools contains Write" {
  awk '/^---$/{n++; next} n==1{print}' "$SKILL_FILE" | grep -q 'allowed-tools:.*Write'
}

# ---------- AC1: Three-phase pipeline sections present in order ----------

@test "E28-S102: SKILL.md body contains Phase 1 — Empathize heading" {
  grep -qE '^##.*Phase 1.*Empathize' "$SKILL_FILE"
}

@test "E28-S102: SKILL.md body contains Phase 2 — Solve heading" {
  grep -qE '^##.*Phase 2.*Solve' "$SKILL_FILE"
}

@test "E28-S102: SKILL.md body contains Phase 3 — Innovate heading" {
  grep -qE '^##.*Phase 3.*Innovate' "$SKILL_FILE"
}

@test "E28-S102: SKILL.md body contains Synthesize section" {
  grep -qiE '^##.*Synthesiz' "$SKILL_FILE"
}

@test "E28-S102: SKILL.md phase sections appear in empathize → solve → innovate → synthesize order" {
  awk '
    /^##[^#]*Phase 1[^a-zA-Z]*Empathize/ { p1 = NR }
    /^##[^#]*Phase 2[^a-zA-Z]*Solve/     { p2 = NR }
    /^##[^#]*Phase 3[^a-zA-Z]*Innovate/  { p3 = NR }
    /^##[^#]*Synthesiz/                  { if (!ps) ps = NR }
    END {
      if (!p1 || !p2 || !p3 || !ps) exit 1
      if (p1 < p2 && p2 < p3 && p3 < ps) exit 0
      exit 1
    }
  ' "$SKILL_FILE"
}

# ---------- AC2: Subagent delegation preserved ----------

@test "E28-S102: SKILL.md delegates Empathize phase to design-thinking-coach subagent" {
  grep -q 'design-thinking-coach' "$SKILL_FILE"
}

@test "E28-S102: SKILL.md delegates Solve phase to problem-solver subagent" {
  grep -q 'problem-solver' "$SKILL_FILE"
}

@test "E28-S102: SKILL.md delegates Innovate phase to innovation-strategist subagent" {
  grep -q 'innovation-strategist' "$SKILL_FILE"
}

@test "E28-S102: SKILL.md references Lyra (design-thinking-coach persona)" {
  grep -q 'Lyra' "$SKILL_FILE"
}

@test "E28-S102: SKILL.md references Nova (problem-solver persona)" {
  grep -q 'Nova' "$SKILL_FILE"
}

@test "E28-S102: SKILL.md references Orion (innovation-strategist persona)" {
  grep -q 'Orion' "$SKILL_FILE"
}

@test "E28-S102: required subagent design-thinking-coach exists" {
  [ -f "$AGENTS_DIR/design-thinking-coach.md" ]
}

@test "E28-S102: required subagent problem-solver exists" {
  [ -f "$AGENTS_DIR/problem-solver.md" ]
}

@test "E28-S102: required subagent innovation-strategist exists" {
  [ -f "$AGENTS_DIR/innovation-strategist.md" ]
}

# ---------- AC2: Sequential-only contract (no parallel, no phase skip) ----------

@test "E28-S102: SKILL.md declares sequential-only execution contract" {
  grep -qiE 'sequential|never parallel|strictly after|each phase builds' "$SKILL_FILE"
}

@test "E28-S102: SKILL.md references ADR-041 (native execution model)" {
  grep -q 'ADR-041' "$SKILL_FILE"
}

@test "E28-S102: SKILL.md references ADR-045 (sequential fork-subagent pattern)" {
  grep -q 'ADR-045' "$SKILL_FILE"
}

@test "E28-S102: SKILL.md documents data-flow between phases" {
  # Empathize output feeds Solve; Solve output feeds Innovate.
  grep -qiE 'empathy.*(input|feed|consum)|Phase 1 output' "$SKILL_FILE"
  grep -qiE '(solutions|solve output).*(input|feed|consum)|Phase 2 output' "$SKILL_FILE"
}

# ---------- AC3: Unified creative brief output path preserved ----------

@test "E28-S102: SKILL.md references output path docs/creative-artifacts/creative-sprint-" {
  grep -q 'docs/creative-artifacts/creative-sprint-' "$SKILL_FILE"
}

@test "E28-S102: SKILL.md references date-suffixed output filename" {
  grep -qE 'creative-sprint-\{date\}\.md|creative-sprint-\{YYYY-MM-DD\}\.md|creative-sprint-\$\{date\}\.md' "$SKILL_FILE"
}

@test "E28-S102: SKILL.md documents unified creative brief as final synthesis artifact" {
  grep -qiE 'unified creative brief|unified brief' "$SKILL_FILE"
}

# ---------- AC-EC: Edge case coverage (7 AC-EC items) ----------

@test "E28-S102: SKILL.md handles AC-EC1 — phase subagent failure halts pipeline" {
  grep -qiE 'phase.*(fail|error).*halt|halts.*pipeline|pipeline halts' "$SKILL_FILE"
}

@test "E28-S102: SKILL.md handles AC-EC2 — missing required subagent fails fast" {
  grep -qiE 'required subagent.*not.*found|subagent.*missing|not installed' "$SKILL_FILE"
}

@test "E28-S102: SKILL.md handles AC-EC3 — Phase 2 refuses to start before Phase 1 output" {
  grep -qiE 'Phase 2 requires Phase 1 output|refuses to start|sequential.*enforc' "$SKILL_FILE"
}

@test "E28-S102: SKILL.md handles AC-EC4 — frontmatter linter reports missing field" {
  grep -qiE 'frontmatter.*linter|missing field|CI gate' "$SKILL_FILE"
}

@test "E28-S102: SKILL.md handles AC-EC5 — same-day output file overwrite / disambiguation" {
  grep -qiE 'overwrite|same day|disambiguat' "$SKILL_FILE"
}

@test "E28-S102: SKILL.md handles AC-EC6 — subagent malformed output detected" {
  grep -qiE 'malformed|schema violation|non-conformant' "$SKILL_FILE"
}

@test "E28-S102: SKILL.md handles AC-EC7 — user interrupt preserves partial outputs" {
  grep -qiE 'interrupt|cancel|partial.*output|recoverable' "$SKILL_FILE"
}

# ---------- AC5 / NFR-053: Legacy path NOT referenced in skill body ----------

@test "E28-S102: SKILL.md does NOT reference legacy _gaia/creative/workflows/ path in body" {
  # Per story AC5 test scenario 8: grepping the new SKILL.md for the legacy
  # _gaia/creative/workflows/ path must return zero matches — only subagent
  # references should remain. We check the body (before "## References")
  # because the References section is allowed to pointer to the parity source.
  body=$(awk '
    /^## References/ { in_refs = 1 }
    !in_refs { print }
  ' "$SKILL_FILE")
  ! echo "$body" | grep -q '_gaia/creative/workflows/creative-sprint'
}

@test "E28-S102: SKILL.md does NOT reference invoke-workflow tag" {
  ! grep -q 'invoke-workflow' "$SKILL_FILE"
}

# ---------- Layout constraints (flat SKILL.md layout, no legacy workflow files) ----------

@test "E28-S102: gaia-creative-sprint/ has no steps/ subdirectory" {
  [ ! -d "$SKILL_DIR/steps" ]
}

@test "E28-S102: gaia-creative-sprint/ has no workflow.yaml" {
  [ ! -f "$SKILL_DIR/workflow.yaml" ]
}

@test "E28-S102: gaia-creative-sprint/ has no .resolved/ subdirectory" {
  [ ! -d "$SKILL_DIR/.resolved" ]
}

@test "E28-S102: gaia-creative-sprint/ has no instructions.xml" {
  [ ! -f "$SKILL_DIR/instructions.xml" ]
}

# ---------- AC4: Linter compliance ----------

@test "E28-S102: lint-skill-frontmatter.sh passes on gaia-creative-sprint SKILL.md" {
  cd "$REPO_ROOT"
  bash .github/scripts/lint-skill-frontmatter.sh
}

# ---------- AC1: Inputs section preserved ----------

@test "E28-S102: SKILL.md body contains Inputs section covering creative challenge, constraints, success criteria, audience" {
  grep -qiE '^##.*Input' "$SKILL_FILE"
  grep -qi 'creative challenge' "$SKILL_FILE"
  grep -qi 'constraint' "$SKILL_FILE"
  grep -qi 'success criteria' "$SKILL_FILE"
  grep -qi 'audience' "$SKILL_FILE"
}
