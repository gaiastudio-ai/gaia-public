#!/usr/bin/env bash
# update-story-status.sh — DEPRECATED wrapper (E54-S3).
#
# Forwards to the unified atomic transition script
#   plugins/gaia/scripts/transition-story-status.sh
# emitting a deprecation warning to stderr on every invocation.
#
# Removal target: a follow-up sweep story will migrate the remaining callers
# (sprint-plan, dev-story, fix-story, gaia-create-story Step 5/6) and then
# this wrapper will be deleted.
#
# Usage (legacy):
#   update-story-status.sh <story_key> <new_status>
#
# Forwarded as:
#   transition-story-status.sh <story_key> --to <new_status>
#
# Refs: E54-S3, AF-2026-04-28-3, FR-338, NFR-056.

set -euo pipefail
LC_ALL=C
export LC_ALL

SCRIPT_NAME="gaia-create-story/update-story-status.sh"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_SCRIPTS_DIR="$(cd "$SCRIPT_DIR/../../../scripts" && pwd)"

TRANSITION="$PLUGIN_SCRIPTS_DIR/transition-story-status.sh"

log() { printf '%s: %s\n' "$SCRIPT_NAME" "$*" >&2; }
die() { log "$*"; exit 1; }

if [ $# -lt 2 ]; then
  die "usage: update-story-status.sh <story_key> <new_status>"
fi

STORY_KEY="$1"
NEW_STATUS="$2"

if [ ! -x "$TRANSITION" ]; then
  die "transition-story-status.sh not found or not executable at $TRANSITION"
fi

log "WARNING: update-story-status.sh is deprecated; use transition-story-status.sh ${STORY_KEY} --to ${NEW_STATUS}"

exec "$TRANSITION" "$STORY_KEY" --to "$NEW_STATUS"
