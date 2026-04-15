#!/usr/bin/env bash
# smoke-lifecycle-event.sh — manual smoke test harness for lifecycle-event.sh (E28-S12)
#
# One assertion (or set) per AC (AC1–AC7) plus the 10 test scenarios from
# the story spec. The full bats-core suite lands in E28-S17 — this is the TDD
# harness that drives the RED → GREEN cycle for E28-S12 only.
#
# Usage: bash plugins/gaia/scripts/tests/smoke-lifecycle-event.sh
# Exit 0 when all assertions pass, 1 on first aggregated failure.

set -uo pipefail
LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
EVT="$SCRIPT_DIR/lifecycle-event.sh"

TMP="$(mktemp -d)"
export MEMORY_PATH="$TMP/_memory"
JSONL="$MEMORY_PATH/lifecycle-events.jsonl"
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0

ok()   { printf "  ok  %s\n" "$1"; PASS=$((PASS + 1)); }
fail() { printf "  FAIL %s\n     %s\n" "$1" "$2"; FAIL=$((FAIL + 1)); }

reset_jsonl() {
  rm -rf "$MEMORY_PATH"
}

# -----------------------------------------------------------------------------
echo "== AC1/S1: happy path — minimal event appends one line and exits 0 =="
reset_jsonl
if "$EVT" --type step_complete --workflow create-story >/dev/null 2>&1; then
  ok "S1 exit 0"
else
  fail "S1 exit 0" "script did not exit 0"
fi
if [ -f "$JSONL" ]; then ok "S1 JSONL created"; else fail "S1 JSONL created" "$JSONL missing"; fi
lines=$(wc -l < "$JSONL" 2>/dev/null | tr -d ' ')
if [ "$lines" = "1" ]; then ok "S1 exactly one line"; else fail "S1 exactly one line" "got $lines lines"; fi
if jq -e . "$JSONL" >/dev/null 2>&1; then ok "S1 valid JSON"; else fail "S1 valid JSON" "jq rejected line"; fi

# -----------------------------------------------------------------------------
echo "== AC2/S2: full-field event includes story_key, step, data =="
reset_jsonl
"$EVT" --type gate_failed --workflow dev-story --story E1-S1 --step 7 --data '{"gate":"lint"}' >/dev/null 2>&1 || true
if [ -f "$JSONL" ]; then
  line="$(tail -1 "$JSONL")"
  if echo "$line" | jq -e '.timestamp and .event_type == "gate_failed" and .workflow == "dev-story" and .pid' >/dev/null 2>&1; then
    ok "S2 required fields present"
  else
    fail "S2 required fields present" "$line"
  fi
  if echo "$line" | jq -e '.story_key == "E1-S1" and .step == 7 and .data.gate == "lint"' >/dev/null 2>&1; then
    ok "S2 optional fields present"
  else
    fail "S2 optional fields present" "$line"
  fi
  # AC2: ISO 8601 UTC with millisecond precision — "...T...:...:...Z"
  if echo "$line" | jq -r .timestamp | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3}Z$'; then
    ok "S2 timestamp ISO8601 ms UTC"
  else
    fail "S2 timestamp ISO8601 ms UTC" "$(echo "$line" | jq -r .timestamp)"
  fi
else
  fail "S2 required fields present" "JSONL missing"
fi

# -----------------------------------------------------------------------------
echo "== AC3/S3: 10 concurrent writes — no interleaving =="
reset_jsonl
# Fire 10 parallel writers via xargs -P 10
seq 1 10 | xargs -P 10 -I {} "$EVT" --type concurrent_test --workflow cw --step {} >/dev/null 2>&1
n=$(wc -l < "$JSONL" 2>/dev/null | tr -d ' ')
if [ "$n" = "10" ]; then ok "S3 exactly 10 lines"; else fail "S3 exactly 10 lines" "got $n"; fi
# Every line must parse as JSON (no interleaving)
bad=0
while IFS= read -r l; do
  [ -z "$l" ] && continue
  if ! printf '%s' "$l" | jq -e . >/dev/null 2>&1; then
    bad=$((bad + 1))
  fi
done < "$JSONL"
if [ "$bad" = "0" ]; then ok "S3 all lines parse (no interleaving)"; else fail "S3 all lines parse" "$bad bad lines"; fi

# -----------------------------------------------------------------------------
echo "== AC4/S4+S5: event-types file rejects unknown, accepts known =="
reset_jsonl
TYPES_FILE="$TMP/types.txt"
cat > "$TYPES_FILE" <<'EOF'
# allowed types
step_complete
gate_failed
EOF
# S4: reject
if "$EVT" --type bogus --workflow x --event-types-file "$TYPES_FILE" >/dev/null 2>"$TMP/stderr.s4"; then
  fail "S4 reject unknown" "expected non-zero exit"
else
  ok "S4 reject unknown exit != 0"
fi
if grep -q "bogus" "$TMP/stderr.s4" 2>/dev/null && grep -q "types.txt" "$TMP/stderr.s4" 2>/dev/null; then
  ok "S4 stderr names type and file"
else
  fail "S4 stderr names type and file" "$(cat "$TMP/stderr.s4" 2>/dev/null)"
fi
if [ ! -s "$JSONL" ]; then ok "S4 no append on reject"; else fail "S4 no append on reject" "JSONL has $(wc -l < "$JSONL") lines"; fi

# S5: accept
reset_jsonl
if "$EVT" --type step_complete --workflow x --event-types-file "$TYPES_FILE" >/dev/null 2>&1; then
  ok "S5 accept known exit 0"
else
  fail "S5 accept known exit 0" "non-zero exit"
fi
if [ -s "$JSONL" ]; then ok "S5 append on accept"; else fail "S5 append on accept" "JSONL empty"; fi

# -----------------------------------------------------------------------------
echo "== AC7/S6: malformed --data is rejected, no partial append =="
reset_jsonl
if "$EVT" --type step_complete --workflow x --data 'not-json' >/dev/null 2>"$TMP/stderr.s6"; then
  fail "S6 reject malformed data" "expected non-zero exit"
else
  ok "S6 reject malformed data exit != 0"
fi
if [ -s "$TMP/stderr.s6" ]; then ok "S6 stderr message"; else fail "S6 stderr message" "empty stderr"; fi
# No partial line written
if [ ! -s "$JSONL" ]; then ok "S6 no partial append"; else fail "S6 no partial append" "JSONL not empty"; fi

# -----------------------------------------------------------------------------
echo "== AC6/S7: missing JSONL file is created with 0644 =="
reset_jsonl
"$EVT" --type step_complete --workflow create-story >/dev/null 2>&1
if [ -f "$JSONL" ]; then ok "S7 JSONL created"; else fail "S7 JSONL created" "missing"; fi
mode=""
if stat -f %Lp "$JSONL" >/dev/null 2>&1; then
  mode=$(stat -f %Lp "$JSONL")
elif stat -c %a "$JSONL" >/dev/null 2>&1; then
  mode=$(stat -c %a "$JSONL")
fi
if [ "$mode" = "644" ]; then ok "S7 mode 0644"; else fail "S7 mode 0644" "got $mode"; fi

# -----------------------------------------------------------------------------
echo "== S8: missing required flags — no --type =="
reset_jsonl
if "$EVT" --workflow create-story >/dev/null 2>"$TMP/stderr.s8"; then
  fail "S8 exit != 0 on missing --type" "expected non-zero"
else
  ok "S8 exit != 0 on missing --type"
fi
if grep -qi "type" "$TMP/stderr.s8" 2>/dev/null; then
  ok "S8 usage/error on stderr mentions type"
else
  fail "S8 usage/error on stderr mentions type" "$(cat "$TMP/stderr.s8" 2>/dev/null)"
fi

# -----------------------------------------------------------------------------
echo "== AC5/S9: performance — single invocation under 1s (budget is 50ms) =="
reset_jsonl
# Measure with /usr/bin/time if available; else date math. Budget 1000ms wall to
# keep the smoke suite tolerant on slow CI; the 50ms NFR target is documented in
# the script header and will be asserted properly in E28-S17 bats-core.
start_ms=$(python3 -c 'import time; print(int(time.time()*1000))')
"$EVT" --type step_complete --workflow perf >/dev/null 2>&1
end_ms=$(python3 -c 'import time; print(int(time.time()*1000))')
elapsed=$((end_ms - start_ms))
if [ "$elapsed" -lt 1000 ]; then
  ok "S9 elapsed ${elapsed}ms < 1000ms smoke budget"
else
  fail "S9 elapsed" "${elapsed}ms >= 1000ms"
fi

# -----------------------------------------------------------------------------
echo "== S10: --help prints usage and exits 0 =="
if out=$("$EVT" --help 2>&1); then
  ok "S10 --help exit 0"
else
  fail "S10 --help exit 0" "non-zero exit"
fi
if echo "${out:-}" | grep -qi "usage"; then
  ok "S10 --help prints usage"
else
  fail "S10 --help prints usage" "no 'usage' in output"
fi

# -----------------------------------------------------------------------------
echo
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
