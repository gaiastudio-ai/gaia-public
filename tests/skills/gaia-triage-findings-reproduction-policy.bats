#!/usr/bin/env bats
# gaia-triage-findings-reproduction-policy.bats — Reproduction-required policy (E28-S223)
#
# Validates:
#   AC1: SKILL.md adds a "Reproduction Required" rule to the findings-table
#        parser. Each finding suggesting a fix must include either a
#        reproduction command in the suggested-action column OR be classified
#        as DISMISS pending reproduction.
#   AC2: gaia-create-story invocations originating from triage embed the
#        reproduction command (when present) into the new story's Origin
#        section.
#   AC3: A "Reproduction Required" policy note is added to SKILL.md
#        referencing feedback_reproduce_before_fix_stories.md.
#
# Usage:
#   bats tests/skills/gaia-triage-findings-reproduction-policy.bats
#
# Dependencies: bats-core 1.10+

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SKILL_FILE="$REPO_ROOT/plugins/gaia/skills/gaia-triage-findings/SKILL.md"
}

# ---------- AC1: Reproduction Required parser rule ----------

@test "AC1: SKILL.md mentions Reproduction Required rule" {
  grep -qi "reproduction required" "$SKILL_FILE"
}

@test "AC1: SKILL.md describes reproduction command in suggested-action column" {
  grep -qi "reproduction command" "$SKILL_FILE"
}

@test "AC1: SKILL.md describes DISMISS pending reproduction" {
  grep -qi "DISMISS.*reproduction\|reproduction.*DISMISS\|dismiss.*pending.*reproduction" "$SKILL_FILE"
}

# ---------- AC2: Reproduction snippet forwarded into new story Origin ----------

@test "AC2: SKILL.md describes embedding reproduction snippet in new story Origin" {
  grep -qi "reproduction.*origin\|origin.*reproduction\|embed.*reproduction" "$SKILL_FILE"
}

@test "AC2: SKILL.md updates create-story spawn to forward the reproduction snippet" {
  # The /gaia-create-story spawn step must forward the reproduction snippet
  # so it lands in the new story's Origin section.
  grep -qi "reproduction" "$SKILL_FILE"
  # And the spawn invocation block still exists (we are not removing it).
  grep -q "/gaia-create-story" "$SKILL_FILE"
}

# ---------- AC3: Policy note + memory cross-reference ----------

@test "AC3: SKILL.md references feedback_reproduce_before_fix_stories memory" {
  grep -q "feedback_reproduce_before_fix_stories" "$SKILL_FILE"
}

@test "AC3: SKILL.md has a Reproduction Policy section heading or Critical-Rules entry" {
  # Either a dedicated subsection OR a Critical-Rules bullet calling out the policy.
  grep -qE "^### .*Reproduction|^## .*Reproduction|^\- \*\*Reproduction" "$SKILL_FILE"
}

# ---------- Regression guard: existing parity tests must still match ----------

@test "Regression: Critical Rules section still present" {
  grep -q "## Critical Rules" "$SKILL_FILE"
}

@test "Regression: Step 4 spawn block still references gaia-create-story" {
  grep -q "/gaia-create-story" "$SKILL_FILE"
}

@test "Regression: SKILL.md still sets status backlog and sprint_id null" {
  grep -q "status: backlog" "$SKILL_FILE"
  grep -q "sprint_id: null" "$SKILL_FILE"
}
