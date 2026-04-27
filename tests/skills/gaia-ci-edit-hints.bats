#!/usr/bin/env bats
# E52-S6 — /gaia-ci-edit hint-level audit checks
#
# Covers TC-GR37-32 and TC-GR37-33 from docs/test-artifacts/test-plan.md.
# Script-verifiable greps assert that the SKILL.md body lists cascade targets
# before the confirmation prompt and surfaces cascade failures with both
# `path:` and `reason:` fields.
#
# Audit grep design (per story Technical Notes):
#   TC-GR37-32: cascade-target listing exists ("cascade" + "target"|"affected")
#               AND the listing precedes the Step 7 confirmation prompt.
#   TC-GR37-33: cascade-failure surfacing exists ("cascade" + "failure"|"error")
#               AND mentions both `path:` and `reason:` so failures are
#               diagnosable without re-running the skill.

setup() {
  SKILL_FILE="${BATS_TEST_DIRNAME}/../../plugins/gaia/skills/gaia-ci-edit/SKILL.md"
}

@test "SKILL.md exists" {
  [ -f "$SKILL_FILE" ]
}

@test "TC-GR37-32 — SKILL.md lists cascade targets (grep matches cascade + target|affected)" {
  run bash -c "grep -nE 'cascade.*(target|affected)' '$SKILL_FILE'"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

@test "TC-GR37-32 — cascade-target listing precedes the confirmation prompt in Step 7" {
  # Walk Step 7 and confirm the cascade-target listing appears before the
  # confirmation prompt line — the listing must be visible BEFORE the user
  # commits to the change, not after.
  run awk '
    /^### Step 7/ { in_step = 1 }
    /^### Step 8/ { in_step = 0 }
    in_step && /cascade.*(target|affected)/ && !seen_prompt { seen_targets = 1 }
    in_step && /[Cc]onfirmation prompt|Apply this edit/ { seen_prompt = 1; if (seen_targets) hit = 1 }
    END { exit (hit ? 0 : 1) }
  ' "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "TC-GR37-33 — SKILL.md surfaces cascade failures (grep matches cascade + failure|error)" {
  run bash -c "grep -nE 'cascade.*(failure|error)' '$SKILL_FILE'"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

@test "TC-GR37-33 — cascade-failure surfacing references both path and reason" {
  # Failure surfacing must mention BOTH `path:` and `reason:` so users can
  # diagnose the failing file and the cause without re-running the skill.
  # Walk the cascade-failure section and assert both tokens appear in close
  # proximity (within Step 7).
  run awk '
    /^### Step 7/ { in_step = 1 }
    /^### Step 8/ { in_step = 0 }
    in_step && /path:/ { saw_path = 1 }
    in_step && /reason:/ { saw_reason = 1 }
    END { exit ((saw_path && saw_reason) ? 0 : 1) }
  ' "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "TC-GR37-33 — cascade-failure section forbids silent rollback" {
  # The failure prose must explicitly state that silent rollback is not
  # permitted — this is the AC2 negation that prevents regressions.
  run grep -nE "do NOT rollback|silent failures|rollback-without-diagnosis" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}
