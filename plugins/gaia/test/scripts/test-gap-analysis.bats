#!/usr/bin/env bats
# test-gap-analysis.bats — bats-core tests for gaia-test-gap-analysis skill (E28-S84, AC5)
#
# Validates:
#   - SKILL.md exists with correct frontmatter
#   - setup.sh and finalize.sh exist and are executable
#   - _reference-frontmatter.md exists
#   - gaia-fill-test-gaps SKILL.md exists with correct frontmatter
#   - fill-test-gaps setup.sh and finalize.sh exist and are executable
#   - Fixture project has a known missing test case that gap-analysis should detect

PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SKILLS_DIR="$PLUGIN_DIR/skills"
FIXTURES_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/fixtures/test-gap-analysis" && pwd)"

# ----- gaia-test-gap-analysis SKILL.md existence and structure -----

@test "gaia-test-gap-analysis/SKILL.md exists" {
  [ -f "$SKILLS_DIR/gaia-test-gap-analysis/SKILL.md" ]
}

@test "gaia-test-gap-analysis SKILL.md has correct name in frontmatter" {
  run head -10 "$SKILLS_DIR/gaia-test-gap-analysis/SKILL.md"
  [[ "$output" == *"name: gaia-test-gap-analysis"* ]]
}

@test "gaia-test-gap-analysis SKILL.md has argument-hint in frontmatter" {
  run head -10 "$SKILLS_DIR/gaia-test-gap-analysis/SKILL.md"
  [[ "$output" == *"argument-hint:"* ]]
}

@test "gaia-test-gap-analysis SKILL.md has context: fork in frontmatter" {
  run head -10 "$SKILLS_DIR/gaia-test-gap-analysis/SKILL.md"
  [[ "$output" == *"context: fork"* ]]
}

@test "gaia-test-gap-analysis SKILL.md has allowed-tools: Read Grep Glob Bash" {
  run head -10 "$SKILLS_DIR/gaia-test-gap-analysis/SKILL.md"
  [[ "$output" == *"allowed-tools: Read Grep Glob Bash"* ]]
}

@test "gaia-test-gap-analysis SKILL.md contains Setup section" {
  run grep -c "## Setup" "$SKILLS_DIR/gaia-test-gap-analysis/SKILL.md"
  [ "$output" -ge 1 ]
}

@test "gaia-test-gap-analysis SKILL.md contains Mission section" {
  run grep -c "## Mission" "$SKILLS_DIR/gaia-test-gap-analysis/SKILL.md"
  [ "$output" -ge 1 ]
}

@test "gaia-test-gap-analysis SKILL.md contains Critical Rules section" {
  run grep -c "## Critical Rules" "$SKILLS_DIR/gaia-test-gap-analysis/SKILL.md"
  [ "$output" -ge 1 ]
}

@test "gaia-test-gap-analysis SKILL.md contains Steps section" {
  run grep -c "## Steps" "$SKILLS_DIR/gaia-test-gap-analysis/SKILL.md"
  [ "$output" -ge 1 ]
}

@test "gaia-test-gap-analysis SKILL.md contains Finalize section" {
  run grep -c "## Finalize" "$SKILLS_DIR/gaia-test-gap-analysis/SKILL.md"
  [ "$output" -ge 1 ]
}

@test "gaia-test-gap-analysis SKILL.md references FR-223 schema" {
  run grep -c "FR-223" "$SKILLS_DIR/gaia-test-gap-analysis/SKILL.md"
  [ "$output" -ge 1 ]
}

# ----- E48-S5: inline AC linkage validation + schema pinning -----

@test "E48-S5 AC1: Step 4 mandates inline AC-to-test-case linkage validation in the skill" {
  # Step 4 must explicitly state the skill cross-references ACs against test cases inline
  run grep -E "inline|AC Linkage|AC linkage" "$SKILLS_DIR/gaia-test-gap-analysis/SKILL.md"
  [ "$status" -eq 0 ]
  run grep -c "AC Linkage" "$SKILLS_DIR/gaia-test-gap-analysis/SKILL.md"
  [ "$output" -ge 1 ]
}

@test "E48-S5 AC2: SKILL.md mandates story-key + AC-id flagging for unmapped ACs" {
  # Documentation must show the story-key + AC identifier flagging convention
  run grep -E "unmapped" "$SKILLS_DIR/gaia-test-gap-analysis/SKILL.md"
  [ "$status" -eq 0 ]
  # Example of the flagged format (e.g. "E{n}-S{n} AC{n}: unmapped" or similar)
  run grep -E "AC[0-9]+: unmapped|AC\{n\}: unmapped|AC[0-9]+\".*unmapped|unmapped.*AC" "$SKILLS_DIR/gaia-test-gap-analysis/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "E48-S5 AC2: SKILL.md instructs that linkage is surfaced inline (not solely delegated)" {
  # The inline-surfacing mandate (ADR-063 verdict surfacing)
  run grep -E "ADR-063|verdict|inline by the skill|surfaces" "$SKILLS_DIR/gaia-test-gap-analysis/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "E48-S5 AC3: SKILL.md pins test-plan.md column schema" {
  # Test case ID, Story Key, AC must appear as documented column names
  run grep -E "Test Case ID" "$SKILLS_DIR/gaia-test-gap-analysis/SKILL.md"
  [ "$status" -eq 0 ]
  run grep -E "Story Key" "$SKILLS_DIR/gaia-test-gap-analysis/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "E48-S5 AC3: SKILL.md pins story-key format E{n}-S{n}" {
  # The pinned story key format must be present
  run grep -E "E\{n\}-S\{n\}|E[0-9]+-S[0-9]+" "$SKILLS_DIR/gaia-test-gap-analysis/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "E48-S5 AC3: SKILL.md pins AC identifier format AC{n}" {
  run grep -E "AC\{n\}|AC[0-9]+" "$SKILLS_DIR/gaia-test-gap-analysis/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "E48-S5 AC4: SKILL.md documents required epic: frontmatter field for per-epic grouping" {
  # The epic: frontmatter field must be explicitly documented as required for Step 4c grouping
  run grep -E "epic:.*frontmatter|epic:\` field|required.*epic|epic:.*field" "$SKILLS_DIR/gaia-test-gap-analysis/SKILL.md"
  [ "$status" -eq 0 ]
  # And the E{n} format
  run grep -E "E\{n\}" "$SKILLS_DIR/gaia-test-gap-analysis/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "E48-S5 AC4: SKILL.md documents fallback for missing epic: field" {
  # Stories without epic: get skipped with warning per Dev Notes
  run grep -E "skip story with warning|skip with warning|skip.*missing.*epic|fallback" "$SKILLS_DIR/gaia-test-gap-analysis/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "E48-S5: SKILL.md adds a Pinned Schemas section anchor" {
  # A dedicated section pins the schemas inline (test-plan.md columns + epic frontmatter)
  run grep -E "^## .*Schema|^### .*Schema|Pinned Schema|Schema Pinning" "$SKILLS_DIR/gaia-test-gap-analysis/SKILL.md"
  [ "$status" -eq 0 ]
}

# ----- gaia-test-gap-analysis scripts -----

@test "gaia-test-gap-analysis/scripts/setup.sh exists and is executable" {
  [ -x "$SKILLS_DIR/gaia-test-gap-analysis/scripts/setup.sh" ]
}

@test "gaia-test-gap-analysis/scripts/finalize.sh exists and is executable" {
  [ -x "$SKILLS_DIR/gaia-test-gap-analysis/scripts/finalize.sh" ]
}

@test "gaia-test-gap-analysis setup.sh contains resolve-config invocation" {
  run grep -c "resolve-config" "$SKILLS_DIR/gaia-test-gap-analysis/scripts/setup.sh"
  [ "$output" -ge 1 ]
}

@test "gaia-test-gap-analysis finalize.sh contains checkpoint write invocation" {
  run grep -c "checkpoint" "$SKILLS_DIR/gaia-test-gap-analysis/scripts/finalize.sh"
  [ "$output" -ge 1 ]
}

@test "gaia-test-gap-analysis finalize.sh contains lifecycle-event invocation" {
  run grep -c "lifecycle-event" "$SKILLS_DIR/gaia-test-gap-analysis/scripts/finalize.sh"
  [ "$output" -ge 1 ]
}

# ----- gaia-test-gap-analysis reference frontmatter -----

@test "gaia-test-gap-analysis/_reference-frontmatter.md exists" {
  [ -f "$SKILLS_DIR/gaia-test-gap-analysis/_reference-frontmatter.md" ]
}

# ----- gaia-fill-test-gaps SKILL.md existence and structure -----

@test "gaia-fill-test-gaps/SKILL.md exists" {
  [ -f "$SKILLS_DIR/gaia-fill-test-gaps/SKILL.md" ]
}

@test "gaia-fill-test-gaps SKILL.md has correct name in frontmatter" {
  run head -10 "$SKILLS_DIR/gaia-fill-test-gaps/SKILL.md"
  [[ "$output" == *"name: gaia-fill-test-gaps"* ]]
}

@test "gaia-fill-test-gaps SKILL.md has argument-hint in frontmatter" {
  run head -10 "$SKILLS_DIR/gaia-fill-test-gaps/SKILL.md"
  [[ "$output" == *"argument-hint:"* ]]
}

@test "gaia-fill-test-gaps SKILL.md does NOT have context: fork" {
  run head -10 "$SKILLS_DIR/gaia-fill-test-gaps/SKILL.md"
  [[ "$output" != *"context: fork"* ]]
}

@test "gaia-fill-test-gaps SKILL.md has Write and Edit in allowed-tools" {
  run head -10 "$SKILLS_DIR/gaia-fill-test-gaps/SKILL.md"
  [[ "$output" == *"Write"* ]]
  [[ "$output" == *"Edit"* ]]
}

@test "gaia-fill-test-gaps SKILL.md contains Setup section" {
  run grep -c "## Setup" "$SKILLS_DIR/gaia-fill-test-gaps/SKILL.md"
  [ "$output" -ge 1 ]
}

@test "gaia-fill-test-gaps SKILL.md contains Mission section" {
  run grep -c "## Mission" "$SKILLS_DIR/gaia-fill-test-gaps/SKILL.md"
  [ "$output" -ge 1 ]
}

@test "gaia-fill-test-gaps SKILL.md contains Critical Rules section" {
  run grep -c "## Critical Rules" "$SKILLS_DIR/gaia-fill-test-gaps/SKILL.md"
  [ "$output" -ge 1 ]
}

@test "gaia-fill-test-gaps SKILL.md contains Finalize section" {
  run grep -c "## Finalize" "$SKILLS_DIR/gaia-fill-test-gaps/SKILL.md"
  [ "$output" -ge 1 ]
}

@test "gaia-fill-test-gaps SKILL.md references gap-triage-rules.js" {
  run grep -c "gap-triage-rules" "$SKILLS_DIR/gaia-fill-test-gaps/SKILL.md"
  [ "$output" -ge 1 ]
}

# ----- gaia-fill-test-gaps scripts -----

@test "gaia-fill-test-gaps/scripts/setup.sh exists and is executable" {
  [ -x "$SKILLS_DIR/gaia-fill-test-gaps/scripts/setup.sh" ]
}

@test "gaia-fill-test-gaps/scripts/finalize.sh exists and is executable" {
  [ -x "$SKILLS_DIR/gaia-fill-test-gaps/scripts/finalize.sh" ]
}

# ----- gaia-fill-test-gaps reference frontmatter -----

@test "gaia-fill-test-gaps/_reference-frontmatter.md exists" {
  [ -f "$SKILLS_DIR/gaia-fill-test-gaps/_reference-frontmatter.md" ]
}

# ----- Fixture validation: known gap detection -----

@test "fixture test-plan.md exists" {
  [ -f "$FIXTURES_DIR/test-plan.md" ]
}

@test "fixture story file exists with AC3 that has no test case" {
  [ -f "$FIXTURES_DIR/E99-S1-test-story.md" ]
  # AC3 exists in the story but no TC maps to it in the test plan
  run grep -c "AC3" "$FIXTURES_DIR/E99-S1-test-story.md"
  [ "$output" -ge 1 ]
  # Verify TC-003 does NOT exist in the test plan (AC3 is uncovered)
  run grep -c "TC-003" "$FIXTURES_DIR/test-plan.md"
  [ "$output" -eq 0 ]
}

@test "fixture test-plan covers AC1 and AC2 but not AC3" {
  run grep -c "AC1" "$FIXTURES_DIR/test-plan.md"
  [ "$output" -ge 1 ]
  run grep -c "AC2" "$FIXTURES_DIR/test-plan.md"
  [ "$output" -ge 1 ]
  run grep -c "AC3" "$FIXTURES_DIR/test-plan.md"
  [ "$output" -eq 0 ]
}
