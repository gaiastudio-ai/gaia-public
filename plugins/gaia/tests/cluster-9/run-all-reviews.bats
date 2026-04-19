#!/usr/bin/env bats
# run-all-reviews.bats — Cluster 9 integration test (E28-S73)
#
# End-to-end test for gaia-run-all-reviews: verifies all 6 Review Gate rows
# are updated correctly using the canonical PASSED / FAILED / UNVERIFIED
# vocabulary, in the canonical ADR-045 order.
#
# Refs: FR-323, FR-325, FR-330, NFR-048, NFR-052, NFR-053, ADR-041, ADR-045
# Brief: P9-S8

load 'test_helper.bash'

# ---------- Paths ----------

CLUSTER9_DIR="${BATS_TEST_DIRNAME}"
FIXTURES_DIR="${CLUSTER9_DIR}/fixtures"
EXPECTED_DIR="${FIXTURES_DIR}/expected"
# Override SCRIPTS_DIR from test_helper (which resolves relative to tests/)
# Cluster 9 tests need the scripts dir two levels up from cluster-9/
SCRIPTS_DIR="$(cd "${BATS_TEST_DIRNAME}/../../scripts" && pwd)"

# ---------- Helpers ----------

setup() {
  common_setup
  TEST_PROJECT="$TEST_TMP"
  # Post-E28-S99, review-gate.sh::locate_story_file resolves story files
  # directly under IMPLEMENTATION_ARTIFACTS (flat directory), matching
  # sprint-state.sh. The fixture must be installed at that flat location,
  # not under a stories/ subdirectory — otherwise reviewers run but the
  # writeback target resolves to "no story file found" and Review Gate
  # rows stay UNVERIFIED. See E28-S174.
  ART="$TEST_PROJECT/docs/implementation-artifacts"
  mkdir -p "$ART"

  export PROJECT_PATH="$TEST_PROJECT"
  export REVIEW_GATE_SCRIPT="$SCRIPTS_DIR/review-gate.sh"

  # Preserve temp dir path on failure for post-mortem (AC fixture doc)
  BATS_PRESERVE_TMPDIR_ON_FAILURE=1
}

teardown() {
  if [ "$BATS_TEST_COMPLETED" = 1 ]; then
    common_teardown
  else
    # Preserve temp path in TAP log for post-mortem
    echo "# POST-MORTEM: temp dir preserved at $TEST_TMP" >&3
  fi
}

# Copy fixture story to the test temp dir
install_fixture() {
  cp "$FIXTURES_DIR/C9-FIXTURE-fake.md" "$ART/C9-FIXTURE-fake.md"
}

# Create mock reviewers that all return PASSED
seed_all_pass_reviewers() {
  local mock_dir="$TEST_TMP/mock-reviewers"
  mkdir -p "$mock_dir"
  for reviewer in code-review security-review qa-generate-tests test-automation test-review performance-review; do
    cat > "$mock_dir/$reviewer" <<'MOCK'
#!/usr/bin/env bash
echo "PASSED"
exit 0
MOCK
    chmod +x "$mock_dir/$reviewer"
  done
  export REVIEWER_MOCK_DIR="$mock_dir"
}

# Create mock reviewers where security-review returns FAILED, rest PASSED
seed_security_failed_reviewers() {
  local mock_dir="$TEST_TMP/mock-reviewers"
  mkdir -p "$mock_dir"
  for reviewer in code-review qa-generate-tests test-automation test-review performance-review; do
    cat > "$mock_dir/$reviewer" <<'MOCK'
#!/usr/bin/env bash
echo "PASSED"
exit 0
MOCK
    chmod +x "$mock_dir/$reviewer"
  done
  cat > "$mock_dir/security-review" <<'MOCK'
#!/usr/bin/env bash
echo "FAILED"
exit 0
MOCK
  chmod +x "$mock_dir/security-review"
  export REVIEWER_MOCK_DIR="$mock_dir"
}

# Extract the Review Gate table from the story file and normalize it.
# Returns one line per gate row: "| <gate_name> | <status> | — |"
extract_review_gate_table() {
  local file="$1"
  awk '
    /^## Review Gate/ { in_gate = 1; next }
    in_gate && /^## / { in_gate = 0 }
    in_gate && /^\|/ && !/^\|[-]+/ && !/^\| Review/ {
      n = split($0, cells, "|")
      if (n >= 4) {
        gate = cells[2]; status = cells[3]
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", gate)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", status)
        if (gate != "") printf "| %s | %s | — |\n", gate, status
      }
    }
  ' "$file"
}

# Parse the review-runner.sh stderr output to extract the invocation sequence
extract_reviewer_sequence() {
  local stderr_file="$1"
  grep 'running reviewer' "$stderr_file" | sed 's/.*running reviewer [0-9]\/6: //' | sed 's/ (.*//'
}

# Validate all Review Gate Status cells are in canonical vocabulary
validate_canonical_vocabulary() {
  local file="$1"
  local non_canonical=0
  local status_values
  status_values=$(awk '
    /^## Review Gate/ { in_gate = 1; next }
    in_gate && /^## / { in_gate = 0 }
    in_gate && /^\|/ && !/^\|[-]+/ && !/^\| Review/ {
      split($0, cells, "|")
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", cells[3])
      if (cells[3] != "") print cells[3]
    }
  ' "$file")

  while IFS= read -r val; do
    case "$val" in
      PASSED|FAILED|UNVERIFIED) ;;
      *) non_canonical=1; echo "NON-CANONICAL: '$val'" ;;
    esac
  done <<< "$status_values"
  return $non_canonical
}

# ---------- Test 1: Happy path — all six reviewers pass (AC1, AC2) ----------

@test "happy path: all 6 reviewers run and produce all-PASSED gate table" {
  install_fixture
  seed_all_pass_reviewers

  run "$SCRIPTS_DIR/review-runner.sh" "C9-FIXTURE"
  [ "$status" -eq 0 ]

  # Verify all 6 gate rows updated to PASSED
  run "$SCRIPTS_DIR/review-gate.sh" check --story "C9-FIXTURE"
  [ "$status" -eq 0 ]
}

# ---------- Test 2: Vocabulary invariant — only canonical values (AC2) ----------

@test "vocabulary invariant: all gate values are canonical after all-pass run" {
  install_fixture
  seed_all_pass_reviewers

  "$SCRIPTS_DIR/review-runner.sh" "C9-FIXTURE" 2>/dev/null

  run validate_canonical_vocabulary "$ART/C9-FIXTURE-fake.md"
  [ "$status" -eq 0 ]
}

# ---------- Test 3: Snapshot diff — all-pass matches expected (AC2) ----------

@test "all-pass snapshot: Review Gate table matches expected/review-gate-all-pass.md" {
  install_fixture
  seed_all_pass_reviewers

  "$SCRIPTS_DIR/review-runner.sh" "C9-FIXTURE" 2>/dev/null

  # Extract actual Review Gate section
  local actual expected
  actual=$(extract_review_gate_table "$ART/C9-FIXTURE-fake.md")
  expected=$(extract_review_gate_table "$EXPECTED_DIR/review-gate-all-pass.md")

  [ "$actual" = "$expected" ]
}

# ---------- Test 4: Negative path — one reviewer FAILED (AC3) ----------

@test "negative path: security-review FAILED, remaining 5 still run" {
  install_fixture
  seed_security_failed_reviewers

  run "$SCRIPTS_DIR/review-runner.sh" "C9-FIXTURE"
  # Should exit non-zero because at least one FAILED
  [ "$status" -ne 0 ]

  # All 6 gate writes should have happened
  run "$SCRIPTS_DIR/review-gate.sh" status --story "C9-FIXTURE"
  [ "$status" -eq 0 ]
  # Parse JSON: Security Review should be FAILED, rest PASSED
  echo "$output" | jq -e '.gates["Security Review"] == "FAILED"'
  echo "$output" | jq -e '.gates["Code Review"] == "PASSED"'
  echo "$output" | jq -e '.gates["QA Tests"] == "PASSED"'
  echo "$output" | jq -e '.gates["Test Automation"] == "PASSED"'
  echo "$output" | jq -e '.gates["Test Review"] == "PASSED"'
  echo "$output" | jq -e '.gates["Performance Review"] == "PASSED"'
}

# ---------- Test 5: Negative path — story status stays review (not done) (AC3b) ----------

@test "negative path: story frontmatter status remains review (not auto-transitioned)" {
  install_fixture
  seed_security_failed_reviewers

  "$SCRIPTS_DIR/review-runner.sh" "C9-FIXTURE" 2>/dev/null || true

  # Story status should still be review (review-runner.sh does NOT transition state)
  grep -q 'status: review' "$ART/C9-FIXTURE-fake.md"
}

# ---------- Test 6: Negative snapshot diff (AC3) ----------

@test "negative-path snapshot: Review Gate table matches expected/review-gate-security-failed.md" {
  install_fixture
  seed_security_failed_reviewers

  "$SCRIPTS_DIR/review-runner.sh" "C9-FIXTURE" 2>/dev/null || true

  local actual expected
  actual=$(extract_review_gate_table "$ART/C9-FIXTURE-fake.md")
  expected=$(extract_review_gate_table "$EXPECTED_DIR/review-gate-security-failed.md")

  if [ "$actual" != "$expected" ]; then
    echo "EXPECTED:"
    echo "$expected"
    echo "ACTUAL:"
    echo "$actual"
    diff -u <(echo "$expected") <(echo "$actual") || true
    return 1
  fi
}

# ---------- Test 7: Canonical order — ADR-045 sequence (AC1) ----------

@test "canonical order: reviewers invoked in ADR-045 sequence" {
  install_fixture
  seed_all_pass_reviewers

  local stderr_file="$TEST_TMP/runner-stderr.txt"
  "$SCRIPTS_DIR/review-runner.sh" "C9-FIXTURE" 2>"$stderr_file"

  local sequence
  sequence=$(extract_reviewer_sequence "$stderr_file")

  local expected_sequence="code-review
security-review
qa-generate-tests
test-automation
test-review
performance-review"

  [ "$sequence" = "$expected_sequence" ]
}

# ---------- Test 8: Each reviewer invoked exactly once (AC1) ----------

@test "each reviewer invoked exactly once" {
  install_fixture
  seed_all_pass_reviewers

  local stderr_file="$TEST_TMP/runner-stderr.txt"
  "$SCRIPTS_DIR/review-runner.sh" "C9-FIXTURE" 2>"$stderr_file"

  local count
  count=$(grep -c 'running reviewer' "$stderr_file")
  [ "$count" -eq 6 ]
}

# ---------- Test 9: Vocabulary breach detection — non-canonical value (AC2) ----------

@test "vocabulary invariant: parser detects non-canonical value" {
  install_fixture

  # Manually inject a non-canonical value
  sed -i.bak 's/Code Review | UNVERIFIED/Code Review | PASS/' "$ART/C9-FIXTURE-fake.md"
  rm -f "$ART/C9-FIXTURE-fake.md.bak"

  run validate_canonical_vocabulary "$ART/C9-FIXTURE-fake.md"
  [ "$status" -ne 0 ]
  [[ "$output" == *"NON-CANONICAL"* ]]
  [[ "$output" == *"PASS"* ]]
}

# ---------- Test 10: Temp-dir isolation — no writes outside temp dir ----------

@test "isolation: no writes to repo state outside test temp dir" {
  install_fixture
  seed_all_pass_reviewers

  # Record state of the fixtures dir before the run
  local fixtures_hash_before fixtures_hash_after
  fixtures_hash_before=$(find "$FIXTURES_DIR" -type f -exec shasum {} \; | sort)

  "$SCRIPTS_DIR/review-runner.sh" "C9-FIXTURE" 2>/dev/null

  fixtures_hash_after=$(find "$FIXTURES_DIR" -type f -exec shasum {} \; | sort)
  [ "$fixtures_hash_before" = "$fixtures_hash_after" ]
}
