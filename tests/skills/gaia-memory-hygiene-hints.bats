#!/usr/bin/env bats
# E52-S7 — /gaia-memory-hygiene hint-level audit checks
#
# Covers TC-GR37-34 and TC-GR37-35 from docs/test-artifacts/test-plan.md §11.47.4.
# Script-verifiable greps assert that the SKILL.md body documents per-item
# estimated token recovery in archival recommendations and the cross-agent
# read authorisation matrix from _memory/config.yaml#cross_references.

setup() {
  SKILL_FILE="${BATS_TEST_DIRNAME}/../../plugins/gaia/skills/gaia-memory-hygiene/SKILL.md"
}

@test "SKILL.md exists" {
  [ -f "$SKILL_FILE" ]
}

@test "TC-GR37-34 — archival recommendations carry per-item token recovery" {
  # Audit grep: token recovery / estimated must co-locate with archival in
  # the Step 8 / §4 Archival Recommendations prose so reviewers can confirm
  # the per-item recovery field is documented (not just the aggregate budget
  # table from Step 7).
  run grep -niE "token recovery|estimated.*archival|archival.*estimated|estimated recovery" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

@test "TC-GR37-35 — SKILL.md documents cross-agent read authorisation" {
  # Audit grep: cross-agent and authoris/authoriz must co-locate in the
  # Step 4 prose. Matches either ordering ("cross-agent ... authoris" or
  # "authoris ... cross-agent") on a single line.
  run grep -niE "cross-agent.*(authoris|authoriz)|(authoris|authoriz).*cross-agent" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

@test "AC1 — per-item estimated recovery formula references token_approximation" {
  # The Step 8 prose must tie the recovery estimate to the existing
  # archival.token_approximation ratio (default 4 chars/token) so the
  # skill stays single-sourced with the Step 7 Token Budget Table.
  run grep -niE "token_approximation|chars/token|chars per token" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [ -n "$output" ]

  run grep -niE "estimated recovery|~\{?N\}? tokens|bytes.*token_approximation" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

@test "AC2 — Step 4 enumerates the canonical cross-agent reader contexts" {
  # Step 4 must enumerate the nine reader contexts from
  # _memory/config.yaml#cross_references so audit reviewers can verify
  # the matrix is documented, not just referenced by name.
  for reader in architect pm sm orchestrator security devops test-architect validator dev-agents; do
    run grep -nE "$reader" "$SKILL_FILE"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
  done
}

@test "AC3 — Step 4 documents block-and-log gate for unauthorised reads" {
  # The block-and-log gate must instruct the skill to skip the read AND
  # log the denial when a triple is not in the matrix. Both halves of
  # the rule must be present.
  run grep -niE "cross-ref denied|not in matrix|denied.*matrix|skip the read" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

@test "AC5 — AC-EC5 graceful-degrade clause preserved" {
  # The new authorisation prose must NOT remove the existing
  # cross-reference matrix missing fallback. Both the warn-and-continue
  # behaviour and the structural-checks degrade path must remain.
  run grep -nE "AC-EC5" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [ -n "$output" ]

  run grep -niE "structural checks.*budget|degrades to structural" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

@test "AC1 (table) — §4 Archival Recommendations table includes Estimated Recovery column" {
  # Step 10 §4 table header must include the new Estimated Recovery
  # column inserted before Action.
  run grep -nE "Estimated Recovery" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [ -n "$output" ]

  # Confirm column ordering: Estimated Recovery appears before Action
  # within the same table header line.
  run grep -nE "Estimated Recovery.*Action" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}
