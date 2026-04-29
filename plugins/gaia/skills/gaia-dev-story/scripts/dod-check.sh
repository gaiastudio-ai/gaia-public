#!/usr/bin/env bash
# dod-check.sh — gaia-dev-story Step 9 Definition of Done helper (E55-S8)
#
# Purpose:
#   Run a deterministic, dumb sequence of DoD checks and emit one YAML row
#   per check. Step 9 in SKILL.md parses this output to render a
#   human-readable summary. The script itself contains no LLM reasoning.
#
# Output:
#   YAML list, one row per check:
#     - { item: <name>, status: PASSED|FAILED, output: <captured stdout/stderr> }
#
# Checks (in order):
#   1. build    — runs `build` if available; PASSED if exit 0, otherwise FAILED.
#   2. tests    — runs `test`  if available; PASSED if exit 0, otherwise FAILED.
#   3. lint     — runs `lint`  if available; PASSED if exit 0, otherwise FAILED.
#   4. secrets  — scans the staged diff and staged file basenames for env-like
#                 files / credentials / canonical secret patterns. Delegates
#                 to dev-story-security-invariants.sh::assert_no_secrets_staged
#                 when available; otherwise inline scan.
#   5. subtasks — counts unchecked subtask boxes in the story file (when
#                 STORY_FILE is provided via env). Always PASSED if STORY_FILE
#                 is unset (no story-file context available).
#
# Usage:
#   dod-check.sh
#
# Environment:
#   STORY_FILE  — optional. Absolute path to the story file for subtask check.
#   PROJECT_PATH — optional. Project root. Defaults to current working dir.
#
# Exit codes:
#   0 — all rows PASSED
#   1 — at least one row FAILED
#   2 — usage error

set -euo pipefail
LC_ALL=C
export LC_ALL

SCRIPT_NAME="gaia-dev-story/dod-check.sh"

log()  { printf '%s: %s\n' "$SCRIPT_NAME" "$*" >&2; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_LIB_DIR="$(cd "$SCRIPT_DIR/../../../scripts/lib" 2>/dev/null && pwd || echo "")"
INVARIANTS_LIB="$PLUGIN_LIB_DIR/dev-story-security-invariants.sh"

# Capture stdout+stderr; preserve exit code regardless of pipefail surprises.
_run_check() {
  local out rc
  set +e
  out="$("$@" 2>&1)"
  rc=$?
  set -e
  printf '%s\n%d\n' "$out" "$rc"
}

# Emit one YAML row.
_emit_row() {
  local item="$1" status="$2" out="$3"
  # Single-line `output` — collapse newlines, trim length to 200 chars to
  # keep the YAML compact. The Step 9 parser only needs status; output is
  # diagnostic.
  local one_line
  one_line="$(printf '%s' "$out" | tr '\n' ' ' | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//' | cut -c1-200)"
  # Escape double quotes in output.
  one_line="${one_line//\"/\\\"}"
  printf -- '- { item: %s, status: %s, output: "%s" }\n' "$item" "$status" "$one_line"
}

# Run a named check by trying the project's `<name>` command on PATH.
# If the command is not found (or only resolves to a shell builtin), the
# check is reported as PASSED with a "skipped" output — absence of a tool
# means there is nothing to verify here.
_check_command() {
  local item="$1" cmd="$2"
  local result rc out cmd_path
  # Use `type -P` which ONLY resolves PATH-listed files — bash builtins
  # and aliases are skipped. This matters for the `test` check, since
  # `command -v test` returns the builtin and never the project script.
  cmd_path="$(type -P "$cmd" 2>/dev/null || true)"
  if [ -z "$cmd_path" ] || [ ! -f "$cmd_path" ] || [ ! -x "$cmd_path" ]; then
    _emit_row "$item" "PASSED" "skipped: no '$cmd' command on PATH"
    return 0
  fi
  # Skip the system POSIX `test` binary (`/bin/test`, `/usr/bin/test`) —
  # running it with no args exits 1 and is never a project test runner.
  # Without this guard `_check_command "tests" "test"` would always FAIL
  # on macOS / Linux dev machines that lack a project-local `test` wrapper.
  case "$cmd_path" in
    /bin/test|/usr/bin/test|/usr/local/bin/test)
      _emit_row "$item" "PASSED" "skipped: '$cmd' resolves to system POSIX builtin ($cmd_path)"
      return 0
      ;;
  esac
  result="$(_run_check "$cmd_path")"
  rc="$(printf '%s' "$result" | tail -1)"
  out="$(printf '%s' "$result" | sed '$d')"
  if [ "$rc" -eq 0 ]; then
    _emit_row "$item" "PASSED" "$out"
    return 0
  fi
  _emit_row "$item" "FAILED" "$out"
  return 1
}

# Inline secrets scan fallback (when the lib is not available).
_inline_secrets_scan() {
  local files diff base pat patterns
  files="$(git diff --cached --name-only 2>/dev/null || true)"
  if [ -n "$files" ]; then
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      base="$(basename "$f")"
      if printf '%s' "$base" | grep -Eq '^\.env(\..+)?$'; then
        echo "secrets: staged env-like file: $f"
        return 1
      fi
      if printf '%s' "$base" | grep -qiE 'credentials'; then
        echo "secrets: staged credentials-like file: $f"
        return 1
      fi
    done <<<"$files"
  fi
  diff="$(git diff --cached 2>/dev/null || true)"
  if [ -n "$diff" ]; then
    patterns=(
      'AKIA[0-9A-Z]{16}'
      'gh[ps]_[A-Za-z0-9]{36,}'
      'Bearer[[:space:]]+[A-Za-z0-9._-]+'
      'xox[baprs]-[A-Za-z0-9-]{10,}'
    )
    for pat in "${patterns[@]}"; do
      if printf '%s' "$diff" | grep -Eq "$pat"; then
        echo "secrets: staged content matches pattern: $pat"
        return 1
      fi
    done
  fi
  return 0
}

_check_secrets() {
  local out rc
  if [ -f "$INVARIANTS_LIB" ]; then
    # shellcheck disable=SC1090
    set +e
    out="$(bash -c "source '$INVARIANTS_LIB' && assert_no_secrets_staged" 2>&1)"
    rc=$?
    set -e
  else
    set +e
    out="$(_inline_secrets_scan 2>&1)"
    rc=$?
    set -e
  fi
  if [ "$rc" -eq 0 ]; then
    _emit_row "secrets" "PASSED" "no secrets in staged diff"
    return 0
  fi
  _emit_row "secrets" "FAILED" "$out"
  return 1
}

_check_subtasks() {
  if [ -z "${STORY_FILE:-}" ] || [ ! -f "${STORY_FILE:-/dev/null}" ]; then
    _emit_row "subtasks" "PASSED" "skipped: STORY_FILE unset"
    return 0
  fi
  local unchecked
  unchecked="$(grep -cE '^[[:space:]]*- \[ \]' "$STORY_FILE" || true)"
  if [ "$unchecked" -gt 0 ]; then
    _emit_row "subtasks" "FAILED" "unchecked subtask count: $unchecked"
    return 1
  fi
  _emit_row "subtasks" "PASSED" "all subtasks checked"
  return 0
}

# ---------- Main ----------
overall=0
_check_command "build" "build" || overall=1
_check_command "tests" "test"  || overall=1
_check_command "lint"  "lint"  || overall=1
_check_secrets               || overall=1
_check_subtasks              || overall=1

exit "$overall"
