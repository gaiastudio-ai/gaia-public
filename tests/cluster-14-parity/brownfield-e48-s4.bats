#!/usr/bin/env bats
# brownfield-e48-s4.bats — E48-S4 test-env pause + per-subagent scan diagnostics
#
# Validates that gaia-brownfield SKILL.md:
#   AC1: In normal mode, after test-environment.yaml is generated in Phase 5,
#        the skill pauses and presents the file content summary for user review
#        before continuing to Phase 6.
#   AC2: In YOLO mode, after test-environment.yaml is generated, the skill
#        auto-continues without pausing (existing behavior preserved).
#   AC3: After Phase 3 multi-scan execution completes, a per-subagent status
#        log is surfaced with one row per scan subagent showing status
#        (success / timeout / resource-capped / errored) and reason.
#   AC4: A timed-out or errored scan shows the appropriate status with a
#        reason string (not silently omitted from the diagnostic log).
#
# Cross-cutting structural requirements (E48 epic anchors):
#   - ADR-063: Mandatory verdict surfacing (PASS/WARNING/CRITICAL) for
#     subagent dispatch — no silent gates.
#   - ADR-037: Structured subagent return schema
#     ({status, summary, artifacts, findings, next}).
#   - ADR-045: Fork-context read-only subagent dispatch pattern.
#   - ADR-067: YOLO behavior — CRITICAL still halts; auto-continue otherwise.
#   - ADR-042: No new scripts (only setup.sh + finalize.sh in scripts/).
#
# Refs: E48-S4, FR-365, ADR-021, ADR-037, ADR-041, ADR-042, ADR-045,
#       ADR-063, ADR-067, NFR-024, NFR-046, NFR-048
#
# Usage:
#   bats tests/cluster-14-parity/brownfield-e48-s4.bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SKILLS_DIR="$REPO_ROOT/plugins/gaia/skills"
  SKILL="gaia-brownfield"
  SKILL_DIR="$SKILLS_DIR/$SKILL"
  SKILL_FILE="$SKILL_DIR/SKILL.md"
}

# ---------- Existence + frontmatter sanity ----------

@test "E48-S4: gaia-brownfield SKILL.md exists" {
  [ -f "$SKILL_FILE" ]
}

@test "E48-S4: SKILL.md frontmatter declares allowed-tools (orchestrator)" {
  local tools_line
  tools_line=$(head -20 "$SKILL_FILE" | grep '^allowed-tools:')
  [[ "$tools_line" == *"Read"* ]]
  [[ "$tools_line" == *"Agent"* ]]
}

# ---------- AC1: Phase 5 normal-mode review pause ----------

@test "E48-S4: SKILL.md describes normal-mode review pause after test-environment.yaml write" {
  grep -qiE 'normal mode.*(pause|review)' "$SKILL_FILE"
}

@test "E48-S4: SKILL.md Phase 5 references the test-environment.yaml file path in the pause" {
  # The pause must surface the path so the user knows what to review.
  grep -qE 'docs/test-artifacts/test-environment\.yaml' "$SKILL_FILE"
}

@test "E48-S4: SKILL.md Phase 5 pause summary lists detected infrastructure fields" {
  # Summary must mention test runners / CI provider / docker / browser matrix
  # so the user can review what was detected before proceeding to Phase 6.
  grep -qiE 'test[_ -]runner' "$SKILL_FILE"
  grep -qiE 'ci[_ -]provider' "$SKILL_FILE"
  grep -qiE 'docker' "$SKILL_FILE"
  grep -qiE 'browser[_ -]matrix' "$SKILL_FILE"
}

@test "E48-S4: SKILL.md Phase 5 pause precedes Phase 6 (NFR Assessment)" {
  # The pause language must position itself before continuing to Phase 6.
  grep -qiE '(before continuing to Phase 6|before proceeding to Phase 6|before Phase 6)' "$SKILL_FILE"
}

# ---------- AC2: YOLO mode auto-continue (no pause) ----------

@test "E48-S4: SKILL.md states YOLO mode skips the Phase 5 review pause" {
  grep -qiE 'yolo.*(skip|auto[- ]continue|no pause)' "$SKILL_FILE"
}

@test "E48-S4: SKILL.md preserves YOLO safe-default merge behavior" {
  # Pre-existing behavior — YOLO uses safe default merge for conflicts.
  grep -qiE 'yolo.*(merge|safe default)' "$SKILL_FILE"
}

# ---------- AC3: Per-subagent scan diagnostic table (Phase 3) ----------

@test "E48-S4: SKILL.md Phase 3 declares a per-subagent scan status log/table" {
  grep -qiE '(per[- ]subagent|scan diagnostic|scan status log)' "$SKILL_FILE"
}

@test "E48-S4: SKILL.md Phase 3 diagnostic table declares Status column" {
  # Look for a table header that includes Status.
  grep -qE 'Scan Subagent.*Status|Status.*Reason|Subagent.*Status.*Duration' "$SKILL_FILE"
}

@test "E48-S4: SKILL.md Phase 3 diagnostic table declares Reason column" {
  grep -qE 'Reason' "$SKILL_FILE"
}

@test "E48-S4: SKILL.md Phase 3 lists all four canonical statuses" {
  grep -qE 'success' "$SKILL_FILE"
  grep -qE 'timeout' "$SKILL_FILE"
  grep -qE 'resource-capped' "$SKILL_FILE"
  grep -qE 'errored' "$SKILL_FILE"
}

@test "E48-S4: SKILL.md describes diagnostic-table surfacing point (after Phase 3 scans)" {
  grep -qiE '(after.*phase 3|after.*all seven|after.*scans complete|post[- ]scan)' "$SKILL_FILE"
}

# ---------- AC4: Reason strings for timeout / errored ----------

@test "E48-S4: SKILL.md says timeout/errored entries carry a reason string (not silently omitted)" {
  grep -qiE 'reason string' "$SKILL_FILE"
  grep -qiE '(not silently omitted|do not silently omit|never silently omit)' "$SKILL_FILE"
}

@test "E48-S4: SKILL.md ties resource-capped to NFR-024 / NFR-048 truncation advisory" {
  grep -qE 'NFR-024' "$SKILL_FILE"
}

# ---------- ADR-063: Subagent Dispatch Contract / verdict surfacing ----------

@test "E48-S4: SKILL.md includes a Subagent Dispatch Contract section" {
  grep -qE '^## Subagent Dispatch Contract|^### Subagent Dispatch Contract' "$SKILL_FILE"
}

@test "E48-S4: SKILL.md surfaces verdict vocabulary (PASS/WARNING/CRITICAL)" {
  grep -q 'CRITICAL' "$SKILL_FILE"
  grep -q 'WARNING' "$SKILL_FILE"
  grep -qE 'PASS|status' "$SKILL_FILE"
}

@test "E48-S4: SKILL.md codifies halt-on-CRITICAL semantics (ADR-063)" {
  grep -qiE 'halt.*CRITICAL|CRITICAL.*halt' "$SKILL_FILE"
}

@test "E48-S4: SKILL.md references ADR-037 structured return schema" {
  grep -q 'ADR-037' "$SKILL_FILE"
}

# ---------- ADR-067: YOLO behavior ----------

@test "E48-S4: SKILL.md includes a YOLO Behavior section" {
  grep -qE '^## YOLO Behavior|^### YOLO Behavior' "$SKILL_FILE"
}

@test "E48-S4: YOLO mode auto-displays verdict but halts on CRITICAL" {
  grep -qiE 'CRITICAL.*still.*halt|CRITICAL.*halt.*YOLO|YOLO.*CRITICAL.*halt' "$SKILL_FILE"
}

# ---------- ADR refs and traceability ----------

@test "E48-S4: SKILL.md references ADR-021 (deep brownfield analysis)" {
  grep -q 'ADR-021' "$SKILL_FILE"
}

@test "E48-S4: SKILL.md references ADR-041 (Native Execution)" {
  grep -q 'ADR-041' "$SKILL_FILE"
}

@test "E48-S4: SKILL.md references ADR-042 (Scripts-over-LLM)" {
  grep -q 'ADR-042' "$SKILL_FILE"
}

@test "E48-S4: SKILL.md references ADR-063 (Subagent Dispatch Contract)" {
  grep -q 'ADR-063' "$SKILL_FILE"
}

@test "E48-S4: SKILL.md references ADR-067 (YOLO Mode Contract)" {
  grep -q 'ADR-067' "$SKILL_FILE"
}

# ---------- ADR-042 no-new-scripts: only setup/finalize allowed ----------

@test "E48-S4: gaia-brownfield scripts/ contains only setup.sh and finalize.sh" {
  cd "$SKILL_DIR/scripts"
  count="$(ls -1 | wc -l | tr -d ' ')"
  [ "$count" = "2" ]
  [ -f "setup.sh" ]
  [ -f "finalize.sh" ]
}

# ---------- Layout constraints (native skill) ----------

@test "E48-S4: gaia-brownfield/ has no workflow.yaml (native skill)" {
  [ ! -f "$SKILL_DIR/workflow.yaml" ]
}

@test "E48-S4: gaia-brownfield/ has no instructions.xml (native skill)" {
  [ ! -f "$SKILL_DIR/instructions.xml" ]
}

# ---------- Linter compliance ----------

@test "E48-S4: lint-skill-frontmatter.sh passes on gaia-brownfield SKILL.md" {
  cd "$REPO_ROOT"
  bash .github/scripts/lint-skill-frontmatter.sh
}
