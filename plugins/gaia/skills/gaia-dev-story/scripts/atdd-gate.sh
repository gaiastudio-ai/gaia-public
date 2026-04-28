#!/usr/bin/env bash
# atdd-gate.sh — gaia-dev-story Step 2b ATDD gate (E55-S5)
#
# Purpose:
#   For high-risk stories, halt the dev-story workflow at Step 2b unless an
#   ATDD scenarios file exists under docs/test-artifacts/. For non-high-risk
#   stories, exit 0 unconditionally.
#
# Per FR-DSH-6 / ADR-073, the canonical glob set is:
#   docs/test-artifacts/atdd-{epic_key}*.md   — epic-level ATDD coverage
#   docs/test-artifacts/atdd-{story_key}*.md  — story-level ATDD coverage
# Either glob matching at least one file satisfies the gate.
#
# Field-name alias note: the canonical story template uses `risk:` in
# frontmatter. FR-DSH-6 / ADR-073 prose refers to `risk_level` — these are
# the same semantic field on the target story being processed by
# /gaia-dev-story. This script reads the canonical `risk:` line; if it is
# absent we also scan for `risk_level:` for forward compatibility.
#
# Usage:
#   atdd-gate.sh <story_key>
#
# Environment:
#   PROJECT_PATH — optional. Project root containing docs/. Defaults to the
#                  current working directory.
#
# Exit codes:
#   0 — gate passes (non-high risk, OR high-risk with at least one ATDD file)
#   1 — gate halts  (high-risk story with no matching ATDD file)
#   2 — usage error (missing story_key, missing story file, etc.)

set -euo pipefail
LC_ALL=C
export LC_ALL

SCRIPT_NAME="gaia-dev-story/atdd-gate.sh"

log() { printf '%s: %s\n' "$SCRIPT_NAME" "$*" >&2; }
die() { log "$*"; exit "${2:-2}"; }

if [ $# -lt 1 ]; then
  die "usage: atdd-gate.sh <story_key>" 2
fi

STORY_KEY="$1"

# Story-key shape guard (defense-in-depth — the harness already validates this
# under E55-S2's T-37 mitigation, but the gate is callable as a standalone
# script so we re-check here).
if ! printf '%s' "$STORY_KEY" | grep -Eq '^E[0-9]+-S[0-9]+$'; then
  die "invalid story_key: $STORY_KEY (expected ^E[0-9]+-S[0-9]+\$)" 2
fi

EPIC_KEY="${STORY_KEY%-S*}"

PROJECT_ROOT="${PROJECT_PATH:-$(pwd)}"
IMPL_DIR="$PROJECT_ROOT/docs/implementation-artifacts"
TEST_DIR="$PROJECT_ROOT/docs/test-artifacts"

# Locate the story file: docs/implementation-artifacts/{story_key}-*.md
shopt -s nullglob
STORY_MATCHES=( "$IMPL_DIR/${STORY_KEY}-"*.md )
shopt -u nullglob

if [ "${#STORY_MATCHES[@]}" -eq 0 ]; then
  die "story file not found: $IMPL_DIR/${STORY_KEY}-*.md" 2
fi

STORY_FILE="${STORY_MATCHES[0]}"

# Read the risk field from frontmatter. Accept `risk:` (canonical) or
# `risk_level:` (PRD/ADR longhand alias). Strip surrounding quotes and
# whitespace; lowercase the verdict.
extract_risk() {
  local file="$1"
  # Limit to the YAML frontmatter (between the first two `---` lines).
  awk '
    NR == 1 && /^---/ { in_fm = 1; next }
    in_fm && /^---/   { exit }
    in_fm             { print }
  ' "$file" \
    | grep -E '^(risk|risk_level):' \
    | head -1 \
    | sed -E 's/^[a-z_]+:[[:space:]]*//; s/^"//; s/"$//; s/^'"'"'//; s/'"'"'$//; s/[[:space:]]+$//' \
    | tr '[:upper:]' '[:lower:]'
}

RISK="$(extract_risk "$STORY_FILE" || true)"

# Non-high risk → pass unconditionally.
if [ "$RISK" != "high" ]; then
  log "risk=${RISK:-unset}; ATDD gate not enforced (high-risk only) — pass"
  exit 0
fi

# High risk → require at least one matching ATDD file.
shopt -s nullglob
ATDD_MATCHES=( "$TEST_DIR/atdd-${EPIC_KEY}"*.md "$TEST_DIR/atdd-${STORY_KEY}"*.md )
shopt -u nullglob

if [ "${#ATDD_MATCHES[@]}" -gt 0 ]; then
  log "risk=high; ATDD file present (${ATDD_MATCHES[0]}) — pass"
  exit 0
fi

log "HALT: high-risk story $STORY_KEY has no ATDD file."
log "      expected one of:"
log "        $TEST_DIR/atdd-${EPIC_KEY}*.md"
log "        $TEST_DIR/atdd-${STORY_KEY}*.md"
log "      run /gaia-atdd $STORY_KEY to generate the scenarios file before /gaia-dev-story."
exit 1
