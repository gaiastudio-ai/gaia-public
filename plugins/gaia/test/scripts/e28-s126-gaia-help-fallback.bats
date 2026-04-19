#!/usr/bin/env bats
# e28-s126-gaia-help-fallback.bats — bats-core tests for the gaia-help SKILL.md
# missing-file fallback contract (Val v1 Finding 8 / E28-S126 AC6).
#
# Context: gaia-help SKILL.md already has partial AC-EC2 handling documented at lines 19, 32
# ("refuse to suggest any command and fall back to /gaia when workflow-manifest.csv is missing").
# Under the native plugin (post-cleanup) workflow-manifest.csv is gone, so this fallback MUST
# be the canonical behavior. These tests enforce the contract at the SKILL.md level.
#
# The skill is prose (instructions for Claude), not executable code. We validate the skill
# *documents* the fallback contract explicitly and with the expected keywords so downstream
# conversion work can rely on it.

PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SKILL="$PLUGIN_DIR/skills/gaia-help/SKILL.md"

@test "gaia-help/SKILL.md exists" {
  [ -f "$SKILL" ]
}

@test "AC-EC2 fallback is documented — 'missing' + 'fall back'" {
  run grep -iE "missing.*fall back|fall back.*missing|workflow-manifest.*missing" "$SKILL"
  [ "$status" -eq 0 ]
}

@test "fallback says fall back to /gaia (no hallucination)" {
  run grep -E "fall back to \`?/gaia\`?" "$SKILL"
  [ "$status" -eq 0 ]
}

@test "skill documents non-negotiable no-hallucination rule" {
  run grep -iE "no.hallucination|never invent|do not invent|do NOT invent" "$SKILL"
  [ "$status" -eq 0 ]
}

@test "skill notes emit warning when manifest missing or unreadable" {
  run grep -iE "emit the warning|warning.*missing|missing.*warning" "$SKILL"
  [ "$status" -eq 0 ]
}

@test "skill does NOT mandate hard-fail on missing manifest" {
  # If the skill ever adds an 'exit non-zero' or 'HALT' directive on missing manifest,
  # that contradicts the fallback contract.
  run grep -iE "missing.*(HALT|exit non-zero|abort|error out)" "$SKILL"
  # grep -i returns 0 on match; we expect NO match → status != 0
  [ "$status" -ne 0 ]
}
