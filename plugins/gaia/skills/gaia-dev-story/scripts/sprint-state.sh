#!/usr/bin/env bash
# sprint-state.sh — gaia-dev-story sprint state wrapper (E28-S53, E38-S1)
#
# Thin wrapper around the shared sprint-state.sh foundation script.
# Provides story state machine transitions for dev-story's lifecycle:
#   backlog → in-progress → review → done
#
# Usage:
#   sprint-state.sh get <story_key>
#   sprint-state.sh transition <story_key> <new_status>
#   sprint-state.sh reconcile [--sprint-id <id>] [--dry-run]
#
# Exit codes:
#   0 — operation succeeded
#   1 — invalid transition, story not found, sprint-state.sh failure, or
#       reconcile error (missing story file, parse failure, write failure)
#   2 — reconcile --dry-run detected drift but wrote nothing
#
# Sync contract (ADR-055 §10.29.3):
#   The canonical implementation lives in
#     gaia-public/plugins/gaia/scripts/sprint-state.sh.
#   Any new subcommand must be forwarded through this wrapper in the same PR
#   so the dev-story skill bundle stays in step with the canonical copy.

set -euo pipefail
LC_ALL=C
export LC_ALL

SCRIPT_NAME="gaia-dev-story/sprint-state.sh"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_SCRIPTS_DIR="$(cd "$SCRIPT_DIR/../../../scripts" && pwd)"

SPRINT_STATE="$PLUGIN_SCRIPTS_DIR/sprint-state.sh"

log() { printf '%s: %s\n' "$SCRIPT_NAME" "$*" >&2; }
die() { log "$*"; exit 1; }

if [ $# -lt 1 ]; then
  die "usage: sprint-state.sh <get|transition|reconcile> [args...]"
fi

SUBCOMMAND="$1"
shift

if [ ! -x "$SPRINT_STATE" ]; then
  die "sprint-state.sh not found or not executable at $SPRINT_STATE"
fi

case "$SUBCOMMAND" in
  get)
    if [ $# -lt 1 ]; then
      die "usage: sprint-state.sh get <story_key>"
    fi
    "$SPRINT_STATE" get --story "$1"
    ;;
  transition)
    if [ $# -lt 2 ]; then
      die "usage: sprint-state.sh transition <story_key> <new_status>"
    fi
    "$SPRINT_STATE" transition --story "$1" --to "$2"
    ;;
  reconcile)
    # Pass-through to canonical script — preserve any trailing
    # --sprint-id <id> / --dry-run flags verbatim (E38-S1, ADR-055 §10.29.1).
    "$SPRINT_STATE" reconcile "$@"
    ;;
  *)
    die "unknown subcommand: $SUBCOMMAND (expected: get, transition, reconcile)"
    ;;
esac
