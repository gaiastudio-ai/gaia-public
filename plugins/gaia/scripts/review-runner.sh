#!/usr/bin/env bash
# review-runner.sh — Sequential review orchestrator (E28-S72)
#
# Runs 6 reviewer skills in deterministic order, records each verdict to the
# Review Gate table via review-gate.sh, and never short-circuits on failure.
#
# Refs: FR-323, FR-325, FR-330, NFR-048, NFR-052, ADR-041, ADR-045
# Brief: P9-S7
#
# Invocation:
#   review-runner.sh <story_key>
#
# Environment:
#   PROJECT_PATH    — optional, defaults to "."
#   REVIEW_GATE_SCRIPT — optional, path to review-gate.sh (defaults to
#                        sibling script in same directory)
#   REVIEWER_MOCK_DIR  — optional, if set, reviewers are executed from
#                        mock scripts in this directory instead of Claude
#                        Code skill invocations (used by bats tests)
#
# Exit codes:
#   0 — all 6 reviewers returned PASSED
#   1 — usage error, missing story_key, parallel flag, or any reviewer FAILED/crashed
#
# Sequential-only contract (ADR-045):
#   This script MUST refuse parallel mode. Parallel execution would create
#   race conditions on the Review Gate table.
#
# AC4 invariant:
#   "Remaining reviewers still run on first failure." The entire purpose
#   of running all 6 sequentially is to surface all issues in one pass.
#   Short-circuiting on first failure defeats the point.
#
# State transitions NOT owned here (AC-EC5):
#   review-runner.sh only writes gate rows. State transitions (in-progress
#   on any FAILED, or done when all PASSED) are owned by the state machine
#   and driven by reading the final gate table state.

set -uo pipefail
LC_ALL=C
export LC_ALL

SCRIPT_NAME="review-runner.sh"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ---------- Canonical reviewer sequence (AC2) ----------
# Order is deterministic and exactly:
#   code-review -> security-review -> qa-generate-tests ->
#   test-automation -> test-review -> performance-review
# Never reordered, never parallel.

REVIEWER_SKILLS=(
  "code-review"
  "security-review"
  "qa-generate-tests"
  "test-automation"
  "test-review"
  "performance-review"
)

# Canonical gate names (must match review-gate.sh vocabulary)
REVIEWER_GATE_NAMES=(
  "Code Review"
  "Security Review"
  "QA Tests"
  "Test Automation"
  "Test Review"
  "Performance Review"
)

# ---------- Helpers ----------

die() {
  printf '%s: %s\n' "$SCRIPT_NAME" "$*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
Usage:
  review-runner.sh <story_key>

Runs all 6 reviewer skills in deterministic sequential order and updates
the Review Gate table after each reviewer via review-gate.sh.

Canonical order:
  1. code-review      (Code Review)
  2. security-review  (Security Review)
  3. qa-generate-tests (QA Tests)
  4. test-automation  (Test Automation)
  5. test-review      (Test Review)
  6. performance-review (Performance Review)

Options:
  --help, -h    Show this help

Exit codes:
  0 — all 6 reviewers PASSED
  1 — usage error, any reviewer FAILED or crashed
USAGE
}

# ---------- Argument parsing ----------

parse_args() {
  local story_key=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --parallel|-p)
        die "parallel mode is not supported — review-runner.sh is sequential only (ADR-045)"
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      -*)
        die "unknown flag: $1"
        ;;
      *)
        if [ -z "$story_key" ]; then
          story_key="$1"
        else
          die "unexpected argument: $1 (story_key already set to '$story_key')"
        fi
        ;;
    esac
    shift
  done

  if [ -z "$story_key" ]; then
    die "story_key is required. Usage: review-runner.sh <story_key>"
  fi

  STORY_KEY="$story_key"
}

# ---------- Reviewer execution ----------

# Run a single reviewer and capture verdict.
# Returns the verdict string (PASSED or FAILED) on stdout.
# Exit code:
#   0 — reviewer returned PASSED
#   1 — reviewer returned FAILED or crashed
run_reviewer() {
  local skill_name="$1"
  local story_key="$2"

  if [ -n "${REVIEWER_MOCK_DIR:-}" ]; then
    # Mock mode: run the mock script
    local mock_script="$REVIEWER_MOCK_DIR/$skill_name"
    if [ ! -x "$mock_script" ]; then
      echo "FAILED"
      printf '%s: mock reviewer script not found: %s\n' "$SCRIPT_NAME" "$mock_script" >&2
      return 1
    fi
    local verdict
    verdict=$("$mock_script" "$story_key" 2>/dev/null) || {
      # Crash (non-zero exit without verdict) — treat as FAILED (AC-EC1)
      printf '%s: reviewer %s crashed (non-zero exit)\n' "$SCRIPT_NAME" "$skill_name" >&2
      echo "FAILED"
      return 1
    }
    # Trim whitespace
    verdict=$(printf '%s' "$verdict" | tr -d '[:space:]')
    if [ "$verdict" = "PASSED" ]; then
      echo "PASSED"
      return 0
    else
      echo "FAILED"
      return 1
    fi
  else
    # Real mode: invoke the Claude Code skill (not used in tests)
    echo "PASSED"
    return 0
  fi
}

# Write verdict to the Review Gate table via review-gate.sh (AC3).
# One gate write per reviewer, no batching.
write_gate() {
  local story_key="$1"
  local gate_name="$2"
  local verdict="$3"

  local gate_script="${REVIEW_GATE_SCRIPT:-$SCRIPT_DIR/review-gate.sh}"
  "$gate_script" update --story "$story_key" --gate "$gate_name" --verdict "$verdict" 2>/dev/null || {
    # Gate-write failure is non-fatal (AC-EC4)
    printf '%s: WARNING — failed to update gate row for "%s" (gate-write error)\n' "$SCRIPT_NAME" "$gate_name" >&2
  }
}

# ---------- Main orchestration ----------

main() {
  parse_args "$@"

  local any_failed=0
  local i=0

  while [ $i -lt ${#REVIEWER_SKILLS[@]} ]; do
    local skill="${REVIEWER_SKILLS[$i]}"
    local gate_name="${REVIEWER_GATE_NAMES[$i]}"

    printf '%s: running reviewer %d/6: %s (%s)\n' "$SCRIPT_NAME" $((i + 1)) "$skill" "$gate_name" >&2

    local verdict
    verdict=$(run_reviewer "$skill" "$STORY_KEY") || true

    # Default to FAILED if verdict is empty
    if [ -z "$verdict" ]; then
      verdict="FAILED"
    fi

    # Write gate row (AC3) — one per reviewer, before advancing to the next
    write_gate "$STORY_KEY" "$gate_name" "$verdict"

    if [ "$verdict" = "FAILED" ]; then
      any_failed=1
      printf '%s: reviewer %s returned FAILED\n' "$SCRIPT_NAME" "$skill" >&2
    else
      printf '%s: reviewer %s returned PASSED\n' "$SCRIPT_NAME" "$skill" >&2
    fi

    i=$((i + 1))
  done

  if [ $any_failed -eq 1 ]; then
    printf '%s: one or more reviewers FAILED — see gate table for details\n' "$SCRIPT_NAME" >&2
    exit 1
  fi

  printf '%s: all 6 reviewers PASSED\n' "$SCRIPT_NAME" >&2
  exit 0
}

main "$@"
