#!/usr/bin/env bats
# E52-S8 — /gaia-perf-testing hint-level audit checks
#
# Covers TC-GR37-38 and TC-GR37-39 from docs/test-artifacts/test-plan.md §11.47.4.
# Script-verifiable greps assert that the SKILL.md body mandates baseline metrics
# capture (with a documented-gap fallback) in Step 1 and enumerates concrete
# critical-rendering-path techniques (lazy loading, code-splitting, image
# optimisation) in Step 3.
#
# Reference: FR-385 (prd.md §4) — gaia-perf-testing baseline metrics + CRP techniques.

setup() {
  SKILL_FILE="${BATS_TEST_DIRNAME}/../../plugins/gaia/skills/gaia-perf-testing/SKILL.md"
}

@test "SKILL.md exists" {
  [ -f "$SKILL_FILE" ]
}

# ---------- TC-GR37-38: Step 1 baseline metrics mandate ----------

@test "TC-GR37-38 — Step 1 mentions baseline metrics co-located with production/staging" {
  # Audit grep: 'baseline' AND 'metrics' must appear in the file, plus
  # 'production' or 'staging' wording in Step 1 prose. The Step 1 mandate
  # replaces the soft 'if available' wording with a two-branch instruction.
  run grep -niE "baseline.*metrics|metrics.*baseline" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [ -n "$output" ]

  run grep -niE "production|staging" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

@test "AC1 — Step 1 mandates baseline capture when prod/staging is available" {
  # The mandate must use MUST language so the action is no longer optional.
  run grep -niE "MUST capture.*baseline|baseline.*MUST capture|MUST.*P50.*P95.*P99" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

@test "AC2 — Step 1 documents the absence as a gap when prod/staging is unavailable" {
  # When neither prod nor staging is available, the skill must instruct the
  # plan to record the absence as a GAP — not silently omit the section.
  run grep -niE "GAP.*no production|GAP.*production or staging|absence.*gap|MUST document the absence" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

# ---------- TC-GR37-39: Step 3 CRP techniques enumeration ----------

@test "TC-GR37-39 — Step 3 names at least two of lazy / code-splitting / image optimi" {
  # AC4: at least two of the three techniques must appear in SKILL.md.
  # Count distinct techniques present (not lines) — they may co-locate on one line.
  count=0
  grep -qiE "lazy" "$SKILL_FILE" && count=$((count + 1))
  grep -qiE "code-splitting|code splitting" "$SKILL_FILE" && count=$((count + 1))
  grep -qiE "image optimi" "$SKILL_FILE" && count=$((count + 1))
  [ "$count" -ge 2 ]
}

@test "AC3 — Step 3 names lazy loading, code-splitting, and image optimisation" {
  # Mandatory minimum set: all three techniques must be named.
  run grep -niE "lazy loading|lazy.loading" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [ -n "$output" ]

  run grep -niE "code-splitting|code splitting" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [ -n "$output" ]

  # Accept either British or American spelling (image optimisation / optimization).
  run grep -niE "image optimi" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

# ---------- AC5: existing budgets and CWV targets preserved ----------

@test "AC5 — Step 1 P50/P95/P99 latency targets preserved" {
  run grep -nE "P50.*P95.*P99|P50, P95, P99" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

@test "AC5 — Step 1 RPS / throughput target preserved" {
  run grep -niE "requests per second|RPS|throughput" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

@test "AC5 — Step 1 error rate threshold preserved" {
  run grep -niE "error rate|0\.1%" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

@test "AC5 — Step 3 LCP / INP / CLS Core Web Vitals targets preserved" {
  run grep -nE "LCP.*2\.5|INP.*200|CLS.*0\.1" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

@test "AC5 — Step 3 Lighthouse CI score threshold preserved" {
  run grep -niE "lighthouse.*90|performance.*> 90|score.*90" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}
