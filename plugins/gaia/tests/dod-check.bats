#!/usr/bin/env bats
# dod-check.bats — coverage for skills/gaia-dev-story/scripts/dod-check.sh
#
# Story: E55-S8 — Auto-reviews YOLO-only (Step 16) + 4 helper scripts + bats coverage
#
# Coverage matrix:
#   - happy path: all checks PASSED, exit 0, six YAML rows
#   - failure path: tests FAILED, exit non-zero, row marked FAILED
#   - idempotency: re-running yields the same final outcome
#   - secrets gate: a staged .env-like file flips secrets row to FAILED
#
# The script is dumb and deterministic — it shells out to project-local
# build/test/lint commands and emits YAML. Tests stub those commands by
# putting fake binaries on PATH inside an isolated TEST_TMP working dir.

load 'test_helper.bash'

setup() {
  common_setup
  DOD_CHECK="$(cd "$BATS_TEST_DIRNAME/../skills/gaia-dev-story/scripts" && pwd)/dod-check.sh"
  cd "$TEST_TMP"
  # Stub git repo so any git invocation in the script is well-defined.
  git init -q -b feat/dummy
  git config user.email "dev@example.com"
  git config user.name "Dev"
  git commit -q --allow-empty -m "init"
  # Per-test stub bin dir prepended to PATH.
  STUB_BIN="$TEST_TMP/stub-bin"
  mkdir -p "$STUB_BIN"
  export PATH="$STUB_BIN:$PATH"
}

teardown() { common_teardown; }

# ---------------------------------------------------------------------------
# Helpers — write a tiny shell stub that exits with the requested code.
# ---------------------------------------------------------------------------
_stub() {
  local name="$1" exit_code="${2:-0}" stdout="${3:-}"
  cat > "$STUB_BIN/$name" <<STUB
#!/usr/bin/env bash
[ -n "$stdout" ] && printf '%s\n' "$stdout"
exit $exit_code
STUB
  chmod +x "$STUB_BIN/$name"
}

# ---------------------------------------------------------------------------
# Happy path — all gates pass.
# ---------------------------------------------------------------------------

@test "dod-check: happy path emits all PASSED rows and exits 0" {
  _stub "build" 0 "build ok"
  _stub "test"  0 "tests ok"
  _stub "lint"  0 "lint ok"
  run "$DOD_CHECK"
  [ "$status" -eq 0 ]
  [[ "$output" == *"status: PASSED"* ]]
  # Must have at least the canonical rows.
  for row in build tests lint secrets subtasks; do
    [[ "$output" == *"item: $row"* ]] || {
      echo "missing item row: $row" >&2
      echo "actual: $output" >&2
      return 1
    }
  done
}

# ---------------------------------------------------------------------------
# Failure — tests fail.
# ---------------------------------------------------------------------------

@test "dod-check: tests fail -> tests row FAILED, exit non-zero" {
  _stub "build" 0 "build ok"
  _stub "test"  1 "tests broke"
  _stub "lint"  0 "lint ok"
  run "$DOD_CHECK"
  [ "$status" -ne 0 ]
  [[ "$output" == *"item: tests"* ]]
  [[ "$output" == *"status: FAILED"* ]]
}

# ---------------------------------------------------------------------------
# Secrets — staging a .env-like file flips secrets row.
# ---------------------------------------------------------------------------

@test "dod-check: staged .env trips secrets row to FAILED" {
  _stub "build" 0 "build ok"
  _stub "test"  0 "tests ok"
  _stub "lint"  0 "lint ok"
  printf 'API_KEY=foo\n' > .env
  git add -f .env
  run "$DOD_CHECK"
  [ "$status" -ne 0 ]
  [[ "$output" == *"item: secrets"* ]]
  [[ "$output" == *"status: FAILED"* ]]
}

# ---------------------------------------------------------------------------
# Idempotency — running twice yields the same overall verdict.
# ---------------------------------------------------------------------------

@test "dod-check: idempotent — two consecutive runs match" {
  _stub "build" 0 "build ok"
  _stub "test"  0 "tests ok"
  _stub "lint"  0 "lint ok"
  run "$DOD_CHECK"
  first_status="$status"
  first_output="$output"
  run "$DOD_CHECK"
  [ "$status" -eq "$first_status" ]
  [ "$output" = "$first_output" ]
}
