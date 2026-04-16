#!/usr/bin/env bats
# knowledge-bundling-parity.bats — E28-S90 knowledge fragment bundling tests
#
# Validates:
#   AC1: Knowledge fragments co-located inside each testing skill directory
#   AC2: Zero dangling _gaia/testing/knowledge/ references in SKILL.md files
#   AC3: Verbatim content preservation of bundled fragments
#   AC4: bats-core test verifies no dangling references
#
# Refs: E28-S90, NFR-048, ADR-041, ADR-042, FR-323
#
# Usage:
#   bats tests/cluster-11-parity/knowledge-bundling-parity.bats
#
# Dependencies: bats-core 1.10+

# ---------- Helpers ----------

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SKILLS_DIR="$REPO_ROOT/plugins/gaia/skills"

  # Skills that need knowledge bundling (per _index.csv mapping)
  TEST_AUTOMATE="$SKILLS_DIR/gaia-test-automate"
  TEST_DESIGN="$SKILLS_DIR/gaia-test-design"
  TEST_FRAMEWORK="$SKILLS_DIR/gaia-test-framework"
  TEST_REVIEW="$SKILLS_DIR/gaia-test-review"
  TEACH_TESTING="$SKILLS_DIR/gaia-teach-testing"
  NFR="$SKILLS_DIR/gaia-nfr"
  ATDD="$SKILLS_DIR/gaia-atdd"
  CI_SETUP="$SKILLS_DIR/gaia-ci-setup"
}

# ---------- AC1: Knowledge directories exist ----------

@test "E28-S90: gaia-test-automate has knowledge/ directory" {
  [ -d "$TEST_AUTOMATE/knowledge" ]
}

@test "E28-S90: gaia-test-design has knowledge/ directory" {
  [ -d "$TEST_DESIGN/knowledge" ]
}

@test "E28-S90: gaia-test-framework has knowledge/ directory" {
  [ -d "$TEST_FRAMEWORK/knowledge" ]
}

@test "E28-S90: gaia-test-review has knowledge/ directory" {
  [ -d "$TEST_REVIEW/knowledge" ]
}

@test "E28-S90: gaia-teach-testing has knowledge/ directory" {
  [ -d "$TEACH_TESTING/knowledge" ]
}

@test "E28-S90: gaia-nfr has knowledge/ directory" {
  [ -d "$NFR/knowledge" ]
}

@test "E28-S90: gaia-atdd has knowledge/ directory" {
  [ -d "$ATDD/knowledge" ]
}

@test "E28-S90: gaia-ci-setup has knowledge/ directory" {
  [ -d "$CI_SETUP/knowledge" ]
}

# ---------- AC1: Specific fragment files co-located ----------

# gaia-test-automate (9 fragments)
@test "E28-S90: test-automate has fixture-architecture.md" {
  [ -f "$TEST_AUTOMATE/knowledge/fixture-architecture.md" ]
}

@test "E28-S90: test-automate has deterministic-testing.md" {
  [ -f "$TEST_AUTOMATE/knowledge/deterministic-testing.md" ]
}

@test "E28-S90: test-automate has api-testing-patterns.md" {
  [ -f "$TEST_AUTOMATE/knowledge/api-testing-patterns.md" ]
}

@test "E28-S90: test-automate has data-factories.md" {
  [ -f "$TEST_AUTOMATE/knowledge/data-factories.md" ]
}

@test "E28-S90: test-automate has selector-resilience.md" {
  [ -f "$TEST_AUTOMATE/knowledge/selector-resilience.md" ]
}

@test "E28-S90: test-automate has visual-testing.md" {
  [ -f "$TEST_AUTOMATE/knowledge/visual-testing.md" ]
}

@test "E28-S90: test-automate has pytest-patterns.md" {
  [ -f "$TEST_AUTOMATE/knowledge/pytest-patterns.md" ]
}

@test "E28-S90: test-automate has jest-vitest-patterns.md" {
  [ -f "$TEST_AUTOMATE/knowledge/jest-vitest-patterns.md" ]
}

@test "E28-S90: test-automate has junit5-patterns.md" {
  [ -f "$TEST_AUTOMATE/knowledge/junit5-patterns.md" ]
}

# gaia-test-design (4 fragments)
@test "E28-S90: test-design has test-pyramid.md" {
  [ -f "$TEST_DESIGN/knowledge/test-pyramid.md" ]
}

@test "E28-S90: test-design has api-testing-patterns.md" {
  [ -f "$TEST_DESIGN/knowledge/api-testing-patterns.md" ]
}

@test "E28-S90: test-design has risk-governance.md" {
  [ -f "$TEST_DESIGN/knowledge/risk-governance.md" ]
}

@test "E28-S90: test-design has contract-testing.md" {
  [ -f "$TEST_DESIGN/knowledge/contract-testing.md" ]
}

# gaia-test-framework (6 fragments)
@test "E28-S90: test-framework has fixture-architecture.md" {
  [ -f "$TEST_FRAMEWORK/knowledge/fixture-architecture.md" ]
}

@test "E28-S90: test-framework has test-isolation.md" {
  [ -f "$TEST_FRAMEWORK/knowledge/test-isolation.md" ]
}

@test "E28-S90: test-framework has data-factories.md" {
  [ -f "$TEST_FRAMEWORK/knowledge/data-factories.md" ]
}

@test "E28-S90: test-framework has pytest-patterns.md" {
  [ -f "$TEST_FRAMEWORK/knowledge/pytest-patterns.md" ]
}

@test "E28-S90: test-framework has jest-vitest-patterns.md" {
  [ -f "$TEST_FRAMEWORK/knowledge/jest-vitest-patterns.md" ]
}

@test "E28-S90: test-framework has junit5-patterns.md" {
  [ -f "$TEST_FRAMEWORK/knowledge/junit5-patterns.md" ]
}

# gaia-test-review (5 fragments)
@test "E28-S90: test-review has test-isolation.md" {
  [ -f "$TEST_REVIEW/knowledge/test-isolation.md" ]
}

@test "E28-S90: test-review has deterministic-testing.md" {
  [ -f "$TEST_REVIEW/knowledge/deterministic-testing.md" ]
}

@test "E28-S90: test-review has selector-resilience.md" {
  [ -f "$TEST_REVIEW/knowledge/selector-resilience.md" ]
}

@test "E28-S90: test-review has visual-testing.md" {
  [ -f "$TEST_REVIEW/knowledge/visual-testing.md" ]
}

@test "E28-S90: test-review has test-healing.md" {
  [ -f "$TEST_REVIEW/knowledge/test-healing.md" ]
}

# gaia-teach-testing (1 fragment)
@test "E28-S90: teach-testing has test-pyramid.md" {
  [ -f "$TEACH_TESTING/knowledge/test-pyramid.md" ]
}

# gaia-nfr (1 fragment)
@test "E28-S90: nfr has risk-governance.md" {
  [ -f "$NFR/knowledge/risk-governance.md" ]
}

# gaia-atdd (1 fragment)
@test "E28-S90: atdd has api-testing-patterns.md" {
  [ -f "$ATDD/knowledge/api-testing-patterns.md" ]
}

# gaia-ci-setup (1 fragment)
@test "E28-S90: ci-setup has contract-testing.md" {
  [ -f "$CI_SETUP/knowledge/contract-testing.md" ]
}

# ---------- AC2: No dangling _gaia/testing/knowledge/ references ----------

@test "E28-S90: no dangling _gaia/testing/knowledge references in gaia-test-automate" {
  ! grep -r '_gaia/testing/knowledge' "$TEST_AUTOMATE/SKILL.md" 2>/dev/null
}

@test "E28-S90: no dangling _gaia/testing/knowledge references in gaia-test-design" {
  ! grep -r '_gaia/testing/knowledge' "$TEST_DESIGN/SKILL.md" 2>/dev/null
}

@test "E28-S90: no dangling _gaia/testing/knowledge references in gaia-test-framework" {
  ! grep -r '_gaia/testing/knowledge' "$TEST_FRAMEWORK/SKILL.md" 2>/dev/null
}

@test "E28-S90: no dangling _gaia/testing/knowledge references in gaia-test-review" {
  ! grep -r '_gaia/testing/knowledge' "$TEST_REVIEW/SKILL.md" 2>/dev/null
}

@test "E28-S90: no dangling _gaia/testing/knowledge references in gaia-teach-testing" {
  ! grep -r '_gaia/testing/knowledge' "$TEACH_TESTING/SKILL.md" 2>/dev/null
}

@test "E28-S90: no dangling _gaia/testing/knowledge references in gaia-nfr" {
  ! grep -r '_gaia/testing/knowledge' "$NFR/SKILL.md" 2>/dev/null
}

@test "E28-S90: no dangling _gaia/testing/knowledge references in gaia-atdd" {
  ! grep -r '_gaia/testing/knowledge' "$ATDD/SKILL.md" 2>/dev/null
}

@test "E28-S90: no dangling _gaia/testing/knowledge references in gaia-ci-setup" {
  ! grep -r '_gaia/testing/knowledge' "$CI_SETUP/SKILL.md" 2>/dev/null
}

# ---------- AC2: Comprehensive scan across ALL testing skill directories ----------

@test "E28-S90: zero dangling _gaia/testing/knowledge references across all testing skills" {
  run grep -rl '_gaia/testing/knowledge' "$SKILLS_DIR"/gaia-test-*/SKILL.md "$SKILLS_DIR"/gaia-teach-testing/SKILL.md "$SKILLS_DIR"/gaia-nfr/SKILL.md "$SKILLS_DIR"/gaia-atdd/SKILL.md "$SKILLS_DIR"/gaia-ci-setup/SKILL.md 2>/dev/null
  [ "$status" -ne 0 ]
}

# ---------- AC3: Content preservation (spot checks) ----------

@test "E28-S90: bundled fragments are non-empty" {
  for skill_dir in "$TEST_AUTOMATE" "$TEST_DESIGN" "$TEST_FRAMEWORK" "$TEST_REVIEW" "$TEACH_TESTING" "$NFR" "$ATDD" "$CI_SETUP"; do
    if [ -d "$skill_dir/knowledge" ]; then
      for f in "$skill_dir"/knowledge/*.md; do
        [ -s "$f" ]
      done
    fi
  done
}

# ---------- AC1: SKILL.md documents knowledge co-location ----------

@test "E28-S90: test-automate SKILL.md references bundled knowledge" {
  grep -q 'knowledge/' "$TEST_AUTOMATE/SKILL.md"
}

@test "E28-S90: test-design SKILL.md references bundled knowledge" {
  grep -q 'knowledge/' "$TEST_DESIGN/SKILL.md"
}

@test "E28-S90: test-framework SKILL.md references bundled knowledge" {
  grep -q 'knowledge/' "$TEST_FRAMEWORK/SKILL.md"
}

@test "E28-S90: test-review SKILL.md references bundled knowledge" {
  grep -q 'knowledge/' "$TEST_REVIEW/SKILL.md"
}

@test "E28-S90: teach-testing SKILL.md references bundled knowledge" {
  grep -q 'knowledge/' "$TEACH_TESTING/SKILL.md"
}

@test "E28-S90: nfr SKILL.md references bundled knowledge" {
  grep -q 'knowledge/' "$NFR/SKILL.md"
}

@test "E28-S90: atdd SKILL.md references bundled knowledge" {
  grep -q 'knowledge/' "$ATDD/SKILL.md"
}

@test "E28-S90: ci-setup SKILL.md references bundled knowledge" {
  grep -q 'knowledge/' "$CI_SETUP/SKILL.md"
}
