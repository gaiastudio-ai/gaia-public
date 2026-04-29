#!/usr/bin/env bats
# review-gate-check-wiring.bats — Cluster 9 wiring contract test (E58-S4)
#
# Asserts the canonical exit-code contract of `review-gate.sh review-gate-check`
# against three deterministic Review Gate fixture states:
#
#   AC1 — all six rows PASSED               -> exit 0 (COMPLETE)        TC-RAR-11
#   AC2 — at least one row FAILED           -> exit 1 (BLOCKED)         TC-RAR-11
#   AC3 — no FAILED, at least one UNVERIFIED -> exit 2 (PENDING)        TC-RAR-11
#   AC4 — exit-code classification matches `review-nudge.sh` row counts TC-RAR-12
#
# Refs: FR-RAR-4, FR-CRG-1, FR-CRG-2, NFR-CRG-1, NFR-CRG-2, ADR-054, E37-S1.
# Story: E58-S4 (de-LLM overall-status via review-gate.sh review-gate-check).
#
# Contract assertion only — no production script changes. The script under
# test (`review-gate.sh review-gate-check`) already exists per E37-S1 / ADR-054.

load 'test_helper.bash'

# ---------- Paths ----------

CLUSTER9_DIR="${BATS_TEST_DIRNAME}"
FIXTURES_DIR="${CLUSTER9_DIR}/fixtures/review-gate-check"
# Override SCRIPTS_DIR from test_helper (which resolves relative to tests/)
# Cluster 9 tests need the scripts dir two levels up from cluster-9/.
SCRIPTS_DIR="$(cd "${BATS_TEST_DIRNAME}/../../scripts" && pwd)"

REVIEW_GATE_SH="$SCRIPTS_DIR/review-gate.sh"
REVIEW_NUDGE_SH="$SCRIPTS_DIR/review-nudge.sh"

# ---------- Helpers ----------

setup() {
  common_setup
  TEST_PROJECT="$TEST_TMP"
  ART="$TEST_PROJECT/docs/implementation-artifacts"
  mkdir -p "$ART"

  export PROJECT_PATH="$TEST_PROJECT"
}

teardown() {
  common_teardown
}

# Install one of the three named fixtures into the temp project's flat
# implementation-artifacts directory.
#
# `review-gate.sh::locate_story_file` resolves story files via the glob
# `${IMPLEMENTATION_ARTIFACTS}/<key>-*.md` (the trailing dash + glob is
# load-bearing — the bare key cannot be the full filename or the glob
# misses). We therefore name fixture files `<key>-fixture.md` so the
# canonical glob finds them when callers pass the bare key.
install_fixture() {
  local name="$1"   # all-passed | any-failed | any-unverified
  cp "$FIXTURES_DIR/${name}-fixture.md" "$ART/${name}-fixture.md"
}

# ---------- AC1: all-passed -> exit 0 (COMPLETE) ----------

@test "AC1 (TC-RAR-11): all-passed fixture exits 0 (COMPLETE)" {
  install_fixture "all-passed"
  run "$REVIEW_GATE_SH" review-gate-check --story "all-passed"
  [ "$status" -eq 0 ]
}

# ---------- AC2: any-failed -> exit 1 (BLOCKED) ----------

@test "AC2 (TC-RAR-11): any-failed fixture exits 1 (BLOCKED)" {
  install_fixture "any-failed"
  run "$REVIEW_GATE_SH" review-gate-check --story "any-failed"
  [ "$status" -eq 1 ]
}

# ---------- AC3: any-unverified -> exit 2 (PENDING) ----------

@test "AC3 (TC-RAR-11): any-unverified fixture exits 2 (PENDING)" {
  install_fixture "any-unverified"
  run "$REVIEW_GATE_SH" review-gate-check --story "any-unverified"
  [ "$status" -eq 2 ]
}

# ---------- AC4: nudge-parity ----------
#
# For each fixture, verify the exit-code-derived classification (0 / 1 / 2)
# is consistent with the FAILED / UNVERIFIED row counts emitted by
# `review-nudge.sh --story <key>`.
#
# Soft dependency: `review-nudge.sh` ships in E58-S3 (still pending at the
# time E58-S4 lands). When the helper is absent we skip cleanly so this
# test file remains forward-compatible — once E58-S3 lands, AC4 activates
# automatically with no further edits.

@test "AC4 (TC-RAR-12): nudge classification matches Review Gate row counts" {
  if [ ! -x "$REVIEW_NUDGE_SH" ]; then
    skip "review-nudge.sh not present yet (lands in E58-S3); AC4 will activate when E58-S3 merges"
  fi

  local name
  for name in all-passed any-failed any-unverified; do
    install_fixture "$name"

    # Capture the gate-check exit code. Wrap in set +e / set -e so that the
    # any-failed fixture's exit-1 (BLOCKED) and any-unverified fixture's exit-2
    # (PENDING) do not trigger bats's strict-mode test failure on the unredirected
    # call. The exit code itself is the contract surface under test here.
    set +e
    "$REVIEW_GATE_SH" review-gate-check --story "$name" >/dev/null 2>&1
    local gate_exit=$?
    set -e

    # Capture nudge output and parse FAILED / UNVERIFIED counts.
    local nudge_out failed_count unverified_count
    nudge_out=$("$REVIEW_NUDGE_SH" --story "$name" 2>/dev/null || true)
    failed_count=$(printf '%s\n' "$nudge_out" | grep -c -E '^[[:space:]]*-?[[:space:]]*FAILED' || true)
    unverified_count=$(printf '%s\n' "$nudge_out" | grep -c -E '^[[:space:]]*-?[[:space:]]*UNVERIFIED' || true)

    case "$gate_exit" in
      0)
        # COMPLETE — no FAILED, no UNVERIFIED rendered.
        [ "$failed_count" -eq 0 ]
        [ "$unverified_count" -eq 0 ]
        ;;
      1)
        # BLOCKED — at least one FAILED rendered.
        [ "$failed_count" -ge 1 ]
        ;;
      2)
        # PENDING — zero FAILED, at least one UNVERIFIED rendered.
        [ "$failed_count" -eq 0 ]
        [ "$unverified_count" -ge 1 ]
        ;;
      *)
        echo "unexpected gate exit code: $gate_exit (fixture=$name)" >&2
        return 1
        ;;
    esac
  done
}
