#!/usr/bin/env bash
# setup.sh — Cluster 6 readiness-check skill setup (E28-S48, brief §Cluster 6 / P6-S4)
#
# Mechanical extension of the Cluster 4 reference implementation authored
# under E28-S35 (gaia-brainstorm/scripts/setup.sh). Adds readiness-check-specific
# prereq gates:
#   - traceability-matrix.md must exist (validate-gate traceability_exists)
#   - ci-setup.md must exist (validate-gate ci_setup_exists)
#
# Both gates are MANDATORY per ADR-042 — there is no "single gate" fallback,
# no env-var bypass, and no flag to make either gate optional. Partial-pass
# is a bug.
#
# Responsibilities (per brief §Cluster 4):
#   1. Resolve config via the shared resolve-config.sh foundation script
#   2. Run validate-gate.sh for both prereqs (traceability + ci-setup)
#   3. Load the checkpoint state for this workflow
#
# Exit codes:
#   0 — setup succeeded, skill body can run
#   1 — config resolution, gate validation, or checkpoint load failed
#
# POSIX discipline: bash with [[ ]] and indexed arrays only. LC_ALL=C for
# deterministic output. macOS /bin/bash 3.2 compatible.

set -euo pipefail
LC_ALL=C
export LC_ALL

SCRIPT_NAME="gaia-readiness-check/setup.sh"
WORKFLOW_NAME="implementation-readiness"

# Resolve the GAIA plugin scripts directory from this script's location:
#   skills/gaia-readiness-check/scripts/setup.sh → ../../../scripts
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Allow override for testing
if [ -n "${PLUGIN_SCRIPTS_DIR:-}" ]; then
  : # use the override
else
  PLUGIN_SCRIPTS_DIR="$(cd "$SCRIPT_DIR/../../../scripts" && pwd)"
fi

RESOLVE_CONFIG="$PLUGIN_SCRIPTS_DIR/resolve-config.sh"
VALIDATE_GATE="$PLUGIN_SCRIPTS_DIR/validate-gate.sh"
CHECKPOINT="$PLUGIN_SCRIPTS_DIR/checkpoint.sh"

log() { printf '%s: %s\n' "$SCRIPT_NAME" "$*" >&2; }
die() { log "$*"; exit 1; }

# ---------- 1. Resolve config ----------
if [ -x "$RESOLVE_CONFIG" ]; then
  if ! config_output=$("$RESOLVE_CONFIG" 2>&1); then
    log "resolve-config.sh failed:"
    printf '%s\n' "$config_output" >&2
    exit 1
  fi
  # Export every KEY='VALUE' line the resolver emits so downstream tools
  # (validate-gate.sh, checkpoint.sh) pick them up from the environment.
  while IFS= read -r line; do
    case "$line" in
      [A-Z_]*=*) eval "export $line" ;;
    esac
  done <<<"$config_output"
else
  log "resolve-config.sh not found at $RESOLVE_CONFIG — using environment defaults"
fi

# ---------- 2. Validate gates (prereqs) — BOTH mandatory per ADR-042 ----------
# The readiness-check skill requires BOTH traceability-matrix.md AND ci-setup.md
# to exist. Neither gate is optional. Neither can be skipped via flag.
# We use --multi to evaluate both in order; validate-gate.sh fails fast on the
# first missing artifact with a clear gate-specific error message.
if [ -x "$VALIDATE_GATE" ]; then
  if ! "$VALIDATE_GATE" --multi "traceability_exists,ci_setup_exists" 2>&1; then
    die "Quality gate failed for $WORKFLOW_NAME — required artifact(s) missing. Run /gaia-trace and/or /gaia-ci-setup to generate the missing artifact(s)."
  fi
else
  die "validate-gate.sh not found at $VALIDATE_GATE — cannot enforce mandatory gates"
fi

# ---------- 3. Load checkpoint state ----------
if [ -x "$CHECKPOINT" ]; then
  # `checkpoint.sh read` exits 2 when no checkpoint exists (fresh run) —
  # that is a valid state for the first invocation of a skill. Any other
  # non-zero exit indicates a real error.
  if "$CHECKPOINT" read --workflow "$WORKFLOW_NAME" >/dev/null 2>&1; then
    log "checkpoint loaded for $WORKFLOW_NAME"
  else
    rc=$?
    if [ "$rc" -eq 2 ]; then
      log "no prior checkpoint for $WORKFLOW_NAME — fresh run"
    else
      die "checkpoint.sh read failed with exit $rc"
    fi
  fi
else
  log "checkpoint.sh not found at $CHECKPOINT — skipping checkpoint load (non-fatal)"
fi

log "setup complete for $WORKFLOW_NAME"
exit 0
