#!/usr/bin/env bash
# finalize.sh — /gaia-atdd skill finalize (E28-S83 + E42-S15)
#
# E42-S15 extends the bare-bones Cluster 4 finalize scaffolding with a
# 5-item post-completion checklist (1 script-verifiable + 4
# LLM-checkable) derived from the V1 atdd checklist (see the
# docs/v1-v2-command-gap-analysis.md entry for the verbatim V1 source).
# See docs/implementation-artifacts/E42-S15-* for the V1 → V2 mapping.
#
# Responsibilities (per brief §Cluster 4 + story E42-S15):
#   1. Run the script-verifiable subset of the 5 V1 checklist items
#      against the atdd-{story_key}.md artifact. Validation runs FIRST.
#   2. Emit an LLM-checkable payload listing the semantic-judgment items.
#   3. Write a checkpoint via the shared checkpoint.sh helper.
#   4. Emit a lifecycle event via lifecycle-event.sh.
#
# The observability side effects (3 + 4) MUST run on every invocation —
# the checklist outcome never suppresses the checkpoint/event write
# (matches E42-S1..S14 contract; story AC6).
#
# Exit codes:
#   0 — finalize succeeded; the script-verifiable item PASSes (or
#       no artifact was requested — classic Cluster 4 behaviour).
#   1 — the script-verifiable checklist item FAILs; the AC4
#       "no artifact to validate" violation; or a
#       checkpoint/lifecycle-event failure. Failed item names are
#       listed on stderr under a "Checklist violations:" header
#       followed by a one-line remediation hint.
#
# Environment:
#   ATDD_ARTIFACT  Absolute path to the atdd-{story_key}.md artifact
#                  to validate. When set, the script runs the 5-item
#                  checklist against it. When set but the file does
#                  not exist or is empty, AC4 fires — a single
#                  "no artifact to validate" violation is emitted
#                  and the script exits non-zero. When unset, the
#                  script skips the checklist (classic Cluster 4
#                  behaviour — observability still runs, exit 0).

set -euo pipefail
LC_ALL=C
export LC_ALL

SCRIPT_NAME="gaia-atdd/finalize.sh"
WORKFLOW_NAME="atdd"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_SCRIPTS_DIR="$(cd "$SCRIPT_DIR/../../../scripts" && pwd)"

CHECKPOINT="$PLUGIN_SCRIPTS_DIR/checkpoint.sh"
LIFECYCLE_EVENT="$PLUGIN_SCRIPTS_DIR/lifecycle-event.sh"

log() { printf '%s: %s\n' "$SCRIPT_NAME" "$*" >&2; }
die() { log "$*"; exit 1; }

# ---------- 0. Resolve artifact paths ----------
# ATDD_ARTIFACT wins when set (test fixtures + explicit invocation).
# The checklist only runs when it is EXPLICITLY set.
ARTIFACT=""
ARTIFACT_REQUESTED=0
if [ -n "${ATDD_ARTIFACT:-}" ]; then
  ARTIFACT_REQUESTED=1
  ARTIFACT="$ATDD_ARTIFACT"
fi

# ---------- 1. Run the 5-item checklist ----------
VIOLATIONS=()
CHECKED=0
PASSED=0
CHECKLIST_STATUS=0

# item_check <id> <description> <boolean-result>
item_check() {
  local id="$1" desc="$2" result="$3"
  CHECKED=$((CHECKED + 1))
  if [ "$result" = "pass" ]; then
    printf '  [PASS] %s — %s [skill: atdd]\n' "$id" "$desc" >&2
    PASSED=$((PASSED + 1))
  else
    printf '  [FAIL] %s — %s [skill: atdd]\n' "$id" "$desc" >&2
    VIOLATIONS+=("$id — $desc")
  fi
}

heading_present() {
  local f="$1" text="$2"
  if grep -Eiq "^##[[:space:]]+${text}([[:space:]]|\$|[[:punct:]])" "$f" 2>/dev/null; then
    echo "pass"
  else
    echo "fail"
  fi
}

# ac_to_test_table_present <file>
# Pass when an "AC-to-Test Mapping" (or "Traceability") H2 heading exists
# AND a markdown table row references an AC identifier (AC1, AC-EC1, etc.).
ac_to_test_table_present() {
  local f="$1"
  if [ "$(heading_present "$f" "(AC-to-Test[[:space:]]+Mapping|Traceability|AC[[:space:]]+to[[:space:]]+Test)")" = "pass" ] \
    && grep -Eq '^\|[[:space:]]*AC[-A-Z0-9]+' "$f" 2>/dev/null; then
    echo "pass"
  else
    echo "fail"
  fi
}

if [ "$ARTIFACT_REQUESTED" -eq 1 ] && { [ ! -f "$ARTIFACT" ] || [ ! -s "$ARTIFACT" ]; }; then
  # AC4 — Caller explicitly pointed at an artifact path but it does
  # not exist on disk or is empty (0 bytes).
  log "no artifact to validate at $ARTIFACT"
  printf '\nChecklist violations:\n' >&2
  printf '  - no artifact to validate (expected %s)\n' "$ARTIFACT" >&2
  printf 'Remediation: rerun /gaia-atdd to produce docs/test-artifacts/atdd-{story_key}.md, then rerun finalize.sh.\n' >&2
  CHECKLIST_STATUS=1
elif [ -n "$ARTIFACT" ] && [ -f "$ARTIFACT" ] && [ -s "$ARTIFACT" ]; then
  log "running 5-item checklist against $ARTIFACT"
  printf '\nChecklist: /gaia-atdd (5 items — 1 script-verifiable, 4 LLM-checkable)\n' >&2

  # --- Script-verifiable items (1) ---

  # SV-01 / V1 "Test-to-AC traceability documented"
  item_check "SV-01" "Test-to-AC traceability documented" \
    "$(ac_to_test_table_present "$ARTIFACT")"

  # --- LLM-checkable items (4) ---
  printf '\n[LLM-CHECK] The following 4 items require semantic review by the host LLM:\n' >&2
  cat >&2 <<'EOF'
  LLM-01 — Acceptance criteria loaded from story/PRD
  LLM-02 — Each AC mapped to exactly one test
  LLM-03 — Tests fail initially (red phase)
  LLM-04 — Tests are atomic and independent
EOF

  TOTAL_ITEMS=5
  LLM_ITEMS=4
  printf '\nChecklist summary: %d/%d script-verifiable items PASS; %d LLM-checkable items deferred to host review. Total items: %d.\n' \
    "$PASSED" "$CHECKED" "$LLM_ITEMS" "$TOTAL_ITEMS" >&2

  if [ "${#VIOLATIONS[@]}" -gt 0 ]; then
    printf '\nChecklist violations:\n' >&2
    for v in "${VIOLATIONS[@]}"; do
      printf '  - %s\n' "$v" >&2
    done
    printf 'Remediation: amend the atdd artifact to satisfy the failed items, then rerun /gaia-atdd.\n' >&2
    CHECKLIST_STATUS=1
  else
    printf 'Checklist: all %d script-verifiable items PASS.\n' "$PASSED" >&2
    CHECKLIST_STATUS=0
  fi
else
  log "no atdd artifact requested (ATDD_ARTIFACT unset) — skipping checklist run"
  CHECKLIST_STATUS=0
fi

# ---------- 2. Write checkpoint (observability — never suppressed) ----------
if [ -x "$CHECKPOINT" ]; then
  if ! "$CHECKPOINT" write --workflow "$WORKFLOW_NAME" --step 5 >/dev/null 2>&1; then
    die "checkpoint.sh write failed for $WORKFLOW_NAME"
  fi
  log "checkpoint written for $WORKFLOW_NAME"
else
  log "checkpoint.sh not found at $CHECKPOINT — skipping checkpoint write (non-fatal)"
fi

# ---------- 3. Emit lifecycle event (observability — never suppressed) ----------
if [ -x "$LIFECYCLE_EVENT" ]; then
  if ! "$LIFECYCLE_EVENT" --type workflow_complete --workflow "$WORKFLOW_NAME" >/dev/null 2>&1; then
    die "lifecycle-event.sh emit failed for $WORKFLOW_NAME"
  fi
  log "lifecycle event emitted for $WORKFLOW_NAME"
else
  log "lifecycle-event.sh not found at $LIFECYCLE_EVENT — skipping event emission (non-fatal)"
fi

log "finalize complete for $WORKFLOW_NAME"
exit "$CHECKLIST_STATUS"
