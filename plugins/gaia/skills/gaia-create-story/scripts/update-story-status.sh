#!/usr/bin/env bash
# update-story-status.sh — Cluster 7 story lifecycle wrapper (E28-S52)
#
# Thin wrapper around the shared sprint-state.sh foundation script.
# Transitions a story to a new state (typically backlog for newly created stories).
#
# Usage:
#   update-story-status.sh <story_key> <new_status>
#
# Example:
#   update-story-status.sh E99-S1 backlog
#
# Exit codes:
#   0 — status transition succeeded
#   1 — invalid transition, story not found, or sprint-state.sh failure
#
# Note: sprint-state.sh handles Sprint-Status Write Safety internally —
# it re-reads sprint-status.yaml immediately before writing under flock.

set -euo pipefail
LC_ALL=C
export LC_ALL

SCRIPT_NAME="gaia-create-story/update-story-status.sh"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_SCRIPTS_DIR="$(cd "$SCRIPT_DIR/../../../scripts" && pwd)"

SPRINT_STATE="$PLUGIN_SCRIPTS_DIR/sprint-state.sh"

log() { printf '%s: %s\n' "$SCRIPT_NAME" "$*" >&2; }
die() { log "$*"; exit 1; }

if [ $# -lt 2 ]; then
  die "usage: update-story-status.sh <story_key> <new_status>"
fi

STORY_KEY="$1"
NEW_STATUS="$2"

if [ ! -x "$SPRINT_STATE" ]; then
  die "sprint-state.sh not found or not executable at $SPRINT_STATE"
fi

"$SPRINT_STATE" transition --story "$STORY_KEY" --to "$NEW_STATUS"
