#!/usr/bin/env bats
# e28-s114-lifecycle-skills-conversion.bats — E28-S114 acceptance tests
#
# Validates the conversion of 5 legacy lifecycle skills under
# `_gaia/lifecycle/skills/` to native Claude Code SKILL.md format under
# `plugins/gaia/skills/`:
#
#   - document-rulesets            → gaia-document-rulesets            (10 sections)
#   - ground-truth-management      → gaia-ground-truth-management      ( 8 sections)
#   - memory-management            → gaia-memory-management            ( 7 sections)
#   - memory-management-cross-agent→ gaia-memory-management-cross-agent( 2 sections)
#   - validation-patterns          → gaia-validation-patterns          ( 5 sections)
#
# Total: 32 <!-- SECTION: --> markers preserved verbatim.
#
# Traces to FR-323, NFR-048, NFR-053, ADR-041, ADR-048.
#
# Dependencies: bats-core 1.10+

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SKILL_DIR="$REPO_ROOT/plugins/gaia/skills"
  LINTER="$REPO_ROOT/.github/scripts/lint-skill-frontmatter.sh"

  DR_SKILL="$SKILL_DIR/gaia-document-rulesets/SKILL.md"
  GT_SKILL="$SKILL_DIR/gaia-ground-truth-management/SKILL.md"
  MM_SKILL="$SKILL_DIR/gaia-memory-management/SKILL.md"
  MMX_SKILL="$SKILL_DIR/gaia-memory-management-cross-agent/SKILL.md"
  VP_SKILL="$SKILL_DIR/gaia-validation-patterns/SKILL.md"
}

# ---------- AC1: Files exist with required frontmatter ----------

@test "AC1: gaia-document-rulesets/SKILL.md exists" {
  [ -f "$DR_SKILL" ]
}

@test "AC1: gaia-ground-truth-management/SKILL.md exists" {
  [ -f "$GT_SKILL" ]
}

@test "AC1: gaia-memory-management/SKILL.md exists" {
  [ -f "$MM_SKILL" ]
}

@test "AC1: gaia-memory-management-cross-agent/SKILL.md exists" {
  [ -f "$MMX_SKILL" ]
}

@test "AC1: gaia-validation-patterns/SKILL.md exists" {
  [ -f "$VP_SKILL" ]
}

@test "AC1: all 5 SKILL.md files carry a name field" {
  for f in "$DR_SKILL" "$GT_SKILL" "$MM_SKILL" "$MMX_SKILL" "$VP_SKILL"; do
    grep -qE '^name:[[:space:]]*[^[:space:]]+' "$f" || { echo "missing name in $f"; return 1; }
  done
}

@test "AC1: all 5 SKILL.md files carry a description field" {
  for f in "$DR_SKILL" "$GT_SKILL" "$MM_SKILL" "$MMX_SKILL" "$VP_SKILL"; do
    grep -qE '^description:[[:space:]]*[^[:space:]]+' "$f" || { echo "missing description in $f"; return 1; }
  done
}

@test "AC1: all 5 SKILL.md files carry an applicable_agents field" {
  for f in "$DR_SKILL" "$GT_SKILL" "$MM_SKILL" "$MMX_SKILL" "$VP_SKILL"; do
    grep -qE '^applicable_agents:' "$f" || { echo "missing applicable_agents in $f"; return 1; }
  done
}

@test "AC1: all 5 SKILL.md files carry an allowed-tools field" {
  for f in "$DR_SKILL" "$GT_SKILL" "$MM_SKILL" "$MMX_SKILL" "$VP_SKILL"; do
    grep -qE '^allowed-tools:' "$f" || { echo "missing allowed-tools in $f"; return 1; }
  done
}

# ---------- AC9 (Test Scenarios #9): applicable_agents preservation ----------

@test "AC9: gaia-document-rulesets applicable_agents == [validator]" {
  grep -qE '^applicable_agents:[[:space:]]*\[validator\]' "$DR_SKILL"
}

@test "AC9: gaia-ground-truth-management applicable_agents == [validator]" {
  grep -qE '^applicable_agents:[[:space:]]*\[validator\]' "$GT_SKILL"
}

@test "AC9: gaia-validation-patterns applicable_agents == [validator]" {
  grep -qE '^applicable_agents:[[:space:]]*\[validator\]' "$VP_SKILL"
}

@test "AC9: gaia-memory-management applicable_agents == [all]" {
  grep -qE '^applicable_agents:[[:space:]]*\[all\]' "$MM_SKILL"
}

@test "AC9: gaia-memory-management-cross-agent applicable_agents == [all]" {
  grep -qE '^applicable_agents:[[:space:]]*\[all\]' "$MMX_SKILL"
}

# ---------- AC2: Section markers preserved verbatim ----------

# Helper — count opening SECTION markers (excluding the "END SECTION" trailer
# and the "Cross-agent extensions ... are in" narrative comment).
count_sections() {
  grep -cE '^<!-- SECTION: [a-z]' "$1"
}

@test "AC2: gaia-document-rulesets preserves 10 SECTION markers" {
  run count_sections "$DR_SKILL"
  [ "$status" -eq 0 ]
  [ "$output" -eq 10 ]
}

@test "AC2: gaia-document-rulesets has all legacy section IDs" {
  local sections=(type-detection prd-rules infra-prd-rules platform-prd-rules arch-rules ux-rules test-plan-rules epics-rules gap-analysis-rules two-pass-logic)
  for s in "${sections[@]}"; do
    grep -qE "<!-- SECTION: ${s} -->" "$DR_SKILL" || { echo "missing section $s"; return 1; }
  done
}

@test "AC2: gaia-ground-truth-management preserves 8 SECTION markers" {
  run count_sections "$GT_SKILL"
  [ "$status" -eq 0 ]
  [ "$output" -eq 8 ]
}

@test "AC2: gaia-ground-truth-management has all legacy section IDs" {
  local sections=(entry-structure incremental-refresh full-refresh dual-refresh conflict-resolution archival token-budget brownfield-extraction)
  for s in "${sections[@]}"; do
    grep -qE "<!-- SECTION: ${s} -->" "$GT_SKILL" || { echo "missing section $s"; return 1; }
  done
}

@test "AC2: gaia-memory-management preserves 7 SECTION markers" {
  run count_sections "$MM_SKILL"
  [ "$status" -eq 0 ]
  [ "$output" -eq 7 ]
}

@test "AC2: gaia-memory-management has all legacy section IDs including session-save, context-summarization, decision-formatting" {
  local sections=(decision-formatting session-load session-save context-summarization stale-detection deduplication budget-monitoring)
  for s in "${sections[@]}"; do
    grep -qE "<!-- SECTION: ${s} -->" "$MM_SKILL" || { echo "missing section $s"; return 1; }
  done
}

@test "AC2: gaia-memory-management-cross-agent preserves 2 SECTION markers" {
  run count_sections "$MMX_SKILL"
  [ "$status" -eq 0 ]
  [ "$output" -eq 2 ]
}

@test "AC2: gaia-memory-management-cross-agent has both legacy section IDs" {
  grep -qE '<!-- SECTION: cross-reference-loading -->' "$MMX_SKILL"
  grep -qE '<!-- SECTION: budget-monitoring -->' "$MMX_SKILL"
}

@test "AC2: gaia-validation-patterns preserves 5 SECTION markers" {
  run count_sections "$VP_SKILL"
  [ "$status" -eq 0 ]
  [ "$output" -eq 5 ]
}

@test "AC2: gaia-validation-patterns has all legacy section IDs" {
  local sections=(claim-extraction filesystem-verification cross-reference severity-classification findings-formatting)
  for s in "${sections[@]}"; do
    grep -qE "<!-- SECTION: ${s} -->" "$VP_SKILL" || { echo "missing section $s"; return 1; }
  done
}

@test "AC2: aggregate — 32 SECTION markers across all 5 converted files" {
  total=0
  for f in "$DR_SKILL" "$GT_SKILL" "$MM_SKILL" "$MMX_SKILL" "$VP_SKILL"; do
    n=$(grep -cE '^<!-- SECTION: [a-z]' "$f")
    total=$((total + n))
  done
  [ "$total" -eq 32 ]
}

# ---------- AC3: Frontmatter linter passes ----------

@test "AC3: frontmatter linter returns exit 0 for the plugins/gaia/skills tree" {
  cd "$REPO_ROOT"
  run bash "$LINTER"
  [ "$status" -eq 0 ]
  [[ "$output" != *ERROR* ]]
}

# ---------- AC4: JIT section load parity (byte-for-byte marker set) ----------

@test "AC4: every legacy SECTION marker in document-rulesets.md is present in the native SKILL.md" {
  LEGACY="$REPO_ROOT/../_gaia/lifecycle/skills/document-rulesets.md"
  [ -f "$LEGACY" ] || skip "legacy source not present in working tree"
  while read -r section_line; do
    section_id=$(echo "$section_line" | sed -E 's|<!-- SECTION: ([a-z0-9-]+) -->|\1|')
    grep -qE "<!-- SECTION: ${section_id} -->" "$DR_SKILL" || { echo "missing section $section_id in native"; return 1; }
  done < <(grep -oE '<!-- SECTION: [a-z0-9-]+ -->' "$LEGACY")
}

@test "AC4: every legacy SECTION marker in memory-management.md is present in the native SKILL.md" {
  LEGACY="$REPO_ROOT/../_gaia/lifecycle/skills/memory-management.md"
  [ -f "$LEGACY" ] || skip "legacy source not present in working tree"
  while read -r section_line; do
    section_id=$(echo "$section_line" | sed -E 's|<!-- SECTION: ([a-z0-9-]+) -->|\1|')
    grep -qE "<!-- SECTION: ${section_id} -->" "$MM_SKILL" || { echo "missing section $section_id in native"; return 1; }
  done < <(grep -oE '<!-- SECTION: [a-z0-9-]+ -->' "$LEGACY")
}

# ---------- ADR-041 traceability comment ----------

@test "ADR-041 traceability: each converted SKILL.md has an ADR-041 header comment" {
  for f in "$DR_SKILL" "$GT_SKILL" "$MM_SKILL" "$MMX_SKILL" "$VP_SKILL"; do
    grep -qE 'ADR-041' "$f" || { echo "missing ADR-041 citation in $f"; return 1; }
  done
}

@test "ADR-041 traceability: each converted SKILL.md cites its legacy source path" {
  grep -qE 'Source: _gaia/lifecycle/skills/document-rulesets\.md' "$DR_SKILL"
  grep -qE 'Source: _gaia/lifecycle/skills/ground-truth-management\.md' "$GT_SKILL"
  grep -qE 'Source: _gaia/lifecycle/skills/memory-management\.md' "$MM_SKILL"
  grep -qE 'Source: _gaia/lifecycle/skills/memory-management-cross-agent\.md' "$MMX_SKILL"
  grep -qE 'Source: _gaia/lifecycle/skills/validation-patterns\.md' "$VP_SKILL"
}

# ---------- Mission + Critical Rules (canonical shape per gaia-fix-story) ----------

@test "Canonical shape: each converted SKILL.md has ## Mission section" {
  for f in "$DR_SKILL" "$GT_SKILL" "$MM_SKILL" "$MMX_SKILL" "$VP_SKILL"; do
    grep -qE '^## Mission' "$f" || { echo "missing Mission section in $f"; return 1; }
  done
}

@test "Canonical shape: each converted SKILL.md has ## Critical Rules section" {
  for f in "$DR_SKILL" "$GT_SKILL" "$MM_SKILL" "$MMX_SKILL" "$VP_SKILL"; do
    grep -qE '^## Critical Rules' "$f" || { echo "missing Critical Rules section in $f"; return 1; }
  done
}
