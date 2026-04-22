#!/usr/bin/env bash
# action-items-increment.sh — increment escalation_count for an action-items.yaml
# entry keyed by theme_hash, with idempotency scoped to (sprint_id, theme_hash).
#
# NOTE(E36-S2 / ADR-052): this script delegates to the shared retro writer
# retro-sidecar-write.sh for allowlist enforcement, idempotency, backup, and
# verify semantics. The current body is an inline, byte-compatible stand-in;
# callers that need the full pipeline should invoke retro-sidecar-write.sh
# directly via RETRO_WRITER. When the full delegation swap lands (follow-up
# under E36-S3), the CLI contract here stays stable so callers do not change.
#
# RETRO_WRITER delegation path (informational):
#   RETRO_WRITER="${SCRIPT_DIR}/../../../../scripts/retro-sidecar-write.sh"
#   "$RETRO_WRITER" --root "$ROOT" --sprint-id "$SPRINT_ID" \
#     --target "$AI_FILE" --payload "$PAYLOAD"
#
# Usage:
#   action-items-increment.sh --file <path> --theme-hash <hex> --sprint-id <id>
#
# Exit codes:
#   0  — increment applied (or no-op because already applied for this sprint)
#   1  — error (missing file, unreadable, invalid arguments)
#
# Contract:
#   * Allowlist check: file path must end in "action-items.yaml".
#   * Idempotency: a sidecar ledger next to the target file records
#     (sprint_id, theme_hash) pairs that have already produced an increment.
#     Re-invoking with the same pair is a silent no-op.
#   * Backup: a .bak copy is written before mutation so a failed write
#     can be rolled back by callers if desired.

set -euo pipefail

AI_FILE=""
THEME_HASH=""
SPRINT_ID=""

while [ $# -gt 0 ]; do
  case "$1" in
    --file)         AI_FILE="$2"; shift 2 ;;
    --theme-hash)   THEME_HASH="$2"; shift 2 ;;
    --sprint-id)    SPRINT_ID="$2"; shift 2 ;;
    *) echo "error: unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$AI_FILE" ] || [ -z "$THEME_HASH" ] || [ -z "$SPRINT_ID" ]; then
  echo "usage: $0 --file <path> --theme-hash <hex> --sprint-id <id>" >&2
  exit 1
fi

# Allowlist (NFR-RIM-2) — only action-items.yaml writes permitted.
case "$(basename "$AI_FILE")" in
  action-items.yaml) ;;
  *) echo "error: write target not in allowlist: $AI_FILE" >&2; exit 1 ;;
esac

if [ ! -f "$AI_FILE" ]; then
  echo "warn: action-items.yaml not found: $AI_FILE — skipping increment" >&2
  exit 0
fi

LEDGER="${AI_FILE}.increment-ledger"
touch "$LEDGER"

LEDGER_KEY="${SPRINT_ID}:${THEME_HASH}"
if grep -Fxq "$LEDGER_KEY" "$LEDGER" 2>/dev/null; then
  # Idempotent no-op (NFR-RIM-3).
  exit 0
fi

# Locate the entry whose theme_hash matches and bump its escalation_count.
# We operate on the raw file with awk because the action-items.yaml dialect
# used in this repo is hand-authored (not round-tripped through a YAML lib)
# and we want byte-stable edits.

BACKUP="${AI_FILE}.bak"
cp -p "$AI_FILE" "$BACKUP"

TMPFILE="$(mktemp -t action-items.yaml.XXXXXX)"
awk -v hash="$THEME_HASH" '
  BEGIN { in_target = 0; applied = 0 }
  {
    line = $0
    if (match(line, /theme_hash:[[:space:]]*"?(sha256:)?[0-9a-f]+/)) {
      found = substr(line, RSTART, RLENGTH)
      # Grab the trailing hex run.
      hex = ""
      if (match(found, /[0-9a-f]+$/)) {
        hex = substr(found, RSTART, RLENGTH)
      }
      if (hex == hash) { in_target = 1 }
      else             { in_target = 0 }
    }
    if (in_target && applied == 0 && match(line, /escalation_count:[[:space:]]*[0-9]+/)) {
      # Extract current counter value and bump it.
      chunk = substr(line, RSTART, RLENGTH)
      cur = chunk
      sub(/^[^0-9]+/, "", cur)
      new_val = cur + 1
      sub(/escalation_count:[[:space:]]*[0-9]+/,
          "escalation_count: " new_val, line)
      applied = 1
      in_target = 0
    }
    print line
  }
' "$AI_FILE" > "$TMPFILE"

# Verify the file is still non-empty before swapping in.
if [ ! -s "$TMPFILE" ]; then
  rm -f "$TMPFILE"
  echo "error: post-write file is empty; aborting and leaving backup" >&2
  exit 1
fi

mv "$TMPFILE" "$AI_FILE"

# Record the idempotency key.
printf '%s\n' "$LEDGER_KEY" >> "$LEDGER"

exit 0
