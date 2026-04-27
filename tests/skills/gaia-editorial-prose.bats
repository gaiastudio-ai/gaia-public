#!/usr/bin/env bats
# gaia-editorial-prose.bats — editorial-prose skill structural + content tests (E51-S1)
#
# Validates:
#   TC-GR37-19 / AC1: SKILL.md explicitly documents the default output behaviour
#                     (display-only vs saved-to-disk) in plain language with rationale.
#   TC-GR37-19 / AC2: SKILL.md "Structural observations" guidance clearly states
#                     the observations are awareness-only and cross-references
#                     /gaia-editorial-structure as the canonical full structural-pass skill.
#
# Usage:
#   bats tests/skills/gaia-editorial-prose.bats
#
# Dependencies: bats-core 1.10+

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SKILL_FILE="$REPO_ROOT/plugins/gaia/skills/gaia-editorial-prose/SKILL.md"
}

@test "SKILL.md exists" {
  [ -f "$SKILL_FILE" ]
}

@test "SKILL.md has a dedicated Output Behaviour heading" {
  # Accept any H2/H3 heading whose text starts with 'Output' (e.g., 'Output Behaviour',
  # 'Output', 'Output Behavior'). This is the explicit subsection required by AC1.
  run grep -E '^##+[[:space:]]+Output(\b|[[:space:]])' "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "Output Behaviour subsection states default disposition is display-only" {
  # Plain-language statement that the default is display-only (not saved to disk by default).
  run grep -i -E "default.*display[- ]only|display[- ]only.*default" "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "Output Behaviour subsection includes a save-on-request convention" {
  # Documents that users can save the output explicitly when they want a persisted artifact.
  run grep -i -E "save.*(explicit|request|ask|on demand|if.*want)|user.*save" "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "Output Behaviour subsection includes a one-line rationale" {
  # Rationale tying the default to the editorial review-feedback convention
  # (review output is feedback, not an artifact replacement).
  run grep -i -E "feedback.*not.*(artifact|replacement|persist)|review.*feedback" "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "Structural observations note states findings are awareness-only" {
  # The structural-observations guidance must explicitly mark itself as awareness-only.
  run grep -i -E "awareness[- ]only" "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "Structural observations note cross-references /gaia-editorial-structure" {
  # Cross-reference must use the standard slash-command form so users can invoke directly.
  run grep -E '/gaia-editorial-structure' "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "Structural observations note labels editorial-structure as the canonical full structural pass" {
  # The cross-reference must clearly identify /gaia-editorial-structure as the canonical
  # command for full structural review (not just a related sibling).
  run grep -i -E "canonical.*structural|full structural[- ]pass|canonical.*full structural" "$SKILL_FILE"
  [ "$status" -eq 0 ]
}
