#!/usr/bin/env bats
# E52-S1 — /gaia-refresh-ground-truth hint-level audit checks
#
# Covers TC-GR37-22 and TC-GR37-23 from docs/test-artifacts/test-plan.md §11.47.4.
# Script-verifiable greps assert that the SKILL.md body restores the entry
# structure load step and adds an explicit post-refresh token-budget check
# that surfaces archival guidance when usage approaches budget_warn_at.

setup() {
  SKILL_FILE="${BATS_TEST_DIRNAME}/../../plugins/gaia/skills/gaia-refresh-ground-truth/SKILL.md"
}

@test "SKILL.md exists" {
  [ -f "$SKILL_FILE" ]
}

@test "TC-GR37-22 — post-refresh step colocates token + budget + archival" {
  # The post-refresh budget check must mention all three keywords in the same
  # step section so the audit grep can confirm the remediation landed.
  run grep -niE "token.*budget.*archival|budget.*archival.*token|archival.*token.*budget" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

@test "TC-GR37-23 — SKILL.md references budget_warn_at and archival guidance" {
  run grep -nE "budget_warn_at" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [ -n "$output" ]

  run grep -niE "archival guidance|archive.*sidecar|archival next steps" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

@test "AC3 — Load entry structure sub-step appears before scan" {
  # The "Load entry structure" sub-step must be present and ordered before the
  # "Scan Inventory Targets" / scan logic so downstream entries inherit a
  # canonical schema.
  run grep -nE "Load entry structure" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [ -n "$output" ]

  entry_line="$(grep -nE "Load entry structure" "$SKILL_FILE" | head -1 | cut -d: -f1)"
  scan_line="$(grep -nE "Scan Inventory Targets" "$SKILL_FILE" | head -1 | cut -d: -f1)"
  [ -n "$entry_line" ]
  [ -n "$scan_line" ]
  [ "$entry_line" -lt "$scan_line" ]
}

@test "AC2 — post-refresh check reads tier_1.session_budget" {
  run grep -nE "tier_1\.session_budget|tiers\.tier_1\.session_budget" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

@test "AC1 — per-agent budget reporting line documented" {
  # Per-agent reporting must specify used / budget / percentage shape.
  run grep -niE "tokens.*\(.*%\)|<used>/<budget>|used/budget" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}
