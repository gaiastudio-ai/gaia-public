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

# Look up the verdict token for the i'th reviewer in MOCK_VERDICTS (E58-S5).
# MOCK_VERDICTS is a comma-separated list aligned with REVIEWER_SKILLS order:
#   PASS,PASS,PASS,PASS,PASS,PASS  → all PASSED
#   PASS,CRASH,PASS,PASS,PASS,PASS → reviewer #2 simulates a non-zero crash
#   PASS,FAIL,PASS,PASS,PASS,PASS  → reviewer #2 returns FAILED cleanly
# bash 3.2 / macOS compatible — no associative arrays, no mapfile.
mock_verdict_for_index() {
  local idx="$1"
  local list="${MOCK_VERDICTS:-}"
  local i=0
  local IFS=,
  # shellcheck disable=SC2206
  local tokens=( $list )
  if [ "$idx" -lt 0 ] || [ "$idx" -ge "${#tokens[@]}" ]; then
    echo ""
    return 0
  fi
  printf '%s' "${tokens[$idx]}"
}

# Run a single reviewer and capture verdict.
# Returns the verdict string (PASSED or FAILED) on stdout.
# Exit code:
#   0 — reviewer returned PASSED
#   1 — reviewer returned FAILED or crashed
#
# Mode precedence (E58-S5):
#   1. MOCK_VERDICTS path  — verdict-list mode driven by env var (per-slot
#      verdict tokens including a CRASH sentinel for crash-resilience tests).
#   2. REVIEWER_MOCK_DIR   — script-dir mode (legacy, exercised by the
#      cluster-9 fixture suite — preserved for backward compatibility).
#   3. Real-mode no-op     — return 0 with no stdout. The SKILL.md harness
#      (E58-S6) drives the LLM judgment and writes the gate row via
#      review-gate.sh update. review-runner.sh MUST NOT shell out to a model
#      and MUST NOT write to the gate ledger from this slot (AC3, AC-EC4).
run_reviewer() {
  local skill_name="$1"
  local story_key="$2"
  local idx="${3:-0}"

  if [ -n "${MOCK_VERDICTS:-}" ]; then
    # MOCK_VERDICTS mode (E58-S5): pick the slot's verdict token.
    local token
    token=$(mock_verdict_for_index "$idx")
    case "$token" in
      PASS|PASSED)
        printf 'PASSED\n'
        return 0
        ;;
      CRASH)
        # Simulate a reviewer crash — non-zero exit + FAILED stdout (AC4).
        printf '%s: reviewer %s crashed (MOCK_VERDICTS sentinel)\n' "$SCRIPT_NAME" "$skill_name" >&2
        printf 'FAILED\n'
        return 1
        ;;
      FAIL|FAILED|*)
        printf 'FAILED\n'
        return 1
        ;;
    esac
  elif [ -n "${REVIEWER_MOCK_DIR:-}" ]; then
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
    # Real-mode no-op (E58-S5, AC1/AC3/AC-EC4): the SKILL.md harness writes
    # the verdict via review-gate.sh update. The script never returns a
    # hardcoded verdict and never writes to the gate ledger from this slot.
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

# ---------- E58-S5 orchestration helpers ----------

# Boundary guard for MOCK_VERDICTS (AC-EC1). When MOCK_MODE=true, MOCK_VERDICTS
# MUST be present so the per-slot verdict lookup is well-defined. The guard
# fires before any reviewer iteration so no gate-ledger writes can occur.
assert_mock_verdicts_when_mock_mode() {
  if [ "${MOCK_MODE:-}" = "true" ] && [ -z "${MOCK_VERDICTS:-}" ]; then
    die "MOCK_VERDICTS required when MOCK_MODE=true (E58-S5 AC-EC1)"
  fi
}

# Run E58-S1 review-skip-check.sh if available; partition the reviewer list
# into skip / run sets (AC2). When the script is not configured (no env
# override and no sibling), fall back silently to "run all 6" — preserves
# backward compatibility with the cluster-9 fixture suite that predates
# E58-S1.
#
# JSON contract (review-skip-check.sh stdout):
#   {"skip":["code-review",...],"run":["security-review",...]}
#
# AC-EC2: malformed JSON HALTs with a parse-error message and non-zero exit.
SKIP_LIST=""
run_skip_check() {
  local skip_script="${REVIEW_SKIP_CHECK_SCRIPT:-}"
  if [ -z "$skip_script" ]; then
    if [ -x "$SCRIPT_DIR/review-skip-check.sh" ] && [ "${REVIEW_RUNNER_USE_SKIP_CHECK:-0}" = "1" ]; then
      skip_script="$SCRIPT_DIR/review-skip-check.sh"
    else
      SKIP_LIST=""
      return 0
    fi
  fi
  if [ ! -x "$skip_script" ]; then
    SKIP_LIST=""
    return 0
  fi

  local raw
  raw=$("$skip_script" --story "$STORY_KEY" 2>/dev/null) || {
    printf '%s: skip-check script returned non-zero — defaulting to run all 6\n' "$SCRIPT_NAME" >&2
    SKIP_LIST=""
    return 0
  }

  # Parse the skip array. jq is required (matches review-skip-check.sh
  # discipline). On parse failure HALT (AC-EC2).
  if ! command -v jq >/dev/null 2>&1; then
    SKIP_LIST=""
    return 0
  fi
  local skip_csv
  skip_csv=$(printf '%s' "$raw" | jq -r '.skip | join(",")' 2>/dev/null) || {
    die "skip-check returned malformed JSON (parse-error) — output was: $raw"
  }
  SKIP_LIST="$skip_csv"
}

# Test whether a canonical short-name is in the SKIP_LIST (CSV).
is_skipped() {
  local needle="$1"
  case ",$SKIP_LIST," in
    *",$needle,"*) return 0 ;;
    *) return 1 ;;
  esac
}

# Resolve a soft-dependency script path. Returns the executable path on
# stdout, or empty string when the script is unconfigured / not executable.
# Two ways to enable a soft dep:
#   1. Set the explicit env override (e.g., REVIEW_SUMMARY_GEN_SCRIPT=/path).
#   2. Place the script as a sibling of review-runner.sh AND set the
#      REVIEW_RUNNER_USE_<NAME>=1 opt-in. The opt-in keeps the cluster-9
#      fixture suite (which predates E58-S1/S2/S3) free of side effects from
#      sibling scripts that may not yet be fully wired.
resolve_soft_dep_script() {
  local override_var="$1"
  local sibling_name="$2"
  local opt_in_var="$3"
  local override="${!override_var:-}"
  if [ -n "$override" ]; then
    [ -x "$override" ] && printf '%s' "$override"
    return 0
  fi
  local sibling="$SCRIPT_DIR/$sibling_name"
  if [ -x "$sibling" ] && [ "${!opt_in_var:-0}" = "1" ]; then
    printf '%s' "$sibling"
  fi
}

# Soft-dependency call for review-summary-gen.sh (E58-S2). Non-fatal —
# failures emit a warning but never abort the orchestrator.
run_summary_gen() {
  local script
  script=$(resolve_soft_dep_script REVIEW_SUMMARY_GEN_SCRIPT review-summary-gen.sh REVIEW_RUNNER_USE_SUMMARY_GEN)
  [ -z "$script" ] && return 0
  "$script" --story "$STORY_KEY" 2>/dev/null || {
    printf '%s: WARNING — summary-gen script returned non-zero\n' "$SCRIPT_NAME" >&2
  }
}

# Soft-dependency call for review-nudge.sh (E58-S3). Non-fatal — failures
# emit a warning but never abort the orchestrator.
run_nudge() {
  local script
  script=$(resolve_soft_dep_script REVIEW_NUDGE_SCRIPT review-nudge.sh REVIEW_RUNNER_USE_NUDGE)
  [ -z "$script" ] && return 0
  "$script" --story "$STORY_KEY" 2>/dev/null || {
    printf '%s: WARNING — nudge script returned non-zero\n' "$SCRIPT_NAME" >&2
  }
}

# ---------- Main orchestration ----------
#
# Canonical orchestration order (E58-S5 AC2):
#   1. skip-check
#   2. for each non-skipped reviewer: judgment slot -> gate write
#   3. summary-gen
#   4. nudge
#
# Both MOCK_VERDICTS mode and real-mode traverse this exact sequence.

main() {
  parse_args "$@"

  # AC-EC1: MOCK_VERDICTS guard before any per-reviewer work.
  assert_mock_verdicts_when_mock_mode

  # Step 1 — skip-check (AC2).
  run_skip_check

  local any_failed=0
  local i=0

  while [ $i -lt ${#REVIEWER_SKILLS[@]} ]; do
    local skill="${REVIEWER_SKILLS[$i]}"
    local gate_name="${REVIEWER_GATE_NAMES[$i]}"

    if is_skipped "$skill"; then
      printf '%s: skipping reviewer %d/6: %s (already PASSED per skip-check)\n' "$SCRIPT_NAME" $((i + 1)) "$skill" >&2
      i=$((i + 1))
      continue
    fi

    printf '%s: running reviewer %d/6: %s (%s)\n' "$SCRIPT_NAME" $((i + 1)) "$skill" "$gate_name" >&2

    local verdict
    # Step 2 — per-reviewer judgment slot (AC2). Crash-resilient: a non-zero
    # exit from run_reviewer is captured and written as FAILED, then the loop
    # continues to the next reviewer (AC4 / AC-EC3).
    verdict=$(run_reviewer "$skill" "$STORY_KEY" "$i") || true

    # Default to FAILED if verdict is empty (real-mode no-op leaves stdout
    # empty by design — in real-mode the SKILL.md harness writes the gate
    # row directly and review-runner.sh skips the gate write below).
    if [ -z "$verdict" ]; then
      if [ -z "${MOCK_VERDICTS:-}" ] && [ -z "${REVIEWER_MOCK_DIR:-}" ]; then
        # AC3 / AC-EC4: real-mode judgment slot returns control without
        # writing to the gate ledger. The SKILL.md harness owns the verdict.
        printf '%s: real-mode no-op for reviewer %s — SKILL.md owns verdict write\n' "$SCRIPT_NAME" "$skill" >&2
        i=$((i + 1))
        continue
      fi
      verdict="FAILED"
    fi

    # Step 2 cont. — gate write per reviewer (AC2 / AC3 mock-mode path).
    write_gate "$STORY_KEY" "$gate_name" "$verdict"

    if [ "$verdict" = "FAILED" ]; then
      any_failed=1
      printf '%s: reviewer %s returned FAILED\n' "$SCRIPT_NAME" "$skill" >&2
    else
      printf '%s: reviewer %s returned PASSED\n' "$SCRIPT_NAME" "$skill" >&2
    fi

    i=$((i + 1))
  done

  # Step 3 — summary-gen (AC2).
  run_summary_gen
  # Step 4 — nudge (AC2).
  run_nudge

  if [ $any_failed -eq 1 ]; then
    printf '%s: one or more reviewers FAILED — see gate table for details\n' "$SCRIPT_NAME" >&2
    exit 1
  fi

  printf '%s: all 6 reviewers PASSED\n' "$SCRIPT_NAME" >&2
  exit 0
}

main "$@"
