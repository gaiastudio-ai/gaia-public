#!/usr/bin/env bash
# sprint-state.sh — gaia-dev-story sprint state wrapper (E28-S53)
#
# Thin wrapper around the shared sprint-state.sh foundation script.
# Provides story state machine transitions for dev-story's lifecycle:
#   backlog → in-progress → review → done
#
# Usage:
#   sprint-state.sh get <story_key>
#   sprint-state.sh transition <story_key> <new_status>
#
# Exit codes:
#   0 — operation succeeded
#   1 — invalid transition, story not found, or sprint-state.sh failure

set -euo pipefail
LC_ALL=C
export LC_ALL

SCRIPT_NAME="gaia-dev-story/sprint-state.sh"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_SCRIPTS_DIR="$(cd "$SCRIPT_DIR/../../../scripts" && pwd)"

SPRINT_STATE="$PLUGIN_SCRIPTS_DIR/sprint-state.sh"

log() { printf '%s: %s\n' "$SCRIPT_NAME" "$*" >&2; }
die() { log "$*"; exit 1; }

if [ $# -lt 2 ]; then
  die "usage: sprint-state.sh <get|transition> <story_key> [new_status]"
fi

SUBCOMMAND="$1"
STORY_KEY="$2"

if [ ! -x "$SPRINT_STATE" ]; then
  die "sprint-state.sh not found or not executable at $SPRINT_STATE"
fi

case "$SUBCOMMAND" in
  get)
    "$SPRINT_STATE" get --story "$STORY_KEY"
    ;;
  transition)
    if [ $# -lt 3 ]; then
      die "usage: sprint-state.sh transition <story_key> <new_status>"
    fi
    NEW_STATUS="$3"
    "$SPRINT_STATE" transition --story "$STORY_KEY" --to "$NEW_STATUS"
    ;;
  *)
    die "unknown subcommand: $SUBCOMMAND (expected: get, transition)"
    ;;
esac
