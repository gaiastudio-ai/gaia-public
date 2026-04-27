#!/usr/bin/env bats
# E52-S5 — /gaia-performance-review hint-level audit checks
#
# Covers TC-GR37-30 and TC-GR37-31 from docs/test-artifacts/test-plan.md §11.47.4.
# Script-verifiable greps assert that the SKILL.md body operationalises percentile
# extraction (P50/P95/P99) inside the measurement steps and logs every
# perf-relevant file analysed in the report — even when no findings fire.
#
# Audit grep design (per story Technical Notes):
#   TC-GR37-30: percentile keywords appear inside the Steps section, not only
#               in the existing critical-rules disclaimer line ("Percentiles,
#               not averages"). The grep filters out that disclaimer.
#   TC-GR37-31: Step 8 contains "log" co-located with "files analysed" or
#               "no findings".

setup() {
  SKILL_FILE="${BATS_TEST_DIRNAME}/../../plugins/gaia/skills/gaia-performance-review/SKILL.md"
}

@test "SKILL.md exists" {
  [ -f "$SKILL_FILE" ]
}

@test "TC-GR37-30 — percentile extraction referenced inside Steps section (not only disclaimer)" {
  # Strip the existing critical-rules disclaimer line, then assert that the
  # remaining body still mentions P50/P95/P99/percentile — proving the
  # operationalisation landed inside an actual step rather than only the rule.
  run bash -c "grep -nE 'P50|P95|P99|percentile' '$SKILL_FILE' | grep -v 'Percentiles, not averages' | grep -v '^[[:space:]]*[0-9]*:.*Critical Rules'"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

@test "TC-GR37-30 — percentile keywords appear in measurement steps (Step 4 / 5 / 6) or output (Step 8)" {
  # Walk the file and confirm at least one P50/P95/P99/percentile mention sits
  # below the Step 4 heading and above the Finalize section so the keyword is
  # operationalised in the prescriptive steps, not only in the rules block.
  run awk '
    /^### Step 4/ { in_steps = 1 }
    /^## Finalize/ { in_steps = 0 }
    in_steps && /P50|P95|P99|percentile/ { hit = 1 }
    END { exit (hit ? 0 : 1) }
  ' "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "TC-GR37-31 — Step 8 logs files analysed (every perf-relevant file)" {
  # Step 8 must contain "log" (or equivalent record/list directive) co-located
  # with either "files analysed" or "no findings" so reviewers can audit the
  # full classifier output.
  run awk '
    /^### Step 8/ { in_step8 = 1 }
    /^### Step 9/ { in_step8 = 0 }
    in_step8 && /[Ll]og.*files analysed|files analysed.*[Ll]og|[Ll]og.*no findings|no findings.*[Ll]og/ { hit = 1 }
    END { exit (hit ? 0 : 1) }
  ' "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "TC-GR37-31 — Step 8 instructs to list every perf-relevant file (no-findings annotation)" {
  # The file-list rendering must explicitly annotate clean files with
  # "no findings" so reviewers can distinguish skipped from analysed-clean.
  run awk '
    /^### Step 8/ { in_step8 = 1 }
    /^### Step 9/ { in_step8 = 0 }
    in_step8 && /no findings/ { hit = 1 }
    END { exit (hit ? 0 : 1) }
  ' "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "AC1 / AC3 — measurement steps cite percentile values, not averages" {
  # Step 4 (N+1 / Database) MUST cite percentile latency values explicitly.
  run awk '
    /^### Step 4/ { in_step4 = 1 }
    /^### Step 5/ { in_step4 = 0 }
    in_step4 && /P50|P95|P99/ { hit = 1 }
    END { exit (hit ? 0 : 1) }
  ' "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "AC1 — Step 5 (Memory and Bundle) operationalises percentile extraction" {
  # Memory percentiles (heap, RSS) MUST be cited where profiling output is
  # available. Story Task 1 extends the percentile pattern from Step 4 to
  # Step 5 for memory metrics.
  run awk '
    /^### Step 5/ { in_step5 = 1 }
    /^### Step 6/ { in_step5 = 0 }
    in_step5 && /P50|P95|P99|percentile/ { hit = 1 }
    END { exit (hit ? 0 : 1) }
  ' "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "AC1 — Step 6 (Caching and Complexity) operationalises percentile extraction" {
  # Throughput percentiles MUST be cited where benchmark output is available.
  # Story Task 1 extends the percentile pattern to Step 6 for throughput.
  run awk '
    /^### Step 6/ { in_step6 = 1 }
    /^### Step 7/ { in_step6 = 0 }
    in_step6 && /P50|P95|P99|percentile/ { hit = 1 }
    END { exit (hit ? 0 : 1) }
  ' "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "AC2 / AC4 — Step 8 Files Reviewed renders the full classifier output" {
  # Description of the Files Reviewed section must indicate completeness —
  # "every perf-relevant file" or "full classifier output".
  run awk '
    /^### Step 8/ { in_step8 = 1 }
    /^### Step 9/ { in_step8 = 0 }
    in_step8 && /every perf-relevant file|full classifier output|all perf-relevant files/ { hit = 1 }
    END { exit (hit ? 0 : 1) }
  ' "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "AC6 — auto-pass critical-rule preserved" {
  # The auto-pass fast-path rule must remain intact — Step 8 changes must NOT
  # remove the "No performance-relevant code changes — auto-passed" path.
  run grep -nE "No performance-relevant code changes — auto-passed" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

@test "AC6 — auto-pass branch in Step 3 unchanged (still skips to Step 8)" {
  # Sanity guard: Step 3 must still emit the directive to skip Steps 4–7 on
  # auto-pass, so AC6 (auto-pass regression guard) does not regress.
  run grep -nE "Skip Steps 4.7|Skip Steps 4–7|Skip Steps 4-7" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

@test "Step 8 Measurements sub-block exists when percentiles are extracted" {
  # AC1: report must record extracted percentiles per file. A "Measurements"
  # sub-block (or the relevant analysis section) must be enumerated.
  run awk '
    /^### Step 8/ { in_step8 = 1 }
    /^### Step 9/ { in_step8 = 0 }
    in_step8 && /Measurements|measurements per file|percentile values/ { hit = 1 }
    END { exit (hit ? 0 : 1) }
  ' "$SKILL_FILE"
  [ "$status" -eq 0 ]
}
