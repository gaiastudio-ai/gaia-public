#!/usr/bin/env bats
# gaia-rollback-plan.bats — rollback plan skill structural tests (E28-S94)
#
# Validates:
#   AC2: SKILL.md exists with rollback trigger criteria and step-by-step procedures
#   AC3: setup.sh/finalize.sh follow shared Cluster 12 pattern (E28-S92, E28-S93)
#   AC5: Behavioral parity — output format matches legacy workflow
#   AC-EC2: Missing deployment state handling
#   AC-EC3: setup.sh missing or not executable detection
#   AC-EC6: Malformed config handling
#   AC-EC7: No orphaned engine-specific XML tags
#
# Usage:
#   bats tests/skills/gaia-rollback-plan.bats
#
# Dependencies: bats-core 1.10+

# ---------- Helpers ----------

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SKILLS_DIR="$REPO_ROOT/plugins/gaia/skills"
  SCRIPTS_DIR="$REPO_ROOT/plugins/gaia/scripts"
  SKILL_DIR="$SKILLS_DIR/gaia-rollback-plan"
  SKILL_FILE="$SKILL_DIR/SKILL.md"
  SETUP_SCRIPT="$SKILL_DIR/scripts/setup.sh"
  FINALIZE_SCRIPT="$SKILL_DIR/scripts/finalize.sh"
}

# ---------- AC2: SKILL.md exists with rollback content ----------

@test "AC2: SKILL.md exists at gaia-rollback-plan skill directory" {
  [ -f "$SKILL_FILE" ]
}

@test "AC2: SKILL.md has YAML frontmatter delimiters" {
  head -1 "$SKILL_FILE" | grep -q "^---$"
  awk 'NR>1 && /^---$/{found=1; exit} END{exit !found}' "$SKILL_FILE"
}

@test "AC2: SKILL.md frontmatter contains name: gaia-rollback-plan" {
  awk '/^---$/{n++; next} n==1{print}' "$SKILL_FILE" | grep -q "^name: gaia-rollback-plan"
}

@test "AC2: SKILL.md frontmatter contains description field" {
  awk '/^---$/{n++; next} n==1{print}' "$SKILL_FILE" | grep -q "^description:"
}

@test "AC2: SKILL.md frontmatter contains tools field" {
  awk '/^---$/{n++; next} n==1{print}' "$SKILL_FILE" | grep -q "^tools:"
}

@test "AC2: SKILL.md covers rollback trigger criteria" {
  grep -qi "trigger.*criteria\|rollback.*trigger\|when.*rollback" "$SKILL_FILE"
}

@test "AC2: SKILL.md covers step-by-step rollback procedure" {
  grep -qi "step.*by.*step\|rollback.*procedure\|procedure" "$SKILL_FILE"
}

@test "AC2: SKILL.md covers data rollback strategy" {
  grep -qi "data.*rollback\|database.*migration\|migration.*reversal" "$SKILL_FILE"
}

@test "AC2: SKILL.md covers communication plan" {
  grep -qi "communication\|notify\|stakeholder" "$SKILL_FILE"
}

@test "AC2: SKILL.md covers automated vs manual triggers" {
  grep -qi "automated\|manual\|automatic" "$SKILL_FILE"
}

@test "AC2: SKILL.md covers rollback duration" {
  grep -qi "duration\|time\|expected.*time" "$SKILL_FILE"
}

@test "AC2: SKILL.md covers verification after rollback" {
  grep -qi "verification\|verify\|post.*rollback" "$SKILL_FILE"
}

# ---------- AC3: Shared setup.sh/finalize.sh pattern ----------

@test "AC3: setup.sh exists and is executable" {
  [ -x "$SETUP_SCRIPT" ]
}

@test "AC3: finalize.sh exists and is executable" {
  [ -x "$FINALIZE_SCRIPT" ]
}

@test "AC3: setup.sh calls resolve-config.sh" {
  grep -q "resolve-config.sh" "$SETUP_SCRIPT"
}

@test "AC3: setup.sh references checkpoint" {
  grep -q "checkpoint" "$SETUP_SCRIPT"
}

@test "AC3: finalize.sh writes checkpoint" {
  grep -q "checkpoint" "$FINALIZE_SCRIPT"
}

@test "AC3: finalize.sh emits lifecycle event" {
  grep -q "lifecycle-event" "$FINALIZE_SCRIPT"
}

@test "AC3: SKILL.md invokes setup.sh at entry" {
  grep -q '!.*setup\.sh' "$SKILL_FILE"
}

@test "AC3: SKILL.md invokes finalize.sh at exit" {
  grep -q '!.*finalize\.sh' "$SKILL_FILE"
}

# ---------- AC5: Output format matches legacy workflow ----------

@test "AC5: SKILL.md produces rollback plan artifact" {
  grep -qi "rollback.*plan\|artifact\|docs/" "$SKILL_FILE"
}

@test "AC5: SKILL.md output includes trigger criteria" {
  grep -qi "trigger.*criteria" "$SKILL_FILE"
}

@test "AC5: SKILL.md output includes procedure steps" {
  grep -qi "procedure\|step.*by.*step" "$SKILL_FILE"
}

# ---------- AC-EC2: Missing deployment state handling ----------

@test "AC-EC2: SKILL.md handles missing deployment state" {
  grep -qi "no.*deployment.*state\|missing.*deployment\|no.*prior.*deployment\|no.*rollback.*target" "$SKILL_FILE"
}

@test "AC-EC2: SKILL.md produces partial plan when state missing" {
  grep -qi "partial.*plan\|warning\|gap" "$SKILL_FILE"
}

# ---------- AC-EC3: setup.sh missing or not executable ----------

@test "AC-EC3: SKILL.md or setup.sh checks script existence" {
  grep -qi "not found\|not executable\|missing.*script\|script.*missing" "$SKILL_FILE" || \
  grep -qi "not found\|not executable" "$SETUP_SCRIPT"
}

# ---------- AC-EC6: Malformed config handling ----------

@test "AC-EC6: SKILL.md handles malformed project config" {
  grep -qi "malformed\|invalid.*config\|config.*error\|empty.*config\|broken" "$SKILL_FILE"
}

@test "AC-EC6: SKILL.md halts on bad config instead of producing broken plan" {
  grep -qi "halt\|error\|abort\|stop\|descriptive.*error" "$SKILL_FILE"
}

# ---------- AC-EC7: No orphaned engine-specific XML tags ----------

@test "AC-EC7: SKILL.md contains no orphaned <action> tags" {
  ! grep -q '<action>' "$SKILL_FILE"
}

@test "AC-EC7: SKILL.md contains no orphaned <template-output> tags" {
  ! grep -q '<template-output>' "$SKILL_FILE"
}

@test "AC-EC7: SKILL.md contains no orphaned <invoke-workflow> tags" {
  ! grep -q '<invoke-workflow>' "$SKILL_FILE"
}

@test "AC-EC7: SKILL.md contains no orphaned <step> tags" {
  ! grep -q '<step ' "$SKILL_FILE"
}

@test "AC-EC7: SKILL.md contains no orphaned <check> tags" {
  ! grep -q '<check ' "$SKILL_FILE"
}

@test "AC-EC7: SKILL.md contains no orphaned <mandate> tags" {
  ! grep -q '<mandate>' "$SKILL_FILE"
}

@test "AC-EC7: SKILL.md contains no orphaned <critical> tags" {
  ! grep -q '<critical>' "$SKILL_FILE"
}

# ---------- AC-EC4: No shared mutable state ----------

@test "AC-EC4: setup.sh uses safe shell defaults" {
  grep -q "set -euo pipefail" "$SETUP_SCRIPT"
}

@test "AC-EC4: finalize.sh uses safe shell defaults" {
  grep -q "set -euo pipefail" "$FINALIZE_SCRIPT"
}
