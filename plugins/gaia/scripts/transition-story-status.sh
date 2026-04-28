#!/usr/bin/env bash
# transition-story-status.sh — E54-S3 unified atomic story-status transitions.
#
# Atomically updates ALL FOUR locations a story status lives in, under flock,
# with rollback on partial failure:
#
#   1. Story file frontmatter (`status:` field) + body `**Status:**` line
#   2. sprint-status.yaml entry (delegated to sprint-state.sh)
#   3. epics-and-stories.md per-story `- **Status:** <state>` line
#   4. story-index.yaml entry (created if absent)
#
# This script eliminates a long-standing class of bug where the four files drift
# out of sync because they were written by different scripts with no shared lock.
#
# Usage:
#   transition-story-status.sh <story_key> --to <new_status> [--from <expected_current>]
#   transition-story-status.sh --help
#
# State machine: see lib/story-state-machine.sh.
#
# Exit codes:
#   0  success (including idempotent self-transition no-op)
#   1  generic / usage error
#   2  story file missing
#   3  multiple story files match the glob
#   4  malformed frontmatter (missing or unparseable status)
#   5  epics-and-stories.md missing
#   6  lock contention (5s flock timeout)
#   7  invalid state transition
#   8  rollback after partial failure
#
# Config (env vars, all optional):
#   PROJECT_PATH              — defaults to "."
#   IMPLEMENTATION_ARTIFACTS  — defaults to ${PROJECT_PATH}/docs/implementation-artifacts
#   PLANNING_ARTIFACTS        — defaults to ${PROJECT_PATH}/docs/planning-artifacts
#   MEMORY_PATH               — defaults to ${PROJECT_PATH}/_memory
#   SPRINT_STATUS_YAML        — overrides default yaml path (forwarded to sprint-state.sh)
#   EPICS_AND_STORIES         — overrides default planning artifact path
#   STORY_INDEX_YAML          — overrides default index path
#   STORY_STATUS_LOCK         — overrides default lock path
#
# Refs: AF-2026-04-28-3, FR-338, NFR-056, ADR-042.

set -euo pipefail
LC_ALL=C
export LC_ALL

SCRIPT_NAME="transition-story-status.sh"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"
STATE_MACHINE_LIB="$LIB_DIR/story-state-machine.sh"

# shellcheck source=lib/story-state-machine.sh
. "$STATE_MACHINE_LIB"

err() { printf '%s: error: %s\n' "$SCRIPT_NAME" "$*" >&2; }
log() { printf '%s: %s\n' "$SCRIPT_NAME" "$*" >&2; }

usage() {
  cat <<'USAGE'
Usage:
  transition-story-status.sh <story_key> --to <new_status> [--from <expected_current>]
  transition-story-status.sh --help

Atomically updates the story-file frontmatter, sprint-status.yaml,
epics-and-stories.md, and story-index.yaml under flock, rolling back on any
partial failure.

States: backlog | validating | ready-for-dev | in-progress | blocked | review | done

Exit codes:
  0 success / no-op    1 generic / usage    2 story file missing
  3 multiple matches   4 malformed frontmatter   5 epics-and-stories.md missing
  6 lock contention    7 invalid transition      8 rollback after failure
USAGE
}

# ---------- Argument parsing ----------

if [ $# -lt 1 ]; then usage >&2; exit 1; fi

case "$1" in
  -h|--help) usage; exit 0 ;;
esac

STORY_KEY="$1"; shift || true
NEW_STATUS=""
EXPECTED_FROM=""

while [ $# -gt 0 ]; do
  case "$1" in
    --to)
      [ $# -ge 2 ] || { err "--to requires a value"; exit 1; }
      NEW_STATUS="$2"; shift 2 ;;
    --from)
      [ $# -ge 2 ] || { err "--from requires a value"; exit 1; }
      EXPECTED_FROM="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *)
      err "unknown argument: $1"
      usage >&2
      exit 1 ;;
  esac
done

if [ -z "$NEW_STATUS" ]; then
  err "missing required --to <new_status>"
  usage >&2
  exit 1
fi

if ! is_canonical_story_state "$NEW_STATUS"; then
  err "invalid target state: '$NEW_STATUS' (allowed: $(canonical_story_states_hint))"
  exit 1
fi

if [ -n "$EXPECTED_FROM" ] && ! is_canonical_story_state "$EXPECTED_FROM"; then
  err "invalid --from state: '$EXPECTED_FROM' (allowed: $(canonical_story_states_hint))"
  exit 1
fi

# ---------- Path resolution ----------

PROJECT_PATH="${PROJECT_PATH:-.}"
IMPLEMENTATION_ARTIFACTS="${IMPLEMENTATION_ARTIFACTS:-${PROJECT_PATH}/docs/implementation-artifacts}"
PLANNING_ARTIFACTS="${PLANNING_ARTIFACTS:-${PROJECT_PATH}/docs/planning-artifacts}"
MEMORY_PATH="${MEMORY_PATH:-${PROJECT_PATH}/_memory}"
EPICS_AND_STORIES="${EPICS_AND_STORIES:-${PLANNING_ARTIFACTS}/epics-and-stories.md}"
STORY_INDEX_YAML="${STORY_INDEX_YAML:-${IMPLEMENTATION_ARTIFACTS}/story-index.yaml}"
STORY_STATUS_LOCK="${STORY_STATUS_LOCK:-${MEMORY_PATH}/.story-status.lock}"

# Forward SPRINT_STATUS_YAML untouched if caller pre-set it.

# ---------- Helpers ----------

# Locate the story file and filter by frontmatter `template: 'story'`. Mirrors
# sprint-state.sh's locator semantics so both scripts agree on which file is
# canonical when review-sibling files (e.g. -review.md) sit alongside.
locate_story_file() {
  local key="$1"
  local pattern="${IMPLEMENTATION_ARTIFACTS}/${key}-*.md"

  shopt -s nullglob
  # shellcheck disable=SC2206
  local matches=( $pattern )
  shopt -u nullglob

  if [ "${#matches[@]}" -eq 0 ]; then
    err "no story file found for key '$key' (glob: $pattern)"
    exit 2
  fi

  local canonical=()
  local m
  for m in "${matches[@]}"; do
    if awk '
      /^---[[:space:]]*$/ { n++; if (n == 2) exit }
      n == 1 && /^template:[[:space:]]*["\x27]?story["\x27]?[[:space:]]*$/ { found = 1; exit }
      END { exit (found ? 0 : 1) }
    ' "$m"; then
      canonical+=( "$m" )
    fi
  done

  if [ "${#canonical[@]}" -eq 0 ]; then
    # Fall back to the only match if it has any frontmatter — keeps non-template
    # fixtures working while still rejecting truly-multiple ambiguous matches.
    if [ "${#matches[@]}" -eq 1 ]; then
      printf '%s' "${matches[0]}"
      return 0
    fi
    err "no canonical story file for key '$key' (checked ${#matches[@]} candidates)"
    exit 3
  fi
  if [ "${#canonical[@]}" -gt 1 ]; then
    err "ambiguous canonical story files for key '$key': ${canonical[*]}"
    exit 3
  fi
  printf '%s' "${canonical[0]}"
}

# Read frontmatter `status:` value from a story file.
read_frontmatter_status() {
  local file="$1" status
  status=$(awk '
    BEGIN { in_fm = 0; seen = 0 }
    /^---[[:space:]]*$/ {
      if (!in_fm && !seen) { in_fm = 1; seen = 1; next }
      if (in_fm) exit
    }
    in_fm && /^status:[[:space:]]*/ {
      sub(/^status:[[:space:]]*/, "", $0)
      gsub(/^["'\''[:space:]]+|["'\''[:space:]]+$/, "", $0)
      print $0
      exit
    }
  ' "$file")

  if [ -z "$status" ]; then
    err "story file '$file' is missing 'status:' in frontmatter"
    exit 4
  fi
  printf '%s' "$status"
}

# Snapshot a file to "<file>.bak.<pid>" for rollback. Idempotent — re-snapshot
# overwrites prior snapshot. Returns the snapshot path on stdout. If the file
# does not yet exist, records a marker file recording the absence so rollback
# can rm -f the file the script created.
snapshot_for_rollback() {
  local file="$1"
  local snap="${file}.bak.tss.$$"
  if [ -e "$file" ]; then
    cp -p "$file" "$snap"
  else
    : > "${snap}.absent"
  fi
  printf '%s' "$snap"
}

# Apply a snapshot to its file. Used during rollback only.
restore_snapshot() {
  local file="$1" snap="$2"
  if [ -e "${snap}.absent" ]; then
    rm -f "$file" "${snap}.absent"
    return 0
  fi
  if [ -e "$snap" ]; then
    mv -f "$snap" "$file"
  fi
}

# Cleanup snapshots after successful run.
cleanup_snapshots() {
  local s
  for s in "$@"; do
    rm -f "$s" "${s}.absent" 2>/dev/null || true
  done
}

# Update the frontmatter `status:` field in the story file to NEW_STATUS.
# Tempfile + atomic rename. Body `> **Status:**` lines are also rewritten if
# present — sprint-state.sh insists on that line; we mirror its behaviour.
rewrite_frontmatter() {
  local file="$1" new_status="$2"
  local tmp
  tmp=$(mktemp "${file}.tmp.XXXXXX")
  # shellcheck disable=SC2064
  trap "rm -f '$tmp'" RETURN

  awk -v new_status="$new_status" '
    BEGIN { in_fm = 0; seen = 0; fm_done = 0; rewrote_fm = 0 }
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
      if (raw ~ /\r$/) crlf = "\r"
      printf "status: %s%s\n", new_status, crlf
      rewrote_fm = 1
      next
    }
    fm_done && line ~ /^>[[:space:]]*\*\*Status:\*\*/ {
      crlf = ""
      if (raw ~ /\r$/) crlf = "\r"
      printf "> **Status:** %s%s\n", new_status, crlf
      next
    }
    { print raw }
    END {
      if (!rewrote_fm) exit 2
    }
  ' "$file" > "$tmp" || {
    local rc=$?
    rm -f "$tmp"
    trap - RETURN
    if [ $rc -eq 2 ]; then
      err "failed to locate frontmatter 'status:' in '$file'"
      exit 4
    fi
    err "awk rewrite of '$file' failed (rc=$rc)"
    exit 1
  }

  if ! mv -f "$tmp" "$file"; then
    rm -f "$tmp"
    trap - RETURN
    err "failed to mv tempfile over '$file'"
    exit 1
  fi
  trap - RETURN
}

# Update the sprint-status.yaml status entry by delegating to sprint-state.sh,
# which already serialises yaml writes under its own flock + rewrites the body
# Status line. We pass the env vars through; sprint-state.sh reads its own
# layout from PROJECT_PATH / IMPLEMENTATION_ARTIFACTS / SPRINT_STATUS_YAML.
#
# We bypass sprint-state.sh's adjacency table because our own state-machine
# is a superset and we have already validated the edge. Doing two checks would
# reject perfectly-legal recovery transitions like `validating -> backlog`.
#
# Strategy: skip sprint-state.sh when (a) it is not present, or (b) its
# adjacency table would reject our edge — in both cases write the yaml entry
# directly using a small awk pass that mirrors sprint-state.sh's writer.
update_sprint_status_yaml() {
  local key="$1" new_status="$2"

  local yaml="${SPRINT_STATUS_YAML:-${IMPLEMENTATION_ARTIFACTS}/sprint-status.yaml}"
  if [ -z "${SPRINT_STATUS_YAML:-}" ]; then
    if [ ! -e "$yaml" ] && [ -e "${PROJECT_PATH}/sprint-status.yaml" ]; then
      yaml="${PROJECT_PATH}/sprint-status.yaml"
    fi
  fi

  if [ ! -s "$yaml" ]; then
    # sprint-status.yaml may not exist in fresh-project flows; skip silently.
    log "sprint-status.yaml not found at '$yaml' — skipping yaml update"
    return 0
  fi

  # Direct in-place rewrite (the outer flock already serialises us against
  # other transition-story-status.sh invocations; sprint-state.sh's own lock
  # would only matter for non-transition writers).
  local tmp
  tmp=$(mktemp "${yaml}.tmp.XXXXXX")
  # shellcheck disable=SC2064
  trap "rm -f '$tmp'" RETURN

  awk -v target="$key" -v new_status="$new_status" '
    BEGIN { in_entry = 0; rewrote = 0 }
    {
      raw = $0
      line = $0
      sub(/\r$/, "", line)
    }
    line ~ /^[[:space:]]*-[[:space:]]*key:[[:space:]]*/ {
      k = line
      sub(/^[[:space:]]*-[[:space:]]*key:[[:space:]]*/, "", k)
      gsub(/^["'\''[:space:]]+|["'\''[:space:]]+$/, "", k)
      in_entry = (k == target) ? 1 : 0
      print raw
      next
    }
    in_entry && line ~ /^[^[:space:]]/ { in_entry = 0 }
    in_entry && !rewrote && line ~ /^[[:space:]]+status:[[:space:]]*/ {
      match(raw, /^[[:space:]]+/)
      indent = substr(raw, RSTART, RLENGTH)
      crlf = ""
      if (raw ~ /\r$/) crlf = "\r"
      printf "%sstatus: \"%s\"%s\n", indent, new_status, crlf
      rewrote = 1
      next
    }
    { print raw }
    END {
      if (!rewrote) exit 2
    }
  ' "$yaml" > "$tmp" || {
    local rc=$?
    rm -f "$tmp"
    trap - RETURN
    if [ $rc -eq 2 ]; then
      log "story '$key' not present in sprint-status.yaml — skipping yaml update"
      return 0
    fi
    err "awk rewrite of '$yaml' failed (rc=$rc)"
    exit 1
  }

  if ! mv -f "$tmp" "$yaml"; then
    rm -f "$tmp"
    trap - RETURN
    err "failed to mv tempfile over '$yaml'"
    exit 1
  fi
  trap - RETURN
}

# Update or insert the `- **Status:** <state>` line inside the story's block in
# epics-and-stories.md. The block starts at `### Story <key>:` and ends at the
# next `### Story` or top-level `## ` heading. Bytes outside the block are
# preserved verbatim.
update_epics_and_stories() {
  local key="$1" new_status="$2"
  local file="$EPICS_AND_STORIES"

  if [ ! -s "$file" ]; then
    err "epics-and-stories.md not found at '$file'"
    exit 5
  fi

  local tmp
  tmp=$(mktemp "${file}.tmp.XXXXXX")
  # shellcheck disable=SC2064
  trap "rm -f '$tmp'" RETURN

  awk -v target="$key" -v new_status="$new_status" '
    function emit_status_line() {
      printf "- **Status:** %s\n", new_status
      inserted = 1
    }
    BEGIN {
      in_block = 0
      saw_status = 0
      inserted = 0
      block_seen = 0
    }
    {
      raw = $0
      line = $0
      sub(/\r$/, "", line)
    }
    # Detect block boundaries.
    line ~ /^### Story / {
      # Closing previous block? If we were in target block and never saw a Status line, insert one.
      if (in_block && !saw_status) {
        emit_status_line()
      }
      # Open new block?
      if (index(line, "Story " target ":") > 0) {
        in_block = 1
        saw_status = 0
        block_seen = 1
      } else {
        in_block = 0
      }
      print raw
      next
    }
    # Top-level heading also closes the block.
    in_block && line ~ /^## / && line !~ /^### / {
      if (!saw_status) emit_status_line()
      in_block = 0
      print raw
      next
    }
    # Inside target block — replace existing **Status:** line.
    in_block && line ~ /^- \*\*Status:\*\*/ {
      crlf = ""
      if (raw ~ /\r$/) crlf = "\r"
      printf "- **Status:** %s%s\n", new_status, crlf
      saw_status = 1
      next
    }
    { print raw }
    END {
      # Block ran to EOF without explicit close — flush a Status line if needed.
      if (in_block && !saw_status) {
        emit_status_line()
      }
      if (!block_seen) {
        # Story not found in epics-and-stories.md — soft-warn via exit 3 so the
        # caller can decide. We treat absence as non-fatal but visible.
        exit 3
      }
    }
  ' "$file" > "$tmp"
  local rc=$?
  if [ $rc -ne 0 ]; then
    if [ $rc -eq 3 ]; then
      # Story not present in epics-and-stories.md — leave the file untouched.
      rm -f "$tmp"
      trap - RETURN
      log "story '$key' not present in epics-and-stories.md — skipping (no insert)"
      return 0
    fi
    rm -f "$tmp"
    trap - RETURN
    err "awk rewrite of '$file' failed (rc=$rc)"
    exit 1
  fi

  if ! mv -f "$tmp" "$file"; then
    rm -f "$tmp"
    trap - RETURN
    err "failed to mv tempfile over '$file'"
    exit 1
  fi
  trap - RETURN
}

# Update or insert the story's status entry in story-index.yaml. Creates the
# file with a minimal skeleton if it does not exist.
update_story_index_yaml() {
  local key="$1" new_status="$2"
  local file="$STORY_INDEX_YAML"

  if [ ! -e "$file" ]; then
    mkdir -p "$(dirname "$file")"
    {
      printf '# Auto-maintained by transition-story-status.sh.\n'
      printf 'last_updated: "%s"\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      printf 'stories:\n'
      printf '  %s:\n' "$key"
      printf '    status: "%s"\n' "$new_status"
    } > "$file"
    return 0
  fi

  local tmp
  tmp=$(mktemp "${file}.tmp.XXXXXX")
  # shellcheck disable=SC2064
  trap "rm -f '$tmp'" RETURN

  # Two-pass: first rewrite if the entry exists; if not, append a new entry.
  awk -v target="$key" -v new_status="$new_status" '
    BEGIN { in_entry = 0; rewrote = 0; in_stories = 0; found = 0 }
    {
      raw = $0
      line = $0
      sub(/\r$/, "", line)
    }
    line ~ /^stories:[[:space:]]*$/ { in_stories = 1; print raw; next }
    in_stories && line ~ /^[A-Za-z]/ { in_stories = 0 }
    # Entry header: two-space indent, key name, colon.
    in_stories && line ~ /^  [A-Za-z][A-Za-z0-9_-]*:[[:space:]]*$/ {
      k = line
      sub(/^  /, "", k)
      sub(/:[[:space:]]*$/, "", k)
      if (k == target) { in_entry = 1; found = 1 } else { in_entry = 0 }
      print raw
      next
    }
    # Leaving the entry: any line at indent <= 2 that is not blank.
    in_entry && line ~ /^[A-Za-z]/ { in_entry = 0 }
    in_entry && line ~ /^  [A-Za-z]/ { in_entry = 0 }
    in_entry && !rewrote && line ~ /^[[:space:]]+status:[[:space:]]*/ {
      match(raw, /^[[:space:]]+/)
      indent = substr(raw, RSTART, RLENGTH)
      crlf = ""
      if (raw ~ /\r$/) crlf = "\r"
      printf "%sstatus: \"%s\"%s\n", indent, new_status, crlf
      rewrote = 1
      next
    }
    { print raw }
    END {
      # If entry was found but had no status field, append one.
      if (found && !rewrote) {
        printf "    status: \"%s\"\n", new_status
      }
      # If entry not found, append a brand new minimal entry.
      if (!found) {
        printf "  %s:\n", target
        printf "    status: \"%s\"\n", new_status
      }
    }
  ' "$file" > "$tmp" || {
    rm -f "$tmp"
    trap - RETURN
    err "awk rewrite of '$file' failed"
    exit 1
  }

  if ! mv -f "$tmp" "$file"; then
    rm -f "$tmp"
    trap - RETURN
    err "failed to mv tempfile over '$file'"
    exit 1
  fi
  trap - RETURN
}

# ---------- Main flow ----------

# Resolve the story file (exit 2/3 on missing/multiple).
STORY_FILE="$(locate_story_file "$STORY_KEY")"

# Acquire the cross-file lock.
mkdir -p "$(dirname "$STORY_STATUS_LOCK")"
exec 200>"$STORY_STATUS_LOCK"
if command -v flock >/dev/null 2>&1; then
  if ! flock -w 5 200; then
    err "lock contention on '$STORY_STATUS_LOCK' (5s timeout) — retry shortly"
    exit 6
  fi
fi

CURRENT_STATUS="$(read_frontmatter_status "$STORY_FILE")"

# --from check.
if [ -n "$EXPECTED_FROM" ] && [ "$CURRENT_STATUS" != "$EXPECTED_FROM" ]; then
  err "expected current status '$EXPECTED_FROM' but found '$CURRENT_STATUS'"
  exit 1
fi

# Idempotent self-transition.
if [ "$CURRENT_STATUS" = "$NEW_STATUS" ]; then
  log "no-op (story already at $NEW_STATUS)"
  exit 0
fi

# State-machine validation.
if ! validate_story_transition "$CURRENT_STATUS" "$NEW_STATUS"; then
  exit 7
fi

# Snapshot every file we may touch so we can roll back on partial failure.
SNAP_STORY="$(snapshot_for_rollback "$STORY_FILE")"
SNAP_YAML=""
SNAP_EPICS="$(snapshot_for_rollback "$EPICS_AND_STORIES")"
SNAP_INDEX="$(snapshot_for_rollback "$STORY_INDEX_YAML")"

YAML_PATH_FOR_SNAP="${SPRINT_STATUS_YAML:-${IMPLEMENTATION_ARTIFACTS}/sprint-status.yaml}"
if [ -e "$YAML_PATH_FOR_SNAP" ]; then
  SNAP_YAML="$(snapshot_for_rollback "$YAML_PATH_FOR_SNAP")"
fi

rollback() {
  log "rolling back partial transition for $STORY_KEY"
  restore_snapshot "$STORY_FILE" "$SNAP_STORY" 2>/dev/null || true
  if [ -n "$SNAP_YAML" ]; then
    restore_snapshot "$YAML_PATH_FOR_SNAP" "$SNAP_YAML" 2>/dev/null || true
  fi
  restore_snapshot "$EPICS_AND_STORIES" "$SNAP_EPICS" 2>/dev/null || true
  restore_snapshot "$STORY_INDEX_YAML" "$SNAP_INDEX" 2>/dev/null || true
}

# Custom failure handler: roll back, then exit 8.
TSS_ROLLBACK_PENDING=1
trap '
  rc=$?
  if [ "${TSS_ROLLBACK_PENDING:-0}" = "1" ] && [ $rc -ne 0 ]; then
    rollback
    exit 8
  fi
' EXIT

# Each step below MUST be wrapped so a failure triggers rollback. We rely on
# `set -e` + the EXIT trap to short-circuit; no bare `exit 1` paths in the
# helpers escape rollback because the EXIT trap fires regardless.

rewrite_frontmatter "$STORY_FILE" "$NEW_STATUS"
update_sprint_status_yaml "$STORY_KEY" "$NEW_STATUS"
update_epics_and_stories "$STORY_KEY" "$NEW_STATUS"
update_story_index_yaml "$STORY_KEY" "$NEW_STATUS"

# All four files written successfully — commit.
TSS_ROLLBACK_PENDING=0
trap - EXIT

cleanup_snapshots "$SNAP_STORY" "$SNAP_YAML" "$SNAP_EPICS" "$SNAP_INDEX"

log "$STORY_KEY transitioned $CURRENT_STATUS -> $NEW_STATUS"
exit 0
