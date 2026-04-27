#!/usr/bin/env bats
# E52-S10 — /gaia-teach-testing hint-level audit checks
#
# Covers TC-GR37-42 and TC-GR37-43 from docs/test-artifacts/test-plan.md §11.47.4.
# Script-verifiable greps assert that the SKILL.md body operationalises:
#   - the JIT knowledge-fragment load discipline with an explicit pre-load
#     prohibition (TC-GR37-42)
#   - the progressive-lesson rule with skill-level gating that excludes
#     advanced topics from beginner sessions (TC-GR37-43)

setup() {
  SKILL_FILE="${BATS_TEST_DIRNAME}/../../plugins/gaia/skills/gaia-teach-testing/SKILL.md"
}

@test "SKILL.md exists" {
  [ -f "$SKILL_FILE" ]
}

@test "TC-GR37-42 — JIT load discipline co-located with pre-load prohibition" {
  # Audit grep: JIT (or just-in-time) must co-locate with a pre-load
  # prohibition on a single line so reviewers can confirm the discipline
  # is documented, not implied. Either ordering matches.
  run grep -niE "(JIT|just-in-time).*(pre-load|pre-loaded)|(pre-load|pre-loaded).*(JIT|just-in-time)" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

@test "TC-GR37-43 — progressive rule co-locates progressive, beginner, advanced" {
  # Audit grep: a single line must co-locate 'progressive', 'beginner',
  # and 'advanced' so reviewers can confirm the skill-level gating rule
  # is documented as one cohesive statement (not three incidental
  # mentions across the file).
  run grep -niE "progressive.*beginner.*advanced|progressive.*advanced.*beginner|beginner.*progressive.*advanced|beginner.*advanced.*progressive|advanced.*beginner.*progressive|advanced.*progressive.*beginner" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

@test "AC1 — Critical Rules block prohibits pre-loading knowledge fragments" {
  # The pre-load prohibition must live in the Critical Rules block (lines
  # 18–26 region) so the rule has hint-level visibility, not just incidental
  # mention elsewhere in the file.
  run grep -niE "MUST NOT be pre-loaded|not be pre-loaded|never pre-load" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

@test "AC2 — progressive rule names the gated advanced topics" {
  # The progressive rule extension must enumerate the advanced topics that
  # are gated for beginner sessions: property-based, mutation, contract
  # testing. All three keywords must appear in the file body.
  run grep -niE "property-based|property based" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [ -n "$output" ]

  run grep -niE "mutation testing|mutation test" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [ -n "$output" ]

  run grep -niE "contract testing|contract test" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

@test "AC3 — Step 2 documents skill-level gating tied to Step 1 assessment" {
  # Step 2 must document that the topic block presented is gated by the
  # Step 1 skill-level assessment with an explicit ONLY-this-block rule
  # for beginner sessions. Match a strong gating phrase, not just the
  # incidental 'based on the assessed skill level' line.
  run grep -niE "Present ONLY|only the.*topic block|only the Beginner|gated by the Step 1|gated by Step 1" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

@test "AC5 — existing JIT and progressive Critical Rules preserved" {
  # The original line 20 JIT rule and line 22 progressive rule must remain
  # in the file body — the new prose extends them, it does not replace
  # them. Match the canonical phrasing of each.
  run grep -nE "load them JIT when referenced by a step" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [ -n "$output" ]

  run grep -nE "Load knowledge progressively" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}
