#!/usr/bin/env bats
# E28-S111-utilities-parity.bats — E28-S111 parity + structure tests
#
# Validates the conversion of 4 legacy document/utility tasks and 3
# anytime/utility workflows from _gaia/ sources to native SKILL.md files
# under plugins/gaia/skills/.
#
# In-scope skills (7):
#   gaia-index-docs          ← _gaia/core/tasks/index-docs.xml (46 lines)
#   gaia-merge-docs          ← _gaia/core/tasks/merge-docs.xml (34 lines)
#   gaia-shard-doc           ← _gaia/core/tasks/shard-doc.xml (49 lines)
#   gaia-validate-framework  ← _gaia/core/tasks/validate-framework.xml (66 lines)
#   gaia-action-items        ← _gaia/lifecycle/workflows/4-implementation/action-items/instructions.xml (131 lines)
#   gaia-create-stakeholder  ← _gaia/lifecycle/workflows/4-implementation/create-stakeholder/instructions.xml (79 lines)
#   gaia-bridge-toggle       ← _gaia/core/workflows/bridge-toggle/instructions.xml (69 lines)
#
# ACs covered here:
#   AC1:  All 7 SKILL.md files exist at canonical paths with valid
#         frontmatter (name, description, tools) and pass the
#         frontmatter linter with zero errors.
#   AC2..AC8: Each converted SKILL.md preserves every `<critical><mandate>`
#         (or Instructions step) from its source as explicit prose.
#   AC9:  Frontmatter linter PASSES for every new SKILL.md.
#   AC10: Each skill cites ADR-041 and follows the canonical SKILL.md shape.
#   AC11: Slash-command identity preserved (name field matches /gaia-{cmd}).
#         For bridge-toggle, both /gaia-bridge-enable and /gaia-bridge-disable
#         are registered as wrapper skills that delegate to gaia-bridge-toggle.
#
# Refs: E28-S111, FR-323, NFR-048, NFR-053, ADR-041, ADR-042, ADR-048
#
# Usage:
#   bats tests/cluster-14-parity/E28-S111-utilities-parity.bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SKILLS_DIR="$REPO_ROOT/plugins/gaia/skills"

  NEW_SKILLS=(
    "gaia-index-docs"
    "gaia-merge-docs"
    "gaia-shard-doc"
    "gaia-validate-framework"
    "gaia-action-items"
    "gaia-create-stakeholder"
    "gaia-bridge-toggle"
  )
}

# ---------- AC1: SKILL.md files exist ----------

@test "E28-S111: gaia-index-docs SKILL.md exists" {
  [ -f "$SKILLS_DIR/gaia-index-docs/SKILL.md" ]
}

@test "E28-S111: gaia-merge-docs SKILL.md exists" {
  [ -f "$SKILLS_DIR/gaia-merge-docs/SKILL.md" ]
}

@test "E28-S111: gaia-shard-doc SKILL.md exists" {
  [ -f "$SKILLS_DIR/gaia-shard-doc/SKILL.md" ]
}

@test "E28-S111: gaia-validate-framework SKILL.md exists" {
  [ -f "$SKILLS_DIR/gaia-validate-framework/SKILL.md" ]
}

@test "E28-S111: gaia-action-items SKILL.md exists" {
  [ -f "$SKILLS_DIR/gaia-action-items/SKILL.md" ]
}

@test "E28-S111: gaia-create-stakeholder SKILL.md exists" {
  [ -f "$SKILLS_DIR/gaia-create-stakeholder/SKILL.md" ]
}

@test "E28-S111: gaia-bridge-toggle SKILL.md exists" {
  [ -f "$SKILLS_DIR/gaia-bridge-toggle/SKILL.md" ]
}

# AC11 — bridge alias wrappers: both enable and disable command names preserved
@test "E28-S111: gaia-bridge-enable wrapper SKILL.md exists" {
  [ -f "$SKILLS_DIR/gaia-bridge-enable/SKILL.md" ]
}

@test "E28-S111: gaia-bridge-disable wrapper SKILL.md exists" {
  [ -f "$SKILLS_DIR/gaia-bridge-disable/SKILL.md" ]
}

# ---------- AC1: Frontmatter delimiters ----------

@test "E28-S111: all 7 new SKILL.md files have YAML frontmatter delimiters" {
  for skill in "${NEW_SKILLS[@]}"; do
    file="$SKILLS_DIR/$skill/SKILL.md"
    head -1 "$file" | grep -q "^---$"
    awk 'NR>1 && /^---$/{found=1; exit} END{exit !found}' "$file"
  done
}

# ---------- AC11 / FR-323: name field matches slash-command identifier ----------

@test "E28-S111: gaia-index-docs name field matches" {
  head -30 "$SKILLS_DIR/gaia-index-docs/SKILL.md" | grep -q '^name: gaia-index-docs$'
}

@test "E28-S111: gaia-merge-docs name field matches" {
  head -30 "$SKILLS_DIR/gaia-merge-docs/SKILL.md" | grep -q '^name: gaia-merge-docs$'
}

@test "E28-S111: gaia-shard-doc name field matches" {
  head -30 "$SKILLS_DIR/gaia-shard-doc/SKILL.md" | grep -q '^name: gaia-shard-doc$'
}

@test "E28-S111: gaia-validate-framework name field matches" {
  head -30 "$SKILLS_DIR/gaia-validate-framework/SKILL.md" | grep -q '^name: gaia-validate-framework$'
}

@test "E28-S111: gaia-action-items name field matches" {
  head -30 "$SKILLS_DIR/gaia-action-items/SKILL.md" | grep -q '^name: gaia-action-items$'
}

@test "E28-S111: gaia-create-stakeholder name field matches" {
  head -30 "$SKILLS_DIR/gaia-create-stakeholder/SKILL.md" | grep -q '^name: gaia-create-stakeholder$'
}

@test "E28-S111: gaia-bridge-toggle name field matches" {
  head -30 "$SKILLS_DIR/gaia-bridge-toggle/SKILL.md" | grep -q '^name: gaia-bridge-toggle$'
}

@test "E28-S111: gaia-bridge-enable name field matches" {
  head -30 "$SKILLS_DIR/gaia-bridge-enable/SKILL.md" | grep -q '^name: gaia-bridge-enable$'
}

@test "E28-S111: gaia-bridge-disable name field matches" {
  head -30 "$SKILLS_DIR/gaia-bridge-disable/SKILL.md" | grep -q '^name: gaia-bridge-disable$'
}

# ---------- AC1: non-empty description ----------

@test "E28-S111: all 7 new SKILL.md files have non-empty description" {
  for skill in "${NEW_SKILLS[@]}"; do
    file="$SKILLS_DIR/$skill/SKILL.md"
    head -30 "$file" | grep -qE '^description: .+'
  done
}

# ---------- AC1: tools declared ----------

@test "E28-S111: all 7 new SKILL.md files declare tools" {
  for skill in "${NEW_SKILLS[@]}"; do
    file="$SKILLS_DIR/$skill/SKILL.md"
    head -30 "$file" | grep -qE '^tools:.+'
  done
}

# ---------- AC9: Frontmatter linter PASSES across the full tree ----------

@test "E28-S111: all SKILL.md files (full tree) pass frontmatter linter" {
  cd "$REPO_ROOT" && bash "$REPO_ROOT/.github/scripts/lint-skill-frontmatter.sh"
}

# ---------- AC2: index-docs preserves scan + categorise + toc mandates ----------

@test "E28-S111: gaia-index-docs preserves scan + preserve + relative path mandates" {
  file="$SKILLS_DIR/gaia-index-docs/SKILL.md"
  grep -qi "scan all\|scan every\|never skip" "$file"
  grep -qi "preserve.*manual\|preserve existing" "$file"
  grep -qi "relative path" "$file"
}

@test "E28-S111: gaia-index-docs documents target folder + TOC + last updated" {
  file="$SKILLS_DIR/gaia-index-docs/SKILL.md"
  grep -qi "target folder\|target root" "$file"
  grep -qi "table of contents\|TOC" "$file"
  grep -qi "last updated" "$file"
}

@test "E28-S111: gaia-index-docs emits to target-folder/index.md" {
  file="$SKILLS_DIR/gaia-index-docs/SKILL.md"
  grep -q "index.md" "$file"
}

# ---------- AC3: merge-docs preserves numbering + hierarchy + order mandates ----------

@test "E28-S111: gaia-merge-docs preserves numbering + hierarchy + ordering mandates" {
  file="$SKILLS_DIR/gaia-merge-docs/SKILL.md"
  grep -qi "section numbering\|cross-reference\|cross reference" "$file"
  grep -qi "heading hierarchy\|heading level" "$file"
  grep -qi "correct order\|reassemble" "$file"
}

@test "E28-S111: gaia-merge-docs cites inverse of shard-doc" {
  file="$SKILLS_DIR/gaia-merge-docs/SKILL.md"
  grep -qi "inverse of shard\|opposite of shard\|shard-doc" "$file"
}

# ---------- AC4: shard-doc preserves H2 default + preserve content + index mandates ----------

@test "E28-S111: gaia-shard-doc preserves H2-default + preserve-all-content + index mandates" {
  file="$SKILLS_DIR/gaia-shard-doc/SKILL.md"
  grep -qi "H2\|level.2\|## " "$file"
  grep -qi "preserve all\|never drop\|preserve ALL" "$file"
  grep -qi "index.md" "$file"
}

@test "E28-S111: gaia-shard-doc preserves preamble + confirmation mandates" {
  file="$SKILLS_DIR/gaia-shard-doc/SKILL.md"
  grep -qi "preamble" "$file"
  grep -qi "confirm\|confirmation" "$file"
}

# ---------- AC5: validate-framework preserves report-all + every-path + resolution mandates ----------

@test "E28-S111: gaia-validate-framework preserves report-all-issues + every-path mandates" {
  file="$SKILLS_DIR/gaia-validate-framework/SKILL.md"
  grep -qi "report ALL\|report all issues\|do not stop" "$file"
  grep -qi "every path\|every reference\|path reference" "$file"
}

@test "E28-S111: gaia-validate-framework references manifest.yaml and config resolution" {
  file="$SKILLS_DIR/gaia-validate-framework/SKILL.md"
  grep -q "manifest.yaml" "$file"
  grep -qi "config resolution\|resolution chain\|resolved" "$file"
}

@test "E28-S111: gaia-validate-framework documents report format (severity grouping)" {
  file="$SKILLS_DIR/gaia-validate-framework/SKILL.md"
  grep -qi "critical\|warning\|severity" "$file"
  grep -qi "PASS\|FAIL" "$file"
}

# ---------- AC6: action-items preserves triage + routing + reasoning + escalation mandates ----------

@test "E28-S111: gaia-action-items preserves pre-sprint + routing + reasoning + escalation mandates" {
  file="$SKILLS_DIR/gaia-action-items/SKILL.md"
  grep -qi "pre-sprint\|before sprint planning" "$file"
  grep -qi "route\|routing" "$file"
  grep -qi "reasoning\|no silent closure" "$file"
  grep -qi "escalat" "$file"
}

@test "E28-S111: gaia-action-items documents triage buckets (clarification, implementation, process, automation)" {
  file="$SKILLS_DIR/gaia-action-items/SKILL.md"
  grep -qi "clarification" "$file"
  grep -qi "implementation" "$file"
  grep -qi "process" "$file"
  grep -qi "automation" "$file"
}

@test "E28-S111: gaia-action-items preserves classification-gate before /gaia-create-story handoff (AC-EC7)" {
  file="$SKILLS_DIR/gaia-action-items/SKILL.md"
  grep -qi "classif" "$file"
  grep -qi "confirm\|confirmation" "$file"
  grep -q "/gaia-create-story" "$file"
}

@test "E28-S111: gaia-action-items preserves action-items.yaml tracker" {
  file="$SKILLS_DIR/gaia-action-items/SKILL.md"
  grep -q "action-items.yaml" "$file"
}

# ---------- AC7: create-stakeholder preserves custom/stakeholders + 50-file cap + duplicate-check mandates ----------

@test "E28-S111: gaia-create-stakeholder preserves custom/stakeholders + 50-cap + duplicate-check mandates" {
  file="$SKILLS_DIR/gaia-create-stakeholder/SKILL.md"
  grep -q "custom/stakeholders" "$file"
  grep -qi "50.file\|50 file\|50-file cap" "$file"
  grep -qi "duplicate\|case-insensitive" "$file"
}

@test "E28-S111: gaia-create-stakeholder preserves required fields (name, role, expertise, personality)" {
  file="$SKILLS_DIR/gaia-create-stakeholder/SKILL.md"
  grep -qi "name" "$file"
  grep -qi "role" "$file"
  grep -qi "expertise" "$file"
  grep -qi "personality" "$file"
}

@test "E28-S111: gaia-create-stakeholder preserves 100-line limit and slug derivation" {
  file="$SKILLS_DIR/gaia-create-stakeholder/SKILL.md"
  grep -qi "100.line\|100 line" "$file"
  grep -qi "slug\|kebab" "$file"
}

# ---------- AC8: bridge-toggle preserves regex-edit + idempotency + post-flip mandates ----------

@test "E28-S111: gaia-bridge-toggle preserves preserve-formatting + regex-edit + idempotent mandates" {
  file="$SKILLS_DIR/gaia-bridge-toggle/SKILL.md"
  grep -qi "preserve.*comment\|preserve.*format\|preserve all" "$file"
  grep -qi "regex" "$file"
  grep -qi "idempotent\|idempotency" "$file"
}

@test "E28-S111: gaia-bridge-toggle targets test_execution_bridge.bridge_enabled in global.yaml" {
  file="$SKILLS_DIR/gaia-bridge-toggle/SKILL.md"
  grep -q "test_execution_bridge" "$file"
  grep -q "bridge_enabled" "$file"
  grep -q "global.yaml" "$file"
}

@test "E28-S111: gaia-bridge-toggle requires post-edit /gaia-build-configs re-run" {
  file="$SKILLS_DIR/gaia-bridge-toggle/SKILL.md"
  grep -q "/gaia-build-configs\|gaia-build-configs\|build-configs" "$file"
}

@test "E28-S111: gaia-bridge-toggle fails fast when test_execution_bridge block is missing (AC-EC2)" {
  file="$SKILLS_DIR/gaia-bridge-toggle/SKILL.md"
  grep -qi "missing\|not found\|not present\|fails fast\|fail fast" "$file"
}

# ---------- AC11: bridge alias wrappers delegate to gaia-bridge-toggle ----------

@test "E28-S111: gaia-bridge-enable wrapper delegates to gaia-bridge-toggle" {
  file="$SKILLS_DIR/gaia-bridge-enable/SKILL.md"
  grep -q "gaia-bridge-toggle" "$file"
  grep -qi "enable" "$file"
}

@test "E28-S111: gaia-bridge-disable wrapper delegates to gaia-bridge-toggle" {
  file="$SKILLS_DIR/gaia-bridge-disable/SKILL.md"
  grep -q "gaia-bridge-toggle" "$file"
  grep -qi "disable" "$file"
}

# ---------- AC10: ADR-041 citation + canonical shape ----------

@test "E28-S111: all 7 new SKILL.md files cite ADR-041" {
  for skill in "${NEW_SKILLS[@]}"; do
    file="$SKILLS_DIR/$skill/SKILL.md"
    grep -q "ADR-041" "$file"
  done
}

@test "E28-S111: all 7 new SKILL.md files have a Mission section" {
  for skill in "${NEW_SKILLS[@]}"; do
    file="$SKILLS_DIR/$skill/SKILL.md"
    grep -q "^## Mission" "$file"
  done
}

@test "E28-S111: all 7 new SKILL.md files have a Critical Rules (or Instructions) section" {
  for skill in "${NEW_SKILLS[@]}"; do
    file="$SKILLS_DIR/$skill/SKILL.md"
    grep -qE "^## (Critical Rules|Instructions|Steps)" "$file"
  done
}

# ---------- References: source file cited ----------

@test "E28-S111: gaia-index-docs cites source xml" {
  grep -q "index-docs.xml" "$SKILLS_DIR/gaia-index-docs/SKILL.md"
}

@test "E28-S111: gaia-merge-docs cites source xml" {
  grep -q "merge-docs.xml" "$SKILLS_DIR/gaia-merge-docs/SKILL.md"
}

@test "E28-S111: gaia-shard-doc cites source xml" {
  grep -q "shard-doc.xml" "$SKILLS_DIR/gaia-shard-doc/SKILL.md"
}

@test "E28-S111: gaia-validate-framework cites source xml" {
  grep -q "validate-framework.xml" "$SKILLS_DIR/gaia-validate-framework/SKILL.md"
}

@test "E28-S111: gaia-action-items cites source instructions.xml path" {
  grep -q "action-items/instructions.xml" "$SKILLS_DIR/gaia-action-items/SKILL.md"
}

@test "E28-S111: gaia-create-stakeholder cites source instructions.xml path" {
  grep -q "create-stakeholder/instructions.xml" "$SKILLS_DIR/gaia-create-stakeholder/SKILL.md"
}

@test "E28-S111: gaia-bridge-toggle cites source instructions.xml path" {
  grep -q "bridge-toggle/instructions.xml" "$SKILLS_DIR/gaia-bridge-toggle/SKILL.md"
}

# ---------- Zero orphaned engine-specific XML tags ----------

@test "E28-S111: no orphaned engine-specific XML tags in any of the 7 new skills" {
  for skill in "${NEW_SKILLS[@]}"; do
    file="$SKILLS_DIR/$skill/SKILL.md"
    if grep -qE '<(action|template-output|invoke-workflow|check|ask|step|workflow|task)[> ]' "$file"; then
      echo "orphaned XML tag in $file"
      return 1
    fi
  done
}

# ---------- tools is per-skill-appropriate ----------

@test "E28-S111: gaia-validate-framework includes Bash + Read + Grep (manifest walk)" {
  file="$SKILLS_DIR/gaia-validate-framework/SKILL.md"
  grep -qE '^tools:.*Bash' "$file"
  grep -qE '^tools:.*Read' "$file"
  grep -qE '^tools:.*Grep' "$file"
}

@test "E28-S111: gaia-bridge-toggle includes Read + Edit + Bash (yaml edit + build-configs rerun)" {
  file="$SKILLS_DIR/gaia-bridge-toggle/SKILL.md"
  grep -qE '^tools:.*Read' "$file"
  grep -qE '^tools:.*Edit' "$file"
  grep -qE '^tools:.*Bash' "$file"
}

@test "E28-S111: gaia-create-stakeholder includes Write (scaffold) and Bash (mkdir sidecar)" {
  file="$SKILLS_DIR/gaia-create-stakeholder/SKILL.md"
  grep -qE '^tools:.*Write' "$file"
  grep -qE '^tools:.*Bash' "$file"
}
