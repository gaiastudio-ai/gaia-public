#!/usr/bin/env bats
# E28-S109-review-tasks-parity.bats — E28-S109 parity + structure tests
#
# Validates the conversion of 7 legacy review tasks from
# _gaia/core/tasks/review-*.xml to native SKILL.md files under
# plugins/gaia/skills/.
#
# Scope note: gaia-review-perf was already shipped in an earlier cluster
# (Cluster 9 / E28-S71 — PR-gate Review Gate variant). This story's
# effective scope is the remaining 6 new skills + a parity re-verification
# of the existing gaia-review-perf. The AC-EC2 collision guard MUST NOT
# overwrite the existing skill.
#
#   AC1: 6 new SKILL.md files exist at canonical paths with valid
#        frontmatter (name, description, tools) and pass the
#        frontmatter linter with zero errors.
#   AC2: Each converted SKILL.md preserves every `<critical><mandate>`
#        from its source XML as an explicit bullet in a `## Critical Rules`
#        section (or equivalent mandate-preservation section).
#   AC3: Frontmatter linter PASSES for every new SKILL.md.
#   AC4: Each skill preserves the legacy task's output artifact path +
#        filename pattern in the skill body.
#   AC6: Each skill cites ADR-041 and ADR-042 so readers can trace the
#        decisions, and invokes `template-header.sh` for artifact header
#        generation per ADR-042 (or documents the graceful-degradation
#        path AC-EC7).
#   AC7: The `name:` field in each SKILL.md matches the existing
#        slash-command identifier (FR-323 — skill-name identity preservation).
#   AC-EC2: The existing gaia-review-perf skill is NOT overwritten —
#        still present with its pre-story `context: fork` pattern.
#
# Refs: E28-S109, FR-323, NFR-048, NFR-053, ADR-041, ADR-042, ADR-048
#
# Usage:
#   bats tests/cluster-14-parity/E28-S109-review-tasks-parity.bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SKILLS_DIR="$REPO_ROOT/plugins/gaia/skills"

  # The 6 new conversions in scope for this story (shipped as a
  # space-separated list to remain bash-3-compatible on macOS).
  NEW_SKILLS=(
    "gaia-review-a11y"
    "gaia-adversarial"
    "gaia-review-api"
    "gaia-review-deps"
    "gaia-edge-cases"
    "gaia-review-security"
  )
}

# ---------- AC1: SKILL.md files exist and have frontmatter ----------

@test "E28-S109: gaia-review-a11y SKILL.md exists" {
  [ -f "$SKILLS_DIR/gaia-review-a11y/SKILL.md" ]
}

@test "E28-S109: gaia-adversarial SKILL.md exists" {
  [ -f "$SKILLS_DIR/gaia-adversarial/SKILL.md" ]
}

@test "E28-S109: gaia-review-api SKILL.md exists" {
  [ -f "$SKILLS_DIR/gaia-review-api/SKILL.md" ]
}

@test "E28-S109: gaia-review-deps SKILL.md exists" {
  [ -f "$SKILLS_DIR/gaia-review-deps/SKILL.md" ]
}

@test "E28-S109: gaia-edge-cases SKILL.md exists" {
  [ -f "$SKILLS_DIR/gaia-edge-cases/SKILL.md" ]
}

@test "E28-S109: gaia-review-security SKILL.md exists" {
  [ -f "$SKILLS_DIR/gaia-review-security/SKILL.md" ]
}

# ---------- AC1: Frontmatter delimiters present ----------

@test "E28-S109: all 6 new SKILL.md files have YAML frontmatter delimiters" {
  for skill in "${NEW_SKILLS[@]}"; do
    file="$SKILLS_DIR/$skill/SKILL.md"
    head -1 "$file" | grep -q "^---$"
    awk 'NR>1 && /^---$/{found=1; exit} END{exit !found}' "$file"
  done
}

# ---------- AC7 / FR-323: name field matches slash-command identifier ----------

@test "E28-S109: gaia-review-a11y name field matches" {
  head -30 "$SKILLS_DIR/gaia-review-a11y/SKILL.md" | grep -q '^name: gaia-review-a11y$'
}

@test "E28-S109: gaia-adversarial name field matches" {
  head -30 "$SKILLS_DIR/gaia-adversarial/SKILL.md" | grep -q '^name: gaia-adversarial$'
}

@test "E28-S109: gaia-review-api name field matches" {
  head -30 "$SKILLS_DIR/gaia-review-api/SKILL.md" | grep -q '^name: gaia-review-api$'
}

@test "E28-S109: gaia-review-deps name field matches" {
  head -30 "$SKILLS_DIR/gaia-review-deps/SKILL.md" | grep -q '^name: gaia-review-deps$'
}

@test "E28-S109: gaia-edge-cases name field matches" {
  head -30 "$SKILLS_DIR/gaia-edge-cases/SKILL.md" | grep -q '^name: gaia-edge-cases$'
}

@test "E28-S109: gaia-review-security name field matches" {
  head -30 "$SKILLS_DIR/gaia-review-security/SKILL.md" | grep -q '^name: gaia-review-security$'
}

# ---------- AC1: non-empty description ----------

@test "E28-S109: all 6 new SKILL.md files have non-empty description" {
  for skill in "${NEW_SKILLS[@]}"; do
    file="$SKILLS_DIR/$skill/SKILL.md"
    head -30 "$file" | grep -qE '^description: .+'
  done
}

# ---------- AC1: tools declared ----------

@test "E28-S109: all 6 new SKILL.md files declare tools" {
  for skill in "${NEW_SKILLS[@]}"; do
    file="$SKILLS_DIR/$skill/SKILL.md"
    head -30 "$file" | grep -qE '^tools:.+Read'
  done
}

# ---------- AC3: Frontmatter linter PASSES across the full tree ----------

@test "E28-S109: all SKILL.md files (full tree) pass frontmatter linter" {
  cd "$REPO_ROOT" && bash "$REPO_ROOT/.github/scripts/lint-skill-frontmatter.sh"
}

# ---------- AC2: Critical mandates preserved from legacy task ----------
# Each skill body must contain a "Critical Rules" (or equivalent) section
# and include the specific mandate keywords from the source XML.

@test "E28-S109: gaia-review-a11y preserves ARIA, keyboard, color contrast mandates" {
  file="$SKILLS_DIR/gaia-review-a11y/SKILL.md"
  grep -qi "ARIA" "$file"
  grep -qi "keyboard" "$file"
  grep -qi "color contrast\|screen reader" "$file"
}

@test "E28-S109: gaia-adversarial preserves skeptical + ranked-findings + no-fixes mandates" {
  file="$SKILLS_DIR/gaia-adversarial/SKILL.md"
  grep -qi "skeptical\|cynical" "$file"
  grep -qi "severity.*confidence\|ranked.*finding" "$file"
  grep -qi "do not suggest fixes\|only identify problems" "$file"
}

@test "E28-S109: gaia-review-api preserves naming + HTTP methods + RFC 7807 mandates" {
  file="$SKILLS_DIR/gaia-review-api/SKILL.md"
  grep -qi "naming convention" "$file"
  grep -qi "HTTP method\|status code" "$file"
  grep -q "RFC 7807" "$file"
}

@test "E28-S109: gaia-review-deps preserves CVE + outdated + license mandates" {
  file="$SKILLS_DIR/gaia-review-deps/SKILL.md"
  grep -qi "CVE\|known vulnerabilit" "$file"
  grep -qi "outdated\|unmaintained" "$file"
  grep -qi "license" "$file"
}

@test "E28-S109: gaia-edge-cases preserves method-driven + unhandled-only + concrete examples mandates" {
  file="$SKILLS_DIR/gaia-edge-cases/SKILL.md"
  grep -qi "method-driven" "$file"
  grep -qi "unhandled" "$file"
  grep -qi "concrete example" "$file"
}

@test "E28-S109: gaia-review-security preserves OWASP Top 10 + secrets + auth mandates" {
  file="$SKILLS_DIR/gaia-review-security/SKILL.md"
  grep -q "OWASP Top 10" "$file"
  grep -qi "hardcoded secret\|API key\|credential" "$file"
  grep -qi "authentication.*authorization\|auth" "$file"
}

# ---------- AC4: Output artifact path/filename pattern preserved ----------

@test "E28-S109: gaia-review-a11y preserves test_artifacts accessibility-review output path" {
  file="$SKILLS_DIR/gaia-review-a11y/SKILL.md"
  grep -qE "test_artifacts.*accessibility-review-" "$file"
}

@test "E28-S109: gaia-adversarial preserves planning_artifacts adversarial-review output path" {
  file="$SKILLS_DIR/gaia-adversarial/SKILL.md"
  grep -qE "planning_artifacts.*adversarial-review-" "$file"
}

@test "E28-S109: gaia-review-api preserves planning_artifacts api-design-review output path" {
  file="$SKILLS_DIR/gaia-review-api/SKILL.md"
  grep -qE "planning_artifacts.*api-design-review-" "$file"
}

@test "E28-S109: gaia-review-deps preserves test_artifacts dependency-audit output path" {
  file="$SKILLS_DIR/gaia-review-deps/SKILL.md"
  grep -qE "test_artifacts.*dependency-audit-" "$file"
}

@test "E28-S109: gaia-edge-cases preserves planning_artifacts edge-case-report output path" {
  file="$SKILLS_DIR/gaia-edge-cases/SKILL.md"
  grep -qE "planning_artifacts.*edge-case-report-" "$file"
}

@test "E28-S109: gaia-review-security preserves planning_artifacts security-review output path" {
  file="$SKILLS_DIR/gaia-review-security/SKILL.md"
  grep -qE "planning_artifacts.*security-review-" "$file"
}

# ---------- AC6: ADR-041 + ADR-042 citations and template-header.sh ref ----------

@test "E28-S109: all 6 new SKILL.md files cite ADR-041 and ADR-042" {
  for skill in "${NEW_SKILLS[@]}"; do
    file="$SKILLS_DIR/$skill/SKILL.md"
    grep -q "ADR-041" "$file"
    grep -q "ADR-042" "$file"
  done
}

@test "E28-S109: all 6 new SKILL.md files reference template-header.sh for header generation" {
  for skill in "${NEW_SKILLS[@]}"; do
    file="$SKILLS_DIR/$skill/SKILL.md"
    grep -q "template-header.sh" "$file"
  done
}

# ---------- AC-EC2: Pre-existing gaia-review-perf NOT overwritten ----------

@test "E28-S109: gaia-review-perf SKILL.md still exists (collision guard honored)" {
  [ -f "$SKILLS_DIR/gaia-review-perf/SKILL.md" ]
}

@test "E28-S109: gaia-review-perf retains its pre-story context: fork pattern" {
  head -10 "$SKILLS_DIR/gaia-review-perf/SKILL.md" | grep -q '^context: fork$'
}

# ---------- AC: References section cites source XML path ----------

@test "E28-S109: all 6 new SKILL.md files cross-reference the source XML path" {
  grep -q "review-accessibility.xml" "$SKILLS_DIR/gaia-review-a11y/SKILL.md"
  grep -q "review-adversarial.xml" "$SKILLS_DIR/gaia-adversarial/SKILL.md"
  grep -q "review-api-design.xml" "$SKILLS_DIR/gaia-review-api/SKILL.md"
  grep -q "review-dependency-audit.xml" "$SKILLS_DIR/gaia-review-deps/SKILL.md"
  grep -q "review-edge-case-hunter.xml" "$SKILLS_DIR/gaia-edge-cases/SKILL.md"
  grep -q "review-security.xml" "$SKILLS_DIR/gaia-review-security/SKILL.md"
}

# ---------- Zero orphaned engine-specific XML tags ----------

@test "E28-S109: no orphaned engine-specific XML tags in any of the 6 new skills" {
  for skill in "${NEW_SKILLS[@]}"; do
    file="$SKILLS_DIR/$skill/SKILL.md"
    # These engine tags must be mapped to prose, not left verbatim
    if grep -qE '<(action|template-output|invoke-workflow|check|ask|step|workflow|task)[> ]' "$file"; then
      echo "orphaned XML tag in $file"
      return 1
    fi
  done
}
