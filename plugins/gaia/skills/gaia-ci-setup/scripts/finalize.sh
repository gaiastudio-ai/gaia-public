#!/usr/bin/env bash
# finalize.sh — Cluster 11 gaia-ci-setup skill finalize (E28-S86)
#
# Mechanical copy of the Cluster 9 reference implementation authored under
# E28-S66 (gaia-code-review/scripts/finalize.sh). Only WORKFLOW_NAME and
# SCRIPT_NAME differ — the body is byte-identical to the reference.
#
# Responsibilities (per brief Cluster 9):
#   1. Invoke validate-gate.sh for post-setup CI gate verification (AC3)
#   2. Write a checkpoint via the shared checkpoint.sh foundation script
#   3. Emit a lifecycle event via lifecycle-event.sh for the tailing sync agent
#
# Exit codes:
#   0 — finalize succeeded
#   1 — gate validation, checkpoint write, or lifecycle event emission failed

set -euo pipefail
LC_ALL=C
export LC_ALL

SCRIPT_NAME="gaia-ci-setup/finalize.sh"
WORKFLOW_NAME="ci-setup"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_SCRIPTS_DIR="$(cd "$SCRIPT_DIR/../../../scripts" && pwd)"

VALIDATE_GATE="$PLUGIN_SCRIPTS_DIR/validate-gate.sh"
CHECKPOINT="$PLUGIN_SCRIPTS_DIR/checkpoint.sh"
LIFECYCLE_EVENT="$PLUGIN_SCRIPTS_DIR/lifecycle-event.sh"

log() { printf '%s: %s\n' "$SCRIPT_NAME" "$*" >&2; }
die() { log "$*"; exit 1; }

# ---------- 1. Post-setup gate verification via validate-gate.sh (AC3) ----------
if [ -x "$VALIDATE_GATE" ]; then
  if ! "$VALIDATE_GATE" ci_setup_exists 2>&1; then
    die "validate-gate.sh: ci_setup_exists gate failed — CI setup output not found"
  fi
  log "validate-gate.sh: ci_setup_exists gate passed"
else
  die "validate-gate.sh not found at $VALIDATE_GATE — cannot verify CI gate (E28-S15 dependency)"
fi

# ---------- 2. Write checkpoint ----------
if [ -x "$CHECKPOINT" ]; then
  if ! "$CHECKPOINT" write --workflow "$WORKFLOW_NAME" --step 9 >/dev/null 2>&1; then
    die "checkpoint.sh write failed for $WORKFLOW_NAME"
  fi
  log "checkpoint written for $WORKFLOW_NAME"
else
  log "checkpoint.sh not found at $CHECKPOINT — skipping checkpoint write (non-fatal)"
fi

# ---------- 3. Emit lifecycle event ----------
if [ -x "$LIFECYCLE_EVENT" ]; then
  if ! "$LIFECYCLE_EVENT" --type workflow_complete --workflow "$WORKFLOW_NAME" >/dev/null 2>&1; then
    die "lifecycle-event.sh emit failed for $WORKFLOW_NAME"
  fi
  log "lifecycle event emitted for $WORKFLOW_NAME"
else
  log "lifecycle-event.sh not found at $LIFECYCLE_EVENT — skipping event emission (non-fatal)"
fi

log "finalize complete for $WORKFLOW_NAME"
exit 0
