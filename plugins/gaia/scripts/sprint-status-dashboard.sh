#!/usr/bin/env bash
# sprint-status-dashboard.sh — deterministic sprint status dashboard formatter (E28-S61)
#
# Reads sprint-status.yaml (located at ${PROJECT_PATH}/docs/implementation-artifacts/
# sprint-status.yaml) and renders a plain-text dashboard table to stdout. This script
# is the read-only rendering peer to sprint-state.sh (E28-S11) — it NEVER opens
# sprint-status.yaml for write under any code path.
#
# Refs: FR-323, FR-325, NFR-048, NFR-053, ADR-041, ADR-042
# Brief: P8-S2 (docs/creative-artifacts/gaia-native-conversion-feature-brief-2026-04-14.md)
#
# Invocation:
#   sprint-status-dashboard.sh [--help]
#
# Environment:
#   PROJECT_PATH  — root of the project (defaults to ".")
#
# Exit codes:
#   0 — dashboard rendered successfully
#   1 — sprint-status.yaml not found, parse error, or missing dependencies
#
# POSIX discipline: bash with set -euo pipefail. macOS /bin/bash 3.2 compatible.
# READ-ONLY: This script NEVER writes to sprint-status.yaml. It opens the file
# with read access only and produces output exclusively on stdout.

set -euo pipefail
LC_ALL=C
export LC_ALL

SCRIPT_NAME="sprint-status-dashboard.sh"

# ---------- Help ----------
if [[ "${1:-}" == "--help" ]]; then
  cat <<'USAGE'
sprint-status-dashboard.sh — render sprint status dashboard from sprint-status.yaml

Usage: sprint-status-dashboard.sh [--help]

Environment:
  PROJECT_PATH  Root of the project (default: ".")

Reads sprint-status.yaml and renders a deterministic plain-text dashboard to stdout.
This script is read-only — it NEVER modifies sprint-status.yaml.
USAGE
  exit 0
fi

# ---------- Resolve paths ----------
PROJECT_PATH="${PROJECT_PATH:-.}"
YAML_PATH="$PROJECT_PATH/docs/implementation-artifacts/sprint-status.yaml"

log() { printf '%s: %s\n' "$SCRIPT_NAME" "$*" >&2; }
die() { log "ERROR: $*"; exit 1; }

# ---------- Validate input ----------
if [[ ! -f "$YAML_PATH" ]]; then
  die "sprint-status.yaml not found at $YAML_PATH"
fi

# ---------- Check dependencies ----------
# We use grep/sed/awk for pure-bash parsing (no yq dependency required).
# Validate the file is parseable YAML by checking for the sprint_id key.
if ! grep -q "^sprint_id:" "$YAML_PATH" 2>/dev/null; then
  die "malformed or empty sprint-status.yaml — missing sprint_id key"
fi

# ---------- Parse header fields ----------
# Helper: extract a top-level YAML scalar. Returns empty string if key is absent.
yaml_val() {
  grep "^${1}:" "$YAML_PATH" 2>/dev/null | sed "s/^${1}:[[:space:]]*//" | tr -d '"' || true
}

sprint_id=$(yaml_val sprint_id)
duration=$(yaml_val duration)
velocity=$(yaml_val velocity_capacity)
total_points=$(yaml_val total_points)
started=$(yaml_val started)
end_date=$(yaml_val end_date)
capacity_util=$(yaml_val capacity_utilization)
epic_focus=$(yaml_val epic_focus)

# ---------- Render header ----------
printf '=%.0s' {1..72}; printf '\n'
printf '  SPRINT STATUS DASHBOARD\n'
printf '=%.0s' {1..72}; printf '\n'
printf '  Sprint:     %s\n' "${sprint_id:-N/A}"
printf '  Duration:   %s\n' "${duration:-N/A}"
printf '  Dates:      %s → %s\n' "${started:-N/A}" "${end_date:-N/A}"
printf '  Velocity:   %s pts (capacity: %s)\n' "${total_points:-0}" "${velocity:-N/A}"
if [[ -n "$capacity_util" ]]; then
  printf '  Utilization: %s\n' "$capacity_util"
fi
if [[ -n "$epic_focus" ]]; then
  printf '  Focus:      %s\n' "$epic_focus"
fi
printf -- '-%.0s' {1..72}; printf '\n'

# ---------- Parse stories ----------
# Extract story blocks from the YAML. Each story starts with "  - key:" under stories:.
# Pure-bash approach: read lines after "stories:" and parse key/value pairs per block.

in_stories=false
story_count=0

# Column headers
printf '  %-12s %-38s %-14s %s\n' "Story" "Title" "Status" "Pts"
printf '  %-12s %-38s %-14s %s\n' "-----" "-----" "------" "---"

# Track story data
s_key="" s_title="" s_status="" s_points=""

flush_story() {
  if [[ -n "$s_key" ]]; then
    # Truncate title to 36 chars
    local display_title="$s_title"
    if [[ ${#display_title} -gt 36 ]]; then
      display_title="${display_title:0:33}..."
    fi
    printf '  %-12s %-38s %-14s %s\n' "$s_key" "$display_title" "$s_status" "$s_points"
    story_count=$((story_count + 1))
  fi
  s_key="" s_title="" s_status="" s_points=""
}

while IFS= read -r line; do
  # Detect the stories: key
  if [[ "$line" =~ ^stories: ]]; then
    in_stories=true
    continue
  fi

  if [[ "$in_stories" == true ]]; then
    # A new top-level key (not indented) ends the stories block
    if [[ "$line" =~ ^[a-z_] ]]; then
      in_stories=false
      flush_story
      continue
    fi

    # New story block starts with "  - key:"
    if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*key:[[:space:]]* ]]; then
      flush_story
      s_key=$(echo "$line" | sed 's/.*key:[[:space:]]*//' | tr -d '"')
      continue
    fi

    # Parse fields within a story block
    if [[ "$line" =~ ^[[:space:]]+title:[[:space:]]* ]]; then
      s_title=$(echo "$line" | sed 's/.*title:[[:space:]]*//' | tr -d '"')
    elif [[ "$line" =~ ^[[:space:]]+status:[[:space:]]* ]]; then
      s_status=$(echo "$line" | sed 's/.*status:[[:space:]]*//' | tr -d '"')
    elif [[ "$line" =~ ^[[:space:]]+points:[[:space:]]* ]]; then
      s_points=$(echo "$line" | sed 's/.*points:[[:space:]]*//' | tr -d '"')
    fi
  fi
done < "$YAML_PATH"

# Flush last story if still in stories block
if [[ "$in_stories" == true ]]; then
  flush_story
fi

# ---------- Footer ----------
printf -- '-%.0s' {1..72}; printf '\n'
printf '  Total: %d stories | %s points\n' "$story_count" "${total_points:-0}"
printf '=%.0s' {1..72}; printf '\n'

exit 0
