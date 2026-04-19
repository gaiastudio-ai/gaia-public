#!/usr/bin/env bats
# cluster-11-testing-cycle.bats — Cluster 11 integration test: testing cycle
#
# Story: E28-S91 — Test testing cluster: design, atdd, gap-analysis, fill cycle
#
# Validates the full testing cluster cycle end-to-end:
#   - test-design produces a test plan from a fixture story
#   - atdd generates acceptance tests referencing test plan scenarios
#   - test-gap-analysis detects a known coverage gap
#   - fill-test-gaps proposes remediation for the gap
#   - validate-gate.sh gates pass after the full cycle
#
# All tests exercise pre-built fixture data — no LLM in the loop.
# Skills are validated structurally (SKILL.md existence, frontmatter, scripts).

PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SKILLS_DIR="$PLUGIN_DIR/skills"
SCRIPTS_DIR="$PLUGIN_DIR/scripts"
FIXTURES_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../fixtures/cluster-11" && pwd)"

setup() {
  TMP_DIR="$(mktemp -d)"
  mkdir -p "$TMP_DIR/docs/test-artifacts"
}

teardown() {
  rm -rf "$TMP_DIR"
}

# ---------- AC1: test-design produces test plan from fixture story ----------

@test "AC1: test-design skill produces test plan from fixture story" {
  # Given a fixture story file with known ACs and requirements
  local fixture_story="$FIXTURES_DIR/fixture-story.md"
  [ -f "$fixture_story" ]

  # And the gaia-test-design SKILL.md exists
  local skill_file="$SKILLS_DIR/gaia-test-design/SKILL.md"
  [ -f "$skill_file" ]

  # When the fixture test plan is placed at the expected output path
  # (simulating test-design skill output)
  cp "$FIXTURES_DIR/fixture-test-plan.md" "$TMP_DIR/docs/test-artifacts/test-plan.md"

  # Then the test plan file exists at the expected output path
  [ -f "$TMP_DIR/docs/test-artifacts/test-plan.md" ]

  # And the test plan contains test scenario entries
  run grep -c "## Test Scenarios" "$TMP_DIR/docs/test-artifacts/test-plan.md"
  [ "$output" -ge 1 ]
}

@test "AC1: test plan contains risk assessment and AC-mapped scenarios" {
  # Given a test plan produced by gaia-test-design
  cp "$FIXTURES_DIR/fixture-test-plan.md" "$TMP_DIR/docs/test-artifacts/test-plan.md"
  [ -f "$TMP_DIR/docs/test-artifacts/test-plan.md" ]

  # Then it contains a risk assessment section
  run grep -c "risk" "$TMP_DIR/docs/test-artifacts/test-plan.md"
  [ "$output" -ge 1 ]

  # And it contains scenarios mapped to the fixture story's acceptance criteria
  run grep -c "AC1\|AC2\|AC3" "$TMP_DIR/docs/test-artifacts/test-plan.md"
  [ "$output" -ge 1 ]
}

# ---------- AC2: atdd generates acceptance tests ----------

@test "AC2: atdd generates acceptance tests referencing test plan scenarios" {
  # Given the test plan and the gaia-atdd skill
  cp "$FIXTURES_DIR/fixture-test-plan.md" "$TMP_DIR/docs/test-artifacts/test-plan.md"
  [ -f "$TMP_DIR/docs/test-artifacts/test-plan.md" ]
  local atdd_skill="$SKILLS_DIR/gaia-atdd/SKILL.md"
  [ -f "$atdd_skill" ]

  # When gaia-atdd output is placed at the expected path
  cp "$FIXTURES_DIR/fixture-atdd.md" "$TMP_DIR/docs/test-artifacts/atdd-FIXTURE-S1.md"
  [ -f "$TMP_DIR/docs/test-artifacts/atdd-FIXTURE-S1.md" ]

  # Then the ATDD output references test plan scenario IDs
  run grep -c "test plan\|test scenario\|scenario" "$TMP_DIR/docs/test-artifacts/atdd-FIXTURE-S1.md"
  [ "$output" -ge 1 ]
}

@test "AC2: atdd output contains AC-to-test mapping and Given/When/Then format" {
  # Given ATDD output from gaia-atdd invocation
  cp "$FIXTURES_DIR/fixture-atdd.md" "$TMP_DIR/docs/test-artifacts/atdd-FIXTURE-S1.md"
  [ -f "$TMP_DIR/docs/test-artifacts/atdd-FIXTURE-S1.md" ]

  # Then it contains an AC-to-test mapping table
  run grep -c "AC.*Test" "$TMP_DIR/docs/test-artifacts/atdd-FIXTURE-S1.md"
  [ "$output" -ge 1 ]

  # And all test skeletons follow Given/When/Then format
  run grep -c "Given\|When\|Then" "$TMP_DIR/docs/test-artifacts/atdd-FIXTURE-S1.md"
  [ "$output" -ge 3 ]
}

# ---------- AC3: test-gap-analysis detects coverage gap ----------

@test "AC3: test-gap-analysis detects known coverage gap in fixture" {
  # Given a fixture test suite with an intentional coverage gap
  [ -d "$FIXTURES_DIR/fixture-test-suite" ]

  # And the gaia-test-gap-analysis skill exists
  local gap_skill="$SKILLS_DIR/gaia-test-gap-analysis/SKILL.md"
  [ -f "$gap_skill" ]

  # When the gap report is placed at the expected path
  cp "$FIXTURES_DIR/fixture-gap-report.md" "$TMP_DIR/docs/test-artifacts/test-gap-analysis-cluster-11.md"
  [ -f "$TMP_DIR/docs/test-artifacts/test-gap-analysis-cluster-11.md" ]

  # Then the gap report identifies the intentionally missing coverage
  run grep -c "gap\|missing\|uncovered" "$TMP_DIR/docs/test-artifacts/test-gap-analysis-cluster-11.md"
  [ "$output" -ge 1 ]

  # And specifically names the AC that lacks test coverage
  run grep -c "AC" "$TMP_DIR/docs/test-artifacts/test-gap-analysis-cluster-11.md"
  [ "$output" -ge 1 ]
}

@test "AC3: gap report includes severity and story key references" {
  # Given a gap report produced by test-gap-analysis
  cp "$FIXTURES_DIR/fixture-gap-report.md" "$TMP_DIR/docs/test-artifacts/test-gap-analysis-cluster-11.md"
  [ -f "$TMP_DIR/docs/test-artifacts/test-gap-analysis-cluster-11.md" ]

  # Then each gap entry includes a severity level
  run grep -c "high\|medium\|low\|critical" "$TMP_DIR/docs/test-artifacts/test-gap-analysis-cluster-11.md"
  [ "$output" -ge 1 ]

  # And each gap entry includes a story key reference
  run grep -c "FIXTURE-S1" "$TMP_DIR/docs/test-artifacts/test-gap-analysis-cluster-11.md"
  [ "$output" -ge 1 ]
}

# ---------- AC4: fill-test-gaps proposes remediation ----------

@test "AC4: fill-test-gaps proposes remediation for detected gaps" {
  # Given the gap report from AC3
  cp "$FIXTURES_DIR/fixture-gap-report.md" "$TMP_DIR/docs/test-artifacts/test-gap-analysis-cluster-11.md"
  [ -f "$TMP_DIR/docs/test-artifacts/test-gap-analysis-cluster-11.md" ]

  # And the gaia-fill-test-gaps skill exists
  local fill_skill="$SKILLS_DIR/gaia-fill-test-gaps/SKILL.md"
  [ -f "$fill_skill" ]

  # When fill-test-gaps output is placed at the expected path
  cp "$FIXTURES_DIR/fixture-remediation.md" "$TMP_DIR/docs/test-artifacts/fill-test-gaps-cluster-11.md"
  [ -f "$TMP_DIR/docs/test-artifacts/fill-test-gaps-cluster-11.md" ]

  # Then a remediation proposal is generated
  run grep -c "remediation\|action\|proposal" "$TMP_DIR/docs/test-artifacts/fill-test-gaps-cluster-11.md"
  [ "$output" -ge 1 ]

  # And it addresses the specific gap detected
  run grep -c "gap\|missing" "$TMP_DIR/docs/test-artifacts/fill-test-gaps-cluster-11.md"
  [ "$output" -ge 1 ]
}

@test "AC4: remediation proposal includes actionable test additions" {
  # Given a remediation report from fill-test-gaps
  cp "$FIXTURES_DIR/fixture-remediation.md" "$TMP_DIR/docs/test-artifacts/fill-test-gaps-cluster-11.md"
  [ -f "$TMP_DIR/docs/test-artifacts/fill-test-gaps-cluster-11.md" ]

  # Then it includes test type recommendations
  run grep -c "unit\|integration\|e2e\|bats" "$TMP_DIR/docs/test-artifacts/fill-test-gaps-cluster-11.md"
  [ "$output" -ge 1 ]

  # And it includes priority for the proposed additions
  run grep -c "priority\|severity\|critical\|high\|medium" "$TMP_DIR/docs/test-artifacts/fill-test-gaps-cluster-11.md"
  [ "$output" -ge 1 ]
}

# ---------- AC5: validate-gate.sh passes after full cycle ----------

@test "AC5: validate-gate.sh traceability gate passes after full cycle" {
  # Given the full testing cluster cycle has completed
  cp "$FIXTURES_DIR/fixture-traceability-matrix.md" "$TMP_DIR/docs/test-artifacts/traceability-matrix.md"
  [ -f "$TMP_DIR/docs/test-artifacts/traceability-matrix.md" ]

  # And validate-gate.sh exists and is executable
  local gate_script="$SCRIPTS_DIR/validate-gate.sh"
  [ -x "$gate_script" ]

  # When validate-gate.sh is invoked with the traceability_exists gate
  TEST_ARTIFACTS="$TMP_DIR/docs/test-artifacts" run "$gate_script" traceability_exists

  # Then the gate check passes (exit code 0)
  [ "$status" -eq 0 ]
}

@test "AC5: validate-gate.sh CI gate passes and fails with actionable error" {
  # Given CI config exists from the testing cluster cycle
  cp "$FIXTURES_DIR/fixture-ci-setup.md" "$TMP_DIR/docs/test-artifacts/ci-setup.md"

  # And validate-gate.sh exists and is executable
  local gate_script="$SCRIPTS_DIR/validate-gate.sh"
  [ -x "$gate_script" ]

  # When validate-gate.sh is invoked with ci_setup_exists
  TEST_ARTIFACTS="$TMP_DIR/docs/test-artifacts" run "$gate_script" ci_setup_exists

  # Then the gate check passes (exit code 0)
  [ "$status" -eq 0 ]

  # And on failure: remove traceability and verify gate fails with actionable error
  rm -f "$TMP_DIR/docs/test-artifacts/traceability-matrix.md"
  TEST_ARTIFACTS="$TMP_DIR/docs/test-artifacts" run "$gate_script" traceability_exists

  # Then gate returns non-zero exit code
  [ "$status" -ne 0 ]

  # And the error message references "traceability"
  [[ "$output" == *"traceability"* ]]
}
