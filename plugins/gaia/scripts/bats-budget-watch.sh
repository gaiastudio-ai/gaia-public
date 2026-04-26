#!/usr/bin/env bash
# bats-budget-watch.sh — E45-S6 / AC3 budget-watch invariant.
#
# Wrap a bats invocation, measure wall-clock duration, and emit a structured
# warning when the duration exceeds a configurable threshold. Always exits
# with the inner command's exit code — this is an advisory gate, never a
# hard failure (per ADR-062 §Recommendation: warn before we fail).
#
# The warning is appended to $GITHUB_STEP_SUMMARY when set, or printed to
# stdout otherwise. CI surfaces the warning on the PR's checks summary.
#
# Usage:
#   bats-budget-watch.sh --threshold-seconds <N> [--label <text>] -- <cmd> [args...]
#
# Examples:
#   bats-budget-watch.sh --threshold-seconds 240 --label bats-tests -- \
#     bash plugins/gaia/tests/run-with-coverage.sh
#
# Exit codes:
#   * Inner command's exit code (preserved verbatim — we never mask failures).
#   * 2 — argument parsing error (missing --threshold-seconds, missing --, etc).
#
# Library mode (for unit tests): set BATS_BUDGET_WATCH_LIB_ONLY=1 before
# sourcing to load the helpers without invoking main().

set -euo pipefail
LC_ALL=C
export LC_ALL

# ---------------------------------------------------------------------------
# Internal helpers — leading-underscore prefix marks them as internal and
# exempts them from the NFR-052 textual public-function coverage gate.
# ---------------------------------------------------------------------------

# _bats_elapsed_seconds <start> <end>
# Diff two epoch seconds. Clamps to 0 on clock skew (end < start).
_bats_elapsed_seconds() {
  local start="$1" end="$2" diff
  diff=$((end - start))
  if [ "$diff" -lt 0 ]; then
    printf '0\n'
  else
    printf '%d\n' "$diff"
  fi
}

# _bats_format_warning <label> <elapsed> <threshold>
# Emit the canonical structured-warning markdown block.
_bats_format_warning() {
  local label="$1" elapsed="$2" threshold="$3"
  cat <<EOF
> [!WARNING]
> **bats budget exceeded** — \`${label}\`
>
> - threshold: ${threshold}s
> - elapsed: ${elapsed}s
> - over by: $((elapsed - threshold))s
>
> The bats CI step is approaching its wall-clock budget. See
> \`plugins/gaia/docs/CI-NOTES.md\` for guidance on adding fixtures without
> breaking the budget. Tracked by E45-S6 / ADR-062.
EOF
}

# _bats_emit_warning <text...>
# Append the warning to $GITHUB_STEP_SUMMARY when set; otherwise print to
# stdout so local runs surface it too.
_bats_emit_warning() {
  local text="$*"
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ] && [ -w "$(dirname "$GITHUB_STEP_SUMMARY")" ]; then
    printf '%s\n' "$text" >> "$GITHUB_STEP_SUMMARY"
  else
    printf '%s\n' "$text"
  fi
}

# ---------------------------------------------------------------------------
# Public entry — bats_budget_watch_check.
# ---------------------------------------------------------------------------

# bats_budget_watch_check <args...>
# Parse CLI args, run the inner command, measure elapsed, emit warning if
# threshold exceeded, return the inner exit code.
bats_budget_watch_check() {
  local threshold="" label="bats" inner_cmd=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --threshold-seconds)
        threshold="${2:-}"
        shift 2
        ;;
      --label)
        label="${2:-bats}"
        shift 2
        ;;
      --)
        shift
        inner_cmd=("$@")
        break
        ;;
      *)
        printf 'bats-budget-watch.sh: unexpected arg %q (did you forget the -- separator?)\n' "$1" >&2
        return 2
        ;;
    esac
  done

  if [ -z "$threshold" ]; then
    printf 'bats-budget-watch.sh: --threshold-seconds is required\n' >&2
    return 2
  fi

  if [ "${#inner_cmd[@]}" -eq 0 ]; then
    printf 'bats-budget-watch.sh: inner command after -- is required\n' >&2
    return 2
  fi

  local start end elapsed inner_status=0
  start="$(date +%s)"
  # Run inner command. Tolerate failure — we still want to emit the warning
  # if the failure happened after the budget was blown.
  set +e
  "${inner_cmd[@]}"
  inner_status=$?
  set -e
  end="$(date +%s)"
  elapsed="$(_bats_elapsed_seconds "$start" "$end")"

  if [ "$elapsed" -gt "$threshold" ]; then
    _bats_emit_warning "$(_bats_format_warning "$label" "$elapsed" "$threshold")"
  fi

  return "$inner_status"
}

# ---------------------------------------------------------------------------
# Main — skipped when sourced as a library (BATS_BUDGET_WATCH_LIB_ONLY=1).
# ---------------------------------------------------------------------------
if [ "${BATS_BUDGET_WATCH_LIB_ONLY:-0}" != "1" ]; then
  bats_budget_watch_check "$@"
fi
