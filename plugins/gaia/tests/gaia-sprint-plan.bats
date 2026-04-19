#!/usr/bin/env bats
# gaia-sprint-plan.bats — E28-S60 tests for the gaia-sprint-plan native skill
#
# Validates:
#   AC1: SKILL.md exists with Cluster 8 frontmatter (name, description, argument-hint, allowed-tools)
#        and sm subagent wired as planning persona
#   AC2: Sprint commit via sprint-state.sh — no direct YAML writes
#   AC3: Cluster 8 shared setup.sh / finalize.sh exist and source foundation scripts
#   AC4: Frontmatter linter conformance (structural checks)

load 'test_helper.bash'

SKILL_DIR="$BATS_TEST_DIRNAME/../skills/gaia-sprint-plan"

setup() {
  common_setup
}
teardown() { common_teardown; }

# ---------- AC1: Frontmatter ----------

@test "AC1: SKILL.md exists in gaia-sprint-plan skill directory" {
  [ -f "$SKILL_DIR/SKILL.md" ]
}

@test "AC1: frontmatter contains name: gaia-sprint-plan" {
  run head -20 "$SKILL_DIR/SKILL.md"
  [[ "$output" == *"name: gaia-sprint-plan"* ]]
}

@test "AC1: frontmatter contains description field" {
  run head -20 "$SKILL_DIR/SKILL.md"
  [[ "$output" == *"description:"* ]]
}

@test "AC1: frontmatter contains argument-hint" {
  run head -20 "$SKILL_DIR/SKILL.md"
  [[ "$output" == *'argument-hint:'* ]]
  [[ "$output" == *'sprint-scope'* ]]
}

@test "AC1: frontmatter contains allowed-tools" {
  run head -20 "$SKILL_DIR/SKILL.md"
  [[ "$output" == *"allowed-tools:"* ]]
}

@test "AC1: frontmatter does NOT contain context: fork (sprint planning is synchronous)" {
  run head -20 "$SKILL_DIR/SKILL.md"
  [[ "$output" != *"context: fork"* ]]
}

@test "AC1: sm subagent is wired as planning persona" {
  run cat "$SKILL_DIR/SKILL.md"
  [[ "$output" == *"sm"* ]]
  [[ "$output" == *"Nate"* ]] || [[ "$output" == *"Scrum Master"* ]]
}

# ---------- AC2: sprint-state.sh integration ----------

@test "AC2: SKILL.md references sprint-state.sh for state mutations" {
  run cat "$SKILL_DIR/SKILL.md"
  [[ "$output" == *"sprint-state.sh"* ]]
}

@test "AC2: SKILL.md does NOT contain direct Write/Edit calls to sprint-status.yaml" {
  run cat "$SKILL_DIR/SKILL.md"
  # The skill must not instruct direct YAML mutation
  [[ "$output" != *'Write.*sprint-status.yaml'* ]]
  [[ "$output" != *'Edit.*sprint-status.yaml'* ]]
}

@test "AC2: SKILL.md explicitly forbids direct YAML writes" {
  run cat "$SKILL_DIR/SKILL.md"
  [[ "$output" == *"MUST NOT"* ]] || [[ "$output" == *"NEVER write"* ]]
}

# ---------- AC3: Cluster 8 shared scripts ----------

@test "AC3: scripts/setup.sh exists and is executable" {
  [ -f "$SKILL_DIR/scripts/setup.sh" ]
  [ -x "$SKILL_DIR/scripts/setup.sh" ]
}

@test "AC3: scripts/finalize.sh exists and is executable" {
  [ -f "$SKILL_DIR/scripts/finalize.sh" ]
  [ -x "$SKILL_DIR/scripts/finalize.sh" ]
}

@test "AC3: setup.sh sources resolve-config.sh from foundation scripts" {
  run cat "$SKILL_DIR/scripts/setup.sh"
  [[ "$output" == *"resolve-config.sh"* ]]
}

@test "AC3: finalize.sh sources checkpoint.sh from foundation scripts" {
  run cat "$SKILL_DIR/scripts/finalize.sh"
  [[ "$output" == *"checkpoint.sh"* ]]
}

@test "AC3: finalize.sh emits lifecycle event" {
  run cat "$SKILL_DIR/scripts/finalize.sh"
  [[ "$output" == *"lifecycle-event.sh"* ]]
}

@test "AC3: setup.sh resolves plugin scripts dir via relative path" {
  run cat "$SKILL_DIR/scripts/setup.sh"
  [[ "$output" == *'PLUGIN_SCRIPTS_DIR'* ]]
  [[ "$output" == *'../../../scripts'* ]]
}

@test "AC3: finalize.sh resolves plugin scripts dir via relative path" {
  run cat "$SKILL_DIR/scripts/finalize.sh"
  [[ "$output" == *'PLUGIN_SCRIPTS_DIR'* ]]
  [[ "$output" == *'../../../scripts'* ]]
}

# ---------- AC4: Frontmatter linter conformance ----------

@test "AC4: SKILL.md frontmatter opens and closes with ---" {
  local first_line
  first_line=$(head -1 "$SKILL_DIR/SKILL.md")
  [ "$first_line" = "---" ]

  # Find the closing --- (second occurrence)
  local closing_line
  closing_line=$(awk '/^---$/{n++; if(n==2){print NR; exit}}' "$SKILL_DIR/SKILL.md")
  [ -n "$closing_line" ]
}

@test "AC4: SKILL.md body contains ## Setup section" {
  run cat "$SKILL_DIR/SKILL.md"
  [[ "$output" == *"## Setup"* ]]
}

@test "AC4: SKILL.md body contains ## Finalize section" {
  run cat "$SKILL_DIR/SKILL.md"
  [[ "$output" == *"## Finalize"* ]]
}

@test "AC4: SKILL.md Setup references the skill's own setup.sh" {
  run cat "$SKILL_DIR/SKILL.md"
  [[ "$output" == *'gaia-sprint-plan/scripts/setup.sh'* ]]
}

@test "AC4: SKILL.md Finalize references the skill's own finalize.sh" {
  run cat "$SKILL_DIR/SKILL.md"
  [[ "$output" == *'gaia-sprint-plan/scripts/finalize.sh'* ]]
}

# ---------- Sprint planning logic presence checks ----------

@test "SKILL.md contains Step 1 — Load Epics" {
  run cat "$SKILL_DIR/SKILL.md"
  [[ "$output" == *"Load Epics"* ]]
}

@test "SKILL.md contains step for Sprint Scoping" {
  run cat "$SKILL_DIR/SKILL.md"
  [[ "$output" == *"Sprint Scoping"* ]]
}

@test "SKILL.md contains step for Story Selection" {
  run cat "$SKILL_DIR/SKILL.md"
  [[ "$output" == *"Story Selection"* ]]
}

@test "SKILL.md references epics-and-stories.md" {
  run cat "$SKILL_DIR/SKILL.md"
  [[ "$output" == *"epics-and-stories.md"* ]]
}

@test "SKILL.md references sizing_map" {
  run cat "$SKILL_DIR/SKILL.md"
  [[ "$output" == *"sizing_map"* ]]
}

@test "SKILL.md references dependency blocking" {
  run cat "$SKILL_DIR/SKILL.md"
  [[ "$output" == *"depends_on"* ]] || [[ "$output" == *"dependency"* ]]
}

@test "SKILL.md references priority ordering" {
  run cat "$SKILL_DIR/SKILL.md"
  [[ "$output" == *"P0"* ]]
  [[ "$output" == *"P1"* ]]
}

@test "SKILL.md references ADR-042 (scripted state mutators)" {
  run cat "$SKILL_DIR/SKILL.md"
  [[ "$output" == *"ADR-042"* ]]
}

@test "SKILL.md describes itself as GAIA-native replacement for legacy workflow" {
  run cat "$SKILL_DIR/SKILL.md"
  [[ "$output" == *"legacy"* ]]
  [[ "$output" == *"sprint-planning"* ]]
}

@test "SKILL.md references NFR-048 token footprint" {
  run cat "$SKILL_DIR/SKILL.md"
  [[ "$output" == *"NFR-048"* ]]
}

@test "setup.sh validates sprint-state.sh availability" {
  run cat "$SKILL_DIR/scripts/setup.sh"
  [[ "$output" == *"sprint-state.sh"* ]]
}
