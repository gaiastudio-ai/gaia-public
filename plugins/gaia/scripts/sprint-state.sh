#!/usr/bin/env bash
# sprint-state.sh — GAIA foundation script (E28-S11)
#
# Validates sprint state machine transitions, updates the story file
# frontmatter + body `**Status:**` line and `sprint-status.yaml` atomically,
# and emits a lifecycle event on every successful transition. Replaces the
# LLM-interpreted status-sync protocol with a deterministic, race-safe
# script per ADR-042 / ADR-048.
#
# Refs: FR-325, FR-328, NFR-048, ADR-042, ADR-048
# Brief: P2-S3 (docs/creative-artifacts/gaia-native-conversion-feature-brief-2026-04-14.md)
#
# Invocation contract (stable for E28-S17 bats-core authors):
#
#   sprint-state.sh transition --story <key> --to <state>
#   sprint-state.sh get        --story <key>
#   sprint-state.sh validate   --story <key>
#   sprint-state.sh --help
#
# Canonical state set (from CLAUDE.md#Sprint State Machine):
#   backlog | validating | ready-for-dev | in-progress | blocked | review | done
#
# Allowed adjacency (edges encoded verbatim from CLAUDE.md):
#   backlog        -> validating
#   validating     -> ready-for-dev
#   ready-for-dev  -> in-progress
#   in-progress    -> blocked
#   in-progress    -> review
#   blocked        -> in-progress
#   review         -> in-progress
#   review         -> done
#
# Sprint-Status Write Safety (CRITICAL, per CLAUDE.md):
#   The story file is the source of truth — sprint-status.yaml is a derived
#   cached view. This script ALWAYS re-reads sprint-status.yaml under flock
#   immediately before writing. It updates both locations inside the same
#   critical section so no concurrent reader sees a drifted pair.
#
# Review Gate check on -> done (AC6):
#   Transitions to 'done' shell out to review-gate.sh status and require all
#   six canonical rows to report PASSED. Any other verdict (UNVERIFIED or
#   FAILED) blocks the transition with the offending row names enumerated.
#
# Config:
#   PROJECT_PATH                — defaults to "." when unset. Story files and
#                                 sprint-status.yaml are located relative to it.
#   IMPLEMENTATION_ARTIFACTS    — defaults to "${PROJECT_PATH}/docs/implementation-artifacts".
#   SPRINT_STATE_SCRIPT_DIR     — internal. Directory of this script, used to
#                                 locate sibling scripts (lifecycle-event.sh,
#                                 review-gate.sh). Override only in tests.
#
# Atomicity & concurrency:
#   All sprint-status.yaml writes are serialized by `flock -x -w 5` on a
#   sibling `sprint-status.yaml.lock` file. Every write (story file AND
#   sprint-status.yaml) is tempfile + atomic `mv`. The same critical section
#   covers:
#     1. read current status from story file
#     2. validate adjacency
#     3. re-read sprint-status.yaml
#     4. rewrite story file via tempfile + mv
#     5. rewrite sprint-status.yaml via tempfile + mv
#     6. emit lifecycle event
#   If step 6 fails the file writes are not rolled back, but the script exits
#   1 and surfaces the failure (AC-EC4: "event failure surfaced with exit 1").
#   Subsequent `validate` will detect drift if any downstream consumer cares.
#
# POSIX discipline: the only non-POSIX constructs are [[ ]] and bash indexed
# arrays. macOS /bin/bash 3.2 compatible. Uses `awk`, `sed`, `grep`, `mktemp`,
# and optionally `flock` (graceful mv-based fallback when absent, same
# pattern as checkpoint.sh / lifecycle-event.sh / review-gate.sh).

set -euo pipefail
LC_ALL=C
export LC_ALL

SCRIPT_NAME="sprint-state.sh"

# ---------- Canonical state machine ----------

CANONICAL_STATES=(
  "backlog"
  "validating"
  "ready-for-dev"
  "in-progress"
  "blocked"
  "review"
  "done"
)

# Allowed adjacency encoded as "from|to" strings (CLAUDE.md verbatim).
ALLOWED_EDGES=(
  "backlog|validating"
  "validating|ready-for-dev"
  "ready-for-dev|in-progress"
  "in-progress|blocked"
  "in-progress|review"
  "blocked|in-progress"
  "review|in-progress"
  "review|done"
)

# ---------- Helpers ----------

die() {
  printf '%s: error: %s\n' "$SCRIPT_NAME" "$*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
Usage:
  sprint-state.sh transition --story <key> --to <state>
  sprint-state.sh get        --story <key>
  sprint-state.sh validate   --story <key>
  sprint-state.sh --help

Subcommands:
  transition  Atomically transition a story to <state>. Validates adjacency,
              re-reads sprint-status.yaml under flock, rewrites story file
              frontmatter + body Status line + sprint-status.yaml, and emits
              one lifecycle event. Transitions to 'done' require all six
              Review Gate rows to report PASSED (via review-gate.sh status).
  get         Print the story's current status (from the story file) to
              stdout and exit 0.
  validate    Compare story file status to sprint-status.yaml. Exit 0 if
              they agree, exit 1 with a drift description on stderr if not.

Canonical states (CLAUDE.md):
  backlog | validating | ready-for-dev | in-progress | blocked | review | done

Config:
  PROJECT_PATH                defaults to "."
  IMPLEMENTATION_ARTIFACTS    defaults to "${PROJECT_PATH}/docs/implementation-artifacts"

Exit codes:
  0  success
  1  usage error, invalid state, illegal transition, missing file, lock
     failure, review gate failure, glob mismatch, or drift (validate)
USAGE
}

is_canonical_state() {
  local candidate="$1"
  local s
  for s in "${CANONICAL_STATES[@]}"; do
    [ "$s" = "$candidate" ] && return 0
  done
  return 1
}

# Exit 1 unless "from -> to" is in ALLOWED_EDGES.
validate_transition() {
  local from="$1" to="$2"
  local edge
  for edge in "${ALLOWED_EDGES[@]}"; do
    if [ "$edge" = "${from}|${to}" ]; then
      return 0
    fi
  done
  die "illegal transition: '${from}' -> '${to}' is not in the allowed adjacency list"
}

# Resolve configuration — PROJECT_PATH and IMPLEMENTATION_ARTIFACTS directory.
resolve_paths() {
  PROJECT_PATH="${PROJECT_PATH:-.}"
  IMPLEMENTATION_ARTIFACTS="${IMPLEMENTATION_ARTIFACTS:-${PROJECT_PATH}/docs/implementation-artifacts}"
  SPRINT_STATUS_YAML="${IMPLEMENTATION_ARTIFACTS}/sprint-status.yaml"
  SPRINT_STATUS_LOCK="${SPRINT_STATUS_YAML}.lock"
}

# Locate the story file via glob `{story_key}-*.md` under IMPLEMENTATION_ARTIFACTS.
# Returns via the STORY_FILE global. Exits 1 on zero or multiple matches
# (AC-EC5).
STORY_FILE=""
locate_story_file() {
  local key="$1"
  local pattern="${IMPLEMENTATION_ARTIFACTS}/${key}-*.md"

  local matches=()
  shopt -s nullglob
  # shellcheck disable=SC2206
  matches=( $pattern )
  shopt -u nullglob

  if [ "${#matches[@]}" -eq 0 ]; then
    die "no story file found for key '$key' (glob: $pattern)"
  fi
  if [ "${#matches[@]}" -gt 1 ]; then
    {
      printf '%s: error: multiple story files matched key %s (glob: %s)\n' \
        "$SCRIPT_NAME" "$key" "$pattern"
      printf '  %s\n' "${matches[@]}"
    } >&2
    exit 1
  fi

  STORY_FILE="${matches[0]}"
}

# Extract the current status from a story file's frontmatter. The story
# template uses `status: <value>` (unquoted or quoted). Returns via stdout.
# Exits 1 if the field is missing.
read_story_status() {
  local file="$1"
  # Only scan the frontmatter block (between the first two `---` lines).
  local status
  status=$(awk '
    BEGIN { in_fm = 0; seen = 0 }
    /^---[[:space:]]*$/ {
      if (!in_fm && !seen) { in_fm = 1; seen = 1; next }
      if (in_fm) { exit }
    }
    in_fm && /^status:[[:space:]]*/ {
      sub(/^status:[[:space:]]*/, "", $0)
      gsub(/^["'\''[:space:]]+|["'\''[:space:]]+$/, "", $0)
      print $0
      exit
    }
  ' "$file")

  if [ -z "$status" ]; then
    die "story file '$file' is missing 'status:' in frontmatter"
  fi
  printf '%s' "$status"
}

# Rewrite a story file so that (a) the frontmatter `status:` field and
# (b) the body `**Status:**` line both show $new_status. Preserves all
# other bytes. Tempfile + atomic mv.
rewrite_story_status() {
  local file="$1" new_status="$2"
  local tmp
  tmp=$(mktemp "${file}.tmp.XXXXXX")
  # shellcheck disable=SC2064
  trap "rm -f '$tmp'" RETURN

  awk -v new_status="$new_status" '
    BEGIN { in_fm = 0; seen = 0; fm_done = 0; rewrote_fm = 0; rewrote_body = 0 }
    {
      raw = $0
      line = $0
      sub(/\r$/, "", line)
    }
    !fm_done && line ~ /^---[[:space:]]*$/ {
      if (!in_fm && !seen) { in_fm = 1; seen = 1; print raw; next }
      if (in_fm) { in_fm = 0; fm_done = 1; print raw; next }
    }
    in_fm && !rewrote_fm && line ~ /^status:[[:space:]]*/ {
      crlf = ""
      if (raw ~ /\r$/) { crlf = "\r" }
      printf "status: %s%s\n", new_status, crlf
      rewrote_fm = 1
      next
    }
    fm_done && !rewrote_body && line ~ /^>[[:space:]]*\*\*Status:\*\*/ {
      crlf = ""
      if (raw ~ /\r$/) { crlf = "\r" }
      printf "> **Status:** %s%s\n", new_status, crlf
      rewrote_body = 1
      next
    }
    { print raw }
    END {
      if (!rewrote_fm)   { exit 2 }
      if (!rewrote_body) { exit 3 }
    }
  ' "$file" > "$tmp" || {
    local rc=$?
    rm -f "$tmp"
    trap - RETURN
    if [ $rc -eq 2 ]; then
      die "failed to locate frontmatter 'status:' field in '$file'"
    elif [ $rc -eq 3 ]; then
      die "failed to locate body '> **Status:**' line in '$file'"
    else
      die "awk rewrite of '$file' failed (rc=$rc)"
    fi
  }

  if ! mv -f "$tmp" "$file"; then
    rm -f "$tmp"
    trap - RETURN
    die "failed to mv tempfile over '$file'"
  fi
  trap - RETURN
}

# Rewrite the matching story entry in sprint-status.yaml so its `status:`
# field reads $new_status. Preserves all other bytes. Tempfile + atomic mv.
# Exits 1 if the story entry is not found (so drift is loud, never silent).
rewrite_sprint_status_yaml() {
  local story_key="$1" new_status="$2"
  local file="$SPRINT_STATUS_YAML"

  if [ ! -s "$file" ]; then
    die "sprint-status.yaml is missing or empty: $file"
  fi

  local tmp
  tmp=$(mktemp "${file}.tmp.XXXXXX")
  # shellcheck disable=SC2064
  trap "rm -f '$tmp'" RETURN

  awk -v target="$story_key" -v new_status="$new_status" '
    BEGIN { in_entry = 0; rewrote = 0 }
    {
      raw = $0
      line = $0
      sub(/\r$/, "", line)
    }
    # A new list entry starts with `  - key:` at two-space indent.
    line ~ /^[[:space:]]*-[[:space:]]*key:[[:space:]]*/ {
      # Extract the key value and strip quotes.
      k = line
      sub(/^[[:space:]]*-[[:space:]]*key:[[:space:]]*/, "", k)
      gsub(/^["'\''[:space:]]+|["'\''[:space:]]+$/, "", k)
      if (k == target) { in_entry = 1 } else { in_entry = 0 }
      print raw
      next
    }
    # Any subsequent list entry or top-level key closes the current entry.
    in_entry && line ~ /^[^[:space:]]/ {
      in_entry = 0
    }
    in_entry && !rewrote && line ~ /^[[:space:]]+status:[[:space:]]*/ {
      # Preserve the original indentation.
      match(raw, /^[[:space:]]+/)
      indent = substr(raw, RSTART, RLENGTH)
      crlf = ""
      if (raw ~ /\r$/) { crlf = "\r" }
      printf "%sstatus: \"%s\"%s\n", indent, new_status, crlf
      rewrote = 1
      next
    }
    { print raw }
    END {
      if (!rewrote) { exit 2 }
    }
  ' "$file" > "$tmp" || {
    local rc=$?
    rm -f "$tmp"
    trap - RETURN
    if [ $rc -eq 2 ]; then
      die "story '$story_key' not found in $file"
    fi
    die "awk rewrite of '$file' failed (rc=$rc)"
  }

  if ! mv -f "$tmp" "$file"; then
    rm -f "$tmp"
    trap - RETURN
    die "failed to mv tempfile over '$file'"
  fi
  trap - RETURN
}

# Extract the status for $story_key from sprint-status.yaml. Stdout.
read_sprint_status_yaml_status() {
  local story_key="$1"
  local file="$SPRINT_STATUS_YAML"

  if [ ! -s "$file" ]; then
    die "sprint-status.yaml is missing or empty: $file"
  fi

  awk -v target="$story_key" '
    BEGIN { in_entry = 0; found = 0 }
    {
      line = $0
      sub(/\r$/, "", line)
    }
    line ~ /^[[:space:]]*-[[:space:]]*key:[[:space:]]*/ {
      k = line
      sub(/^[[:space:]]*-[[:space:]]*key:[[:space:]]*/, "", k)
      gsub(/^["'\''[:space:]]+|["'\''[:space:]]+$/, "", k)
      if (k == target) { in_entry = 1 } else { in_entry = 0 }
      next
    }
    in_entry && line ~ /^[^[:space:]]/ { in_entry = 0 }
    in_entry && line ~ /^[[:space:]]+status:[[:space:]]*/ {
      v = line
      sub(/^[[:space:]]+status:[[:space:]]*/, "", v)
      gsub(/^["'\''[:space:]]+|["'\''[:space:]]+$/, "", v)
      print v
      found = 1
      exit
    }
    END {
      if (!found) { exit 2 }
    }
  ' "$file" || die "story '$story_key' not found in sprint-status.yaml"
}

# Check the Review Gate for the story. Returns 0 if all six canonical rows
# report PASSED; otherwise exits 1 with the non-PASSED rows listed.
check_review_gate_all_passed() {
  local story_key="$1"
  local review_gate_sh="${SPRINT_STATE_SCRIPT_DIR}/review-gate.sh"
  if [ ! -x "$review_gate_sh" ]; then
    die "review-gate.sh not found or not executable at $review_gate_sh (required for ' -> done' transitions)"
  fi
  # Call with an isolated PROJECT_PATH if review-gate.sh lays out story files
  # under docs/implementation-artifacts/stories/ — our layout is flat, so we
  # instead call `check` directly and rely on its own locator. review-gate.sh
  # uses `${PROJECT_PATH}/docs/implementation-artifacts/stories/<key>-*.md`;
  # fall back to a thin parser that reads the Review Gate table from the
  # story file we already resolved. This keeps E28-S11 independent of any
  # later refactor to review-gate.sh's layout assumptions.
  local missing
  missing=$(awk '
    BEGIN { in_section = 0; in_table = 0; saw_sep = 0 }
    /^## Review Gate[[:space:]]*$/ { in_section = 1; in_table = 0; saw_sep = 0; next }
    in_section && /^## / { in_section = 0; in_table = 0; next }
    !in_section { next }
    { sub(/\r$/, "", $0) }
    in_section && !in_table {
      if ($0 ~ /^[[:space:]]*\|/) { in_table = 1; saw_sep = 0; next }
      next
    }
    in_table {
      if ($0 !~ /^[[:space:]]*\|/) { in_table = 0; in_section = 0; next }
      if (!saw_sep && $0 ~ /^[[:space:]]*\|[[:space:]]*-+/) { saw_sep = 1; next }
      line = $0
      sub(/^[[:space:]]*\|/, "", line)
      sub(/\|[[:space:]]*$/, "", line)
      n = split(line, cells, /\|/)
      if (n < 2) next
      gate = cells[1]; status = cells[2]
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", gate)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", status)
      if (status != "PASSED") {
        printf "%s=%s\n", gate, status
      }
    }
  ' "$STORY_FILE")

  if [ -n "$missing" ]; then
    {
      printf '%s: error: Review Gate not fully PASSED for story %s — transition to done rejected:\n' \
        "$SCRIPT_NAME" "$story_key"
      printf '%s\n' "$missing" | sed 's/^/  /'
    } >&2
    exit 1
  fi
}

# Emit one state_transition lifecycle event. Shells out to lifecycle-event.sh
# as a separate process per Technical Notes. If the script is missing or
# exits non-zero, we surface the failure (AC-EC4).
emit_lifecycle_event() {
  local story_key="$1" from="$2" to="$3"
  local lifecycle_sh="${SPRINT_STATE_SCRIPT_DIR}/lifecycle-event.sh"
  if [ ! -x "$lifecycle_sh" ]; then
    die "lifecycle-event.sh not found or not executable at $lifecycle_sh (required by AC3)"
  fi
  local data
  data=$(printf '{"from":"%s","to":"%s"}' "$from" "$to")
  if ! "$lifecycle_sh" \
        --type state_transition \
        --workflow sprint-state \
        --story "$story_key" \
        --data "$data"; then
    die "lifecycle-event.sh failed for $story_key ($from -> $to) — story file and sprint-status.yaml updates completed but event log write failed; run sprint-state.sh validate --story $story_key to check for drift"
  fi
}

# ---------- Subcommand: get ----------

cmd_get() {
  local story_key="$1"
  locate_story_file "$story_key"
  read_story_status "$STORY_FILE"
  printf '\n'
}

# ---------- Subcommand: validate ----------

cmd_validate() {
  local story_key="$1"
  locate_story_file "$story_key"
  local story_status yaml_status
  story_status=$(read_story_status "$STORY_FILE")
  yaml_status=$(read_sprint_status_yaml_status "$story_key")
  if [ "$story_status" != "$yaml_status" ]; then
    printf '%s: drift detected for %s: story file says %q, sprint-status.yaml says %q\n' \
      "$SCRIPT_NAME" "$story_key" "$story_status" "$yaml_status" >&2
    exit 1
  fi
  return 0
}

# ---------- Subcommand: transition ----------

# The core of the transition logic — runs inside the flock critical section.
do_transition_locked() {
  local story_key="$1" to_state="$2"

  # (a) Re-read sprint-status.yaml immediately before writing (Sprint-Status
  # Write Safety). If the file is missing/empty, fail before touching the
  # story file (AC-EC1).
  if [ ! -s "$SPRINT_STATUS_YAML" ]; then
    die "sprint-status.yaml is missing or empty: $SPRINT_STATUS_YAML"
  fi

  # Locate the story file now that we hold the lock.
  locate_story_file "$story_key"

  # Read current status from the story file (source of truth).
  local from_state
  from_state=$(read_story_status "$STORY_FILE")

  # No-op guard: identical transitions are not legal adjacency edges and
  # would be caught below, but surface a clearer message.
  if [ "$from_state" = "$to_state" ]; then
    die "story $story_key is already in state '$to_state'"
  fi

  # Validate adjacency (AC2, AC-EC2).
  validate_transition "$from_state" "$to_state"

  # Review Gate enforcement for -> done (AC6, AC-EC7).
  if [ "$to_state" = "done" ]; then
    check_review_gate_all_passed "$story_key"
  fi

  # (b, c) Atomic updates: story file first (source of truth), then yaml.
  rewrite_story_status "$STORY_FILE" "$to_state"
  rewrite_sprint_status_yaml "$story_key" "$to_state"

  # (d) Emit exactly one lifecycle event. Any failure exits 1; file writes
  # are NOT rolled back — callers MUST treat a non-zero exit from transition
  # as "run validate and fix drift". AC-EC4 explicitly permits this
  # "surfaced with exit 1" branch of the OR.
  emit_lifecycle_event "$story_key" "$from_state" "$to_state"

  printf '%s: %s transitioned %s -> %s\n' "$SCRIPT_NAME" "$story_key" "$from_state" "$to_state"
}

cmd_transition() {
  local story_key="$1" to_state="$2"

  is_canonical_state "$to_state" || die "unknown target state: '$to_state'"

  local flock_bin
  flock_bin=$(command -v flock || true)

  if [ -n "$flock_bin" ]; then
    (
      exec 9>"$SPRINT_STATUS_LOCK"
      if ! "$flock_bin" -x -w 5 9; then
        die "flock timeout acquiring $SPRINT_STATUS_LOCK"
      fi
      do_transition_locked "$story_key" "$to_state"
    )
  else
    # mv-based spin-loop fallback — same pattern as sibling foundation
    # scripts (checkpoint.sh, lifecycle-event.sh, review-gate.sh).
    local tries=0
    while ! ( set -C; : > "$SPRINT_STATUS_LOCK" ) 2>/dev/null; do
      tries=$((tries + 1))
      if [ "$tries" -ge 50 ]; then
        die "lock timeout acquiring $SPRINT_STATUS_LOCK"
      fi
      sleep 0.1 2>/dev/null || sleep 1
    done
    # shellcheck disable=SC2064
    trap "rm -f '$SPRINT_STATUS_LOCK'" EXIT INT TERM
    do_transition_locked "$story_key" "$to_state"
    rm -f "$SPRINT_STATUS_LOCK"
    trap - EXIT INT TERM
  fi
}

# ---------- Argument parsing ----------

main() {
  local subcmd="${1:-}"
  if [ -z "$subcmd" ]; then
    usage >&2
    exit 1
  fi
  shift || true

  case "$subcmd" in
    --help|-h)
      usage
      exit 0
      ;;
    transition|get|validate)
      ;;
    *)
      printf '%s: error: unknown subcommand: %s\n' "$SCRIPT_NAME" "$subcmd" >&2
      usage >&2
      exit 1
      ;;
  esac

  local story_key="" to_state=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --story)
        [ $# -ge 2 ] || die "--story requires a value"
        story_key="$2"; shift 2 ;;
      --story=*)
        story_key="${1#--story=}"; shift ;;
      --to)
        [ $# -ge 2 ] || die "--to requires a value"
        to_state="$2"; shift 2 ;;
      --to=*)
        to_state="${1#--to=}"; shift ;;
      --help|-h)
        usage
        exit 0 ;;
      *)
        die "unknown flag: $1" ;;
    esac
  done

  [ -n "$story_key" ] || die "$subcmd requires --story <key>"

  # Resolve SPRINT_STATE_SCRIPT_DIR (directory containing this script) for
  # sibling script lookups. Respect a pre-exported override for tests.
  if [ -z "${SPRINT_STATE_SCRIPT_DIR:-}" ]; then
    SPRINT_STATE_SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
  fi
  resolve_paths

  case "$subcmd" in
    get)
      cmd_get "$story_key" ;;
    validate)
      cmd_validate "$story_key" ;;
    transition)
      [ -n "$to_state" ] || die "transition requires --to <state>"
      cmd_transition "$story_key" "$to_state" ;;
  esac
}

main "$@"
