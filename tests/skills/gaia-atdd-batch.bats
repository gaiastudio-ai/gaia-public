#!/usr/bin/env bats
# gaia-atdd-batch.bats — /gaia-atdd batch mode + red-phase + graceful exit (E46-S3)
#
# Implements VCP-ATDD-01..VCP-ATDD-05 from docs/test-artifacts/test-plan.md §11.46.11.
#
# Validates the new behaviors on top of the existing single-story /gaia-atdd skill:
#   AC1     / VCP-ATDD-01 — argumentless invocation discovers high-risk stories from
#                           epics-and-stories.md and renders the [all/select/skip] menu
#   AC2     / VCP-ATDD-02 — `all` selection generates ATDD artifacts for every discovered story
#   AC3     / VCP-ATDD-03 — `select` selection generates ATDD artifacts only for chosen stories
#   AC4     / VCP-ATDD-04 — red-phase execution reports pass/fail counts; runner-detection fallback
#   AC5     / VCP-ATDD-05 — zero high-risk stories exits gracefully (exit 0) with the canonical message
#   AC-EC1..AC-EC11    — eleven edge cases (missing file, single story, idempotency, atomic write, etc.)
#
# These tests target the helper scripts that the SKILL.md will invoke:
#   plugins/gaia/skills/gaia-atdd/scripts/discover-stories.sh
#   plugins/gaia/skills/gaia-atdd/scripts/run-red-phase.sh
#
# Usage:
#   bats tests/skills/gaia-atdd-batch.bats
#
# Dependencies: bats-core 1.10+

# ---------- Helpers ----------

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SKILL_DIR="$REPO_ROOT/plugins/gaia/skills/gaia-atdd"
  SKILL_FILE="$SKILL_DIR/SKILL.md"
  DISCOVER_SCRIPT="$SKILL_DIR/scripts/discover-stories.sh"
  RED_PHASE_SCRIPT="$SKILL_DIR/scripts/run-red-phase.sh"

  # Per-test isolated workspace
  TEST_TMP="$BATS_TEST_TMPDIR/gaia-atdd-batch-$$"
  mkdir -p "$TEST_TMP/docs/planning-artifacts" \
           "$TEST_TMP/docs/test-artifacts" \
           "$TEST_TMP/docs/implementation-artifacts"

  EPICS_FILE="$TEST_TMP/docs/planning-artifacts/epics-and-stories.md"
  TEST_ARTIFACTS="$TEST_TMP/docs/test-artifacts"
}

# Build a fixture epics-and-stories.md with the given counts of high/med/low risk stories.
# Args: $1=high count, $2=medium count, $3=low count
_build_epics_fixture() {
  local high="$1" med="$2" low="$3"
  local i=1
  {
    echo "# Epics and Stories"
    echo ""
    echo "## E99 — Test Fixture Epic"
    echo ""
    echo "| Key | Title | Size | Priority | Risk |"
    echo "|-----|-------|------|----------|------|"
    while [ "$i" -le "$high" ]; do
      printf '| E99-S%d | High risk story %d | M | P1 | high |\n' "$i" "$i"
      i=$((i + 1))
    done
    local j=1
    while [ "$j" -le "$med" ]; do
      printf '| E99-M%d | Medium risk story %d | M | P2 | medium |\n' "$j" "$j"
      j=$((j + 1))
    done
    local k=1
    while [ "$k" -le "$low" ]; do
      printf '| E99-L%d | Low risk story %d | S | P3 | low |\n' "$k" "$k"
      k=$((k + 1))
    done
  } > "$EPICS_FILE"
}

# Build a story file in implementation-artifacts/ with N acceptance criteria.
# Args: $1=story_key, $2=ac count
_build_story_file() {
  local key="$1" ac_count="$2"
  local file="$TEST_TMP/docs/implementation-artifacts/${key}-fixture.md"
  {
    echo "---"
    echo "key: \"$key\""
    echo "title: \"Fixture story $key\""
    echo "status: ready-for-dev"
    echo "risk: \"high\""
    echo "---"
    echo ""
    echo "# Story: $key"
    echo ""
    echo "## Acceptance Criteria"
    echo ""
    local i=1
    while [ "$i" -le "$ac_count" ]; do
      printf '- [ ] **AC%d:** Fixture acceptance criterion %d.\n' "$i" "$i"
      i=$((i + 1))
    done
  } > "$file"
}

# ---------- AC1 / VCP-ATDD-01 — Batch discovery + menu ----------

@test "VCP-ATDD-01: discover-stories.sh exists and is executable" {
  [ -x "$DISCOVER_SCRIPT" ]
}

@test "VCP-ATDD-01: discovery scans epics-and-stories.md and lists 3 high-risk stories" {
  _build_epics_fixture 3 2 1
  run "$DISCOVER_SCRIPT" --epics "$EPICS_FILE" --format=keys
  [ "$status" -eq 0 ]
  [[ "$output" == *"E99-S1"* ]]
  [[ "$output" == *"E99-S2"* ]]
  [[ "$output" == *"E99-S3"* ]]
  # Medium / low risk MUST NOT appear
  [[ "$output" != *"E99-M1"* ]]
  [[ "$output" != *"E99-L1"* ]]
}

@test "VCP-ATDD-01: discovery menu output includes the [all / select / skip] tokens for >1 story" {
  _build_epics_fixture 3 0 0
  run "$DISCOVER_SCRIPT" --epics "$EPICS_FILE" --format=menu
  [ "$status" -eq 0 ]
  [[ "$output" == *"all"* ]]
  [[ "$output" == *"select"* ]]
  [[ "$output" == *"skip"* ]]
}

@test "VCP-ATDD-01: discovery menu lists key, title, and risk for each story" {
  _build_epics_fixture 2 0 0
  run "$DISCOVER_SCRIPT" --epics "$EPICS_FILE" --format=menu
  [ "$status" -eq 0 ]
  [[ "$output" == *"E99-S1"* ]]
  [[ "$output" == *"High risk story 1"* ]]
  [[ "$output" == *"high"* ]]
}

# ---------- AC2 / VCP-ATDD-02 — `all` selection ----------

@test "VCP-ATDD-02: discovery emits a stable, ordered keys list usable by 'all' iteration" {
  _build_epics_fixture 3 1 1
  run "$DISCOVER_SCRIPT" --epics "$EPICS_FILE" --format=keys
  [ "$status" -eq 0 ]
  # Three lines, each a story key, in declared order
  local lines
  lines="$(printf '%s\n' "$output" | grep -c '^E99-S[0-9]')"
  [ "$lines" -eq 3 ]
}

# ---------- AC3 / VCP-ATDD-03 — `select` selection ----------

@test "VCP-ATDD-03: discovery resolves a comma-separated 1,3 selection to the right story keys" {
  _build_epics_fixture 3 0 0
  run "$DISCOVER_SCRIPT" --epics "$EPICS_FILE" --format=keys --select=1,3
  [ "$status" -eq 0 ]
  [[ "$output" == *"E99-S1"* ]]
  [[ "$output" == *"E99-S3"* ]]
  [[ "$output" != *"E99-S2"* ]]
}

@test "VCP-ATDD-03 / AC-EC6: out-of-range selection is rejected with non-zero exit and Invalid selection" {
  _build_epics_fixture 3 0 0
  run "$DISCOVER_SCRIPT" --epics "$EPICS_FILE" --format=keys --select=1,9
  [ "$status" -ne 0 ]
  [[ "$output" == *"Invalid selection"* ]]
}

@test "VCP-ATDD-03 / AC-EC6: non-numeric selection is rejected with non-zero exit and Invalid selection" {
  _build_epics_fixture 3 0 0
  run "$DISCOVER_SCRIPT" --epics "$EPICS_FILE" --format=keys --select=abc
  [ "$status" -ne 0 ]
  [[ "$output" == *"Invalid selection"* ]]
}

# ---------- AC4 / VCP-ATDD-04 — Red-phase execution ----------

@test "VCP-ATDD-04: run-red-phase.sh exists and is executable" {
  [ -x "$RED_PHASE_SCRIPT" ]
}

@test "VCP-ATDD-04 / AC-EC4: missing test-environment.yaml triggers warning + skip + exit 0" {
  # No test-environment.yaml in the fixture project root
  run env GAIA_PROJECT_ROOT="$TEST_TMP" "$RED_PHASE_SCRIPT" --tests "$TEST_ARTIFACTS/atdd-E99-S1.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Test runner not configured"* ]] || [[ "$output" == *"skipping red-phase"* ]]
}

@test "VCP-ATDD-04: red-phase reports a pass/fail count line in its output" {
  # Configure a no-op runner via test-environment.yaml that returns failures
  mkdir -p "$TEST_TMP/docs/test-artifacts"
  cat > "$TEST_TMP/docs/test-artifacts/test-environment.yaml" <<EOF
bridge_enabled: true
runner: "/bin/false"
EOF
  echo "# atdd stub" > "$TEST_TMP/docs/test-artifacts/atdd-E99-S1.md"
  run env GAIA_PROJECT_ROOT="$TEST_TMP" "$RED_PHASE_SCRIPT" --tests "$TEST_TMP/docs/test-artifacts/atdd-E99-S1.md"
  [[ "$output" == *"pass"* ]] || [[ "$output" == *"fail"* ]] || [[ "$output" == *"FAIL"* ]] || [[ "$output" == *"PASS"* ]]
}

@test "VCP-ATDD-04 / AC-EC5: red-phase enforces a per-test timeout (default 30s) flag" {
  # The script must accept a --timeout flag (default 30) for AC-EC5
  run "$RED_PHASE_SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"timeout"* ]]
}

# ---------- AC5 / VCP-ATDD-05 — Graceful empty exit ----------

@test "VCP-ATDD-05: zero high-risk stories prints canonical message and exits 0" {
  _build_epics_fixture 0 5 5
  run "$DISCOVER_SCRIPT" --epics "$EPICS_FILE" --format=keys
  [ "$status" -eq 0 ]
  [[ "$output" == *"No high-risk stories found"* ]]
  [[ "$output" == *"nothing to generate"* ]]
}

# ---------- AC-EC1: epics-and-stories.md missing or unreadable ----------

@test "AC-EC1: missing epics-and-stories.md halts with non-zero exit + clear error" {
  run "$DISCOVER_SCRIPT" --epics "$TEST_TMP/does-not-exist.md" --format=keys
  [ "$status" -ne 0 ]
  [[ "$output" == *"Cannot read"* ]]
  [[ "$output" == *"epics-and-stories.md"* ]] || [[ "$output" == *"halting"* ]]
}

# ---------- AC-EC7: single-story collapses menu to [all / skip] ----------

@test "AC-EC7: exactly one high-risk story collapses menu to [all / skip] (no select)" {
  _build_epics_fixture 1 0 0
  run "$DISCOVER_SCRIPT" --epics "$EPICS_FILE" --format=menu
  [ "$status" -eq 0 ]
  [[ "$output" == *"all"* ]]
  [[ "$output" == *"skip"* ]]
  # The 'select' option is suppressed when there is only one story
  [[ "$output" != *"select"* ]]
}

# ---------- AC-EC10 / AC-EC11: idempotency policy documented in SKILL.md ----------

@test "AC-EC10/11: SKILL.md documents the overwrite-with-warning idempotency policy" {
  grep -qi "overwriting existing ATDD artifact\|overwrite with warning\|idempotency" "$SKILL_FILE"
}

# ---------- AC-EC9: atomic write (temp + rename) referenced in SKILL.md or helper ----------

@test "AC-EC9: SKILL.md documents atomic write (temp + rename) for ATDD artifacts" {
  # Match an artifact-write context — not the unrelated "atomic and independent" phrase
  # that exists in the V1 checklist mapping.
  grep -qi "atomic.*write\|atomic.*artifact\|write.*atomic\|temp.*rename\|temp path.*rename" "$SKILL_FILE"
}

# ---------- SKILL.md documentation coverage ----------

@test "SKILL.md documents batch mode" {
  grep -qi "batch mode\|batch discovery\|argumentless" "$SKILL_FILE"
}

@test "SKILL.md documents the [all / select / skip] menu" {
  grep -q "all.*select.*skip\|all / select / skip" "$SKILL_FILE"
}

@test "SKILL.md documents the red-phase Step 5b" {
  grep -qi "step 5b\|red.phase.*execut" "$SKILL_FILE"
}

@test "SKILL.md documents the graceful empty-list exit message" {
  grep -q "No high-risk stories found" "$SKILL_FILE"
}
