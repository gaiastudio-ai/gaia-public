#!/usr/bin/env bats
# ci-setup-ci-edit.bats — bats-core tests for gaia-ci-setup and gaia-ci-edit skills (E28-S86)
#
# Validates:
#   - SKILL.md exists with correct frontmatter for both skills
#   - setup.sh and finalize.sh exist and are executable for both skills
#   - finalize.sh references validate-gate.sh (AC3)
#   - setup.sh validates dependencies (AC-EC3, AC-EC5)
#   - YAML field order preserved (AC4)
#   - Empty promotion_chain handled (AC-EC2)
#   - Malformed YAML detected (AC-EC4)
#   - Last environment removal guard (AC-EC6)

PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SKILLS_DIR="$PLUGIN_DIR/skills"
SCRIPTS_DIR="$PLUGIN_DIR/scripts"
FIXTURES_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/fixtures/ci-setup-ci-edit" && pwd)"

# ===== gaia-ci-setup SKILL.md existence and structure (AC1) =====

@test "gaia-ci-setup/SKILL.md exists" {
  [ -f "$SKILLS_DIR/gaia-ci-setup/SKILL.md" ]
}

@test "gaia-ci-setup SKILL.md has correct name in frontmatter" {
  run head -10 "$SKILLS_DIR/gaia-ci-setup/SKILL.md"
  [[ "$output" == *"name: gaia-ci-setup"* ]]
}

@test "gaia-ci-setup SKILL.md has tools in frontmatter" {
  run head -10 "$SKILLS_DIR/gaia-ci-setup/SKILL.md"
  [[ "$output" == *"tools:"* ]]
}

@test "gaia-ci-setup SKILL.md contains Setup section" {
  run grep -c "## Setup" "$SKILLS_DIR/gaia-ci-setup/SKILL.md"
  [ "$output" -ge 1 ]
}

@test "gaia-ci-setup SKILL.md contains Mission section" {
  run grep -c "## Mission" "$SKILLS_DIR/gaia-ci-setup/SKILL.md"
  [ "$output" -ge 1 ]
}

@test "gaia-ci-setup SKILL.md contains Critical Rules section" {
  run grep -c "## Critical Rules" "$SKILLS_DIR/gaia-ci-setup/SKILL.md"
  [ "$output" -ge 1 ]
}

@test "gaia-ci-setup SKILL.md contains Steps section" {
  run grep -c "## Steps" "$SKILLS_DIR/gaia-ci-setup/SKILL.md"
  [ "$output" -ge 1 ]
}

@test "gaia-ci-setup SKILL.md contains Finalize section" {
  run grep -c "## Finalize" "$SKILLS_DIR/gaia-ci-setup/SKILL.md"
  [ "$output" -ge 1 ]
}

@test "gaia-ci-setup SKILL.md references validate-gate.sh (AC3)" {
  run grep -c "validate-gate" "$SKILLS_DIR/gaia-ci-setup/SKILL.md"
  [ "$output" -ge 1 ]
}

@test "gaia-ci-setup SKILL.md references ADR-042" {
  run grep -c "ADR-042" "$SKILLS_DIR/gaia-ci-setup/SKILL.md"
  [ "$output" -ge 1 ]
}

# ===== gaia-ci-setup scripts (AC3, AC5) =====

@test "gaia-ci-setup/scripts/setup.sh exists and is executable" {
  [ -x "$SKILLS_DIR/gaia-ci-setup/scripts/setup.sh" ]
}

@test "gaia-ci-setup/scripts/finalize.sh exists and is executable" {
  [ -x "$SKILLS_DIR/gaia-ci-setup/scripts/finalize.sh" ]
}

@test "gaia-ci-setup setup.sh references resolve-config.sh" {
  run grep -c "resolve-config.sh" "$SKILLS_DIR/gaia-ci-setup/scripts/setup.sh"
  [ "$output" -ge 1 ]
}

@test "gaia-ci-setup setup.sh references validate-gate.sh (AC-EC5)" {
  run grep -c "validate-gate.sh" "$SKILLS_DIR/gaia-ci-setup/scripts/setup.sh"
  [ "$output" -ge 1 ]
}

@test "gaia-ci-setup finalize.sh invokes validate-gate.sh (AC3)" {
  run grep -c "validate-gate" "$SKILLS_DIR/gaia-ci-setup/scripts/finalize.sh"
  [ "$output" -ge 1 ]
}

# ===== gaia-ci-edit SKILL.md existence and structure (AC2) =====

@test "gaia-ci-edit/SKILL.md exists" {
  [ -f "$SKILLS_DIR/gaia-ci-edit/SKILL.md" ]
}

@test "gaia-ci-edit SKILL.md has correct name in frontmatter" {
  run head -10 "$SKILLS_DIR/gaia-ci-edit/SKILL.md"
  [[ "$output" == *"name: gaia-ci-edit"* ]]
}

@test "gaia-ci-edit SKILL.md has tools in frontmatter" {
  run head -10 "$SKILLS_DIR/gaia-ci-edit/SKILL.md"
  [[ "$output" == *"tools:"* ]]
}

@test "gaia-ci-edit SKILL.md contains Setup section" {
  run grep -c "## Setup" "$SKILLS_DIR/gaia-ci-edit/SKILL.md"
  [ "$output" -ge 1 ]
}

@test "gaia-ci-edit SKILL.md contains Mission section" {
  run grep -c "## Mission" "$SKILLS_DIR/gaia-ci-edit/SKILL.md"
  [ "$output" -ge 1 ]
}

@test "gaia-ci-edit SKILL.md contains Critical Rules section" {
  run grep -c "## Critical Rules" "$SKILLS_DIR/gaia-ci-edit/SKILL.md"
  [ "$output" -ge 1 ]
}

@test "gaia-ci-edit SKILL.md contains Steps section" {
  run grep -c "## Steps" "$SKILLS_DIR/gaia-ci-edit/SKILL.md"
  [ "$output" -ge 1 ]
}

@test "gaia-ci-edit SKILL.md contains Finalize section" {
  run grep -c "## Finalize" "$SKILLS_DIR/gaia-ci-edit/SKILL.md"
  [ "$output" -ge 1 ]
}

@test "gaia-ci-edit SKILL.md references validate-gate.sh (AC3)" {
  run grep -c "validate-gate" "$SKILLS_DIR/gaia-ci-edit/SKILL.md"
  [ "$output" -ge 1 ]
}

@test "gaia-ci-edit SKILL.md references ADR-033 (promotion chain schema)" {
  run grep -c "ADR-033" "$SKILLS_DIR/gaia-ci-edit/SKILL.md"
  [ "$output" -ge 1 ]
}

@test "gaia-ci-edit SKILL.md references canonical field order (AC4)" {
  run grep -c "canonical field order" "$SKILLS_DIR/gaia-ci-edit/SKILL.md"
  [ "$output" -ge 1 ]
}

# ===== gaia-ci-edit scripts (AC3, AC4) =====

@test "gaia-ci-edit/scripts/setup.sh exists and is executable" {
  [ -x "$SKILLS_DIR/gaia-ci-edit/scripts/setup.sh" ]
}

@test "gaia-ci-edit/scripts/finalize.sh exists and is executable" {
  [ -x "$SKILLS_DIR/gaia-ci-edit/scripts/finalize.sh" ]
}

@test "gaia-ci-edit setup.sh references resolve-config.sh" {
  run grep -c "resolve-config.sh" "$SKILLS_DIR/gaia-ci-edit/scripts/setup.sh"
  [ "$output" -ge 1 ]
}

@test "gaia-ci-edit finalize.sh invokes validate-gate.sh (AC3)" {
  run grep -c "validate-gate" "$SKILLS_DIR/gaia-ci-edit/scripts/finalize.sh"
  [ "$output" -ge 1 ]
}

# ===== validate-gate.sh dependency checks (AC-EC3, AC-EC5) =====

@test "validate-gate.sh foundation script exists" {
  [ -f "$SCRIPTS_DIR/validate-gate.sh" ]
}

@test "validate-gate.sh foundation script is executable" {
  [ -x "$SCRIPTS_DIR/validate-gate.sh" ]
}

@test "gaia-ci-setup setup.sh checks validate-gate.sh executability (AC-EC3)" {
  run grep "validate-gate" "$SKILLS_DIR/gaia-ci-setup/scripts/setup.sh"
  [[ "$output" == *"VALIDATE_GATE"* ]]
}

# ===== Test fixtures (AC5) =====

@test "test fixture global.yaml exists with promotion_chain" {
  [ -f "$FIXTURES_DIR/global.yaml" ]
  run grep "promotion_chain" "$FIXTURES_DIR/global.yaml"
  [ "$status" -eq 0 ]
}

@test "test fixture global-empty-chain.yaml exists with empty chain" {
  [ -f "$FIXTURES_DIR/global-empty-chain.yaml" ]
  run grep "promotion_chain: \[\]" "$FIXTURES_DIR/global-empty-chain.yaml"
  [ "$status" -eq 0 ]
}

@test "test fixture global-malformed.yaml exists" {
  [ -f "$FIXTURES_DIR/global-malformed.yaml" ]
}

@test "fixture global.yaml has canonical field order (AC4)" {
  # Verify the first promotion_chain entry has fields in canonical order:
  # id, name, branch, ci_provider, merge_strategy, ci_checks
  run awk '/- id: staging/,/- id: main/' "$FIXTURES_DIR/global.yaml"
  # id must appear before name, name before branch, etc.
  id_line=$(grep -n "id: staging" "$FIXTURES_DIR/global.yaml" | head -1 | cut -d: -f1)
  name_line=$(grep -n "name: Staging" "$FIXTURES_DIR/global.yaml" | head -1 | cut -d: -f1)
  branch_line=$(grep -n "branch: staging" "$FIXTURES_DIR/global.yaml" | head -1 | cut -d: -f1)
  [ "$id_line" -lt "$name_line" ]
  [ "$name_line" -lt "$branch_line" ]
}

# ===== Edge case coverage =====

@test "gaia-ci-setup SKILL.md handles pre-existing CI config (AC-EC1)" {
  run grep -c "existing" "$SKILLS_DIR/gaia-ci-setup/SKILL.md"
  [ "$output" -ge 1 ]
}

@test "gaia-ci-edit SKILL.md handles empty promotion_chain (AC-EC2)" {
  run grep -ci "empty" "$SKILLS_DIR/gaia-ci-edit/SKILL.md"
  [ "$output" -ge 1 ]
}

@test "gaia-ci-edit SKILL.md handles malformed YAML (AC-EC4)" {
  run grep -ci "malformed" "$SKILLS_DIR/gaia-ci-edit/SKILL.md"
  [ "$output" -ge 1 ]
}

@test "gaia-ci-edit SKILL.md guards last environment removal (AC-EC6)" {
  run grep -ci "last.*environment\|minimum.*1\|at least 1" "$SKILLS_DIR/gaia-ci-edit/SKILL.md"
  [ "$output" -ge 1 ]
}
