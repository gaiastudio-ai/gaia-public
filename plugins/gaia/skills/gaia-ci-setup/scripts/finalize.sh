#!/usr/bin/env bash
# finalize.sh — Cluster 11 gaia-ci-setup skill finalize (E28-S86, fixed E28-S199)
#
# Originally a mechanical copy of the Cluster 9 reference finalize.sh
# (E28-S66 gaia-code-review). E28-S197 triage (F3 / ContractBug) identified
# the unconditional `validate-gate.sh ci_setup_exists` invocation as
# tautological: this skill IS the producer of docs/test-artifacts/ci-setup.md,
# so a post-check on the producer's own output is (a) pointless on the
# success path, and (b) misleading on the failure path — if the setup body
# failed, the error should surface from setup, not from a downstream
# re-discovery of the absent file. On a fresh fixture (no prior run), the
# gate fails tautologically and masks real errors. E28-S199 removes the
# gate outright per the "preferred strategy" in the story Dev Notes.
#
# Responsibilities:
#   1. Write a checkpoint via the shared checkpoint.sh foundation script
#   2. Emit a lifecycle event via lifecycle-event.sh for the tailing sync agent
#
# The `validate-gate.sh ci_setup_exists` post-check previously performed
# here has been removed (E28-S199 / AC1, AC2, AC3). Genuine failures in
# the skill body are reported by the body itself, not by a tautological
# post-check.
#
# Exit codes:
#   0 — finalize succeeded
#   1 — checkpoint write or lifecycle event emission failed

set -euo pipefail
LC_ALL=C
export LC_ALL

SCRIPT_NAME="gaia-ci-setup/finalize.sh"
WORKFLOW_NAME="ci-setup"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_SCRIPTS_DIR="$(cd "$SCRIPT_DIR/../../../scripts" && pwd)"

CHECKPOINT="$PLUGIN_SCRIPTS_DIR/checkpoint.sh"
LIFECYCLE_EVENT="$PLUGIN_SCRIPTS_DIR/lifecycle-event.sh"

log() { printf '%s: %s\n' "$SCRIPT_NAME" "$*" >&2; }
die() { log "$*"; exit 1; }

# ---------- 1. Write checkpoint ----------
if [ -x "$CHECKPOINT" ]; then
  if ! "$CHECKPOINT" write --workflow "$WORKFLOW_NAME" --step 9 >/dev/null 2>&1; then
    die "checkpoint.sh write failed for $WORKFLOW_NAME"
  fi
  log "checkpoint written for $WORKFLOW_NAME"
else
  log "checkpoint.sh not found at $CHECKPOINT — skipping checkpoint write (non-fatal)"
fi

# ---------- 2. Emit lifecycle event ----------
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
