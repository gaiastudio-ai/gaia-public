#!/usr/bin/env bash
# smoke-memory-loader.sh — manual smoke test harness for memory-loader.sh (E28-S13)
#
# One assertion per AC (AC1–AC6) plus the story spec test scenarios that are
# explicitly required by the DoD (#1, #3, #5, #7, #8, #9, #11). The full
# bats-core suite lands in E28-S17 — this is the TDD harness for E28-S13 only.
#
# Usage: bash plugins/gaia/scripts/tests/smoke-memory-loader.sh
# Exit 0 when all assertions pass, 1 on first aggregated failure.

set -uo pipefail
LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ML="$SCRIPT_DIR/memory-loader.sh"

TMP="$(mktemp -d)"
export MEMORY_PATH="$TMP/_memory"
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0

ok()   { printf "  ok  %s\n" "$1"; PASS=$((PASS + 1)); }
fail() { printf "  FAIL %s\n     %s\n" "$1" "$2"; FAIL=$((FAIL + 1)); }

reset() {
  rm -rf "$MEMORY_PATH"
  mkdir -p "$MEMORY_PATH"
}

# -----------------------------------------------------------------------------
echo "== AC1/S1: decision-log tier prints decision-log.md and exits 0 =="
reset
mkdir -p "$MEMORY_PATH/nate-sidecar"
printf 'DL-CONTENT-NATE\n' > "$MEMORY_PATH/nate-sidecar/decision-log.md"
out="$("$ML" nate decision-log 2>/dev/null)"; rc=$?
if [ "$rc" = "0" ]; then ok "S1 exit 0"; else fail "S1 exit 0" "rc=$rc"; fi
if [ "$out" = "DL-CONTENT-NATE" ]; then ok "S1 stdout == decision-log.md"; else fail "S1 stdout == decision-log.md" "got '$out'"; fi

# -----------------------------------------------------------------------------
echo "== AC1/S2: ground-truth tier prints ground-truth.md and exits 0 =="
reset
mkdir -p "$MEMORY_PATH/val-sidecar"
printf 'GT-CONTENT-VAL\n' > "$MEMORY_PATH/val-sidecar/ground-truth.md"
out="$("$ML" val ground-truth 2>/dev/null)"; rc=$?
if [ "$rc" = "0" ]; then ok "S2 exit 0"; else fail "S2 exit 0" "rc=$rc"; fi
if [ "$out" = "GT-CONTENT-VAL" ]; then ok "S2 stdout == ground-truth.md"; else fail "S2 stdout == ground-truth.md" "got '$out'"; fi

# -----------------------------------------------------------------------------
echo "== AC3/S3: all tier prints both with section headers =="
reset
mkdir -p "$MEMORY_PATH/val-sidecar"
printf 'GT-BODY\n' > "$MEMORY_PATH/val-sidecar/ground-truth.md"
printf 'DL-BODY\n' > "$MEMORY_PATH/val-sidecar/decision-log.md"
out="$("$ML" val all 2>/dev/null)"; rc=$?
if [ "$rc" = "0" ]; then ok "S3 exit 0"; else fail "S3 exit 0" "rc=$rc"; fi
if printf '%s' "$out" | grep -q '^## Ground Truth$'; then ok "S3 has '## Ground Truth'"; else fail "S3 has '## Ground Truth'" "$out"; fi
if printf '%s' "$out" | grep -q '^## Decision Log$'; then ok "S3 has '## Decision Log'"; else fail "S3 has '## Decision Log'" "$out"; fi
if printf '%s' "$out" | grep -q 'GT-BODY'; then ok "S3 has GT-BODY"; else fail "S3 has GT-BODY" "$out"; fi
if printf '%s' "$out" | grep -q 'DL-BODY'; then ok "S3 has DL-BODY"; else fail "S3 has DL-BODY" "$out"; fi

# -----------------------------------------------------------------------------
echo "== AC2/S4: config-resolved sidecar path overrides default =="
reset
mkdir -p "$MEMORY_PATH/sm-sidecar"
printf 'FROM-SM-SIDECAR\n' > "$MEMORY_PATH/sm-sidecar/decision-log.md"
# Also create default path with different content — must NOT be read
mkdir -p "$MEMORY_PATH/nate-sidecar"
printf 'FROM-NATE-SIDECAR\n' > "$MEMORY_PATH/nate-sidecar/decision-log.md"
cat > "$MEMORY_PATH/config.yaml" <<'EOF'
agents:
  nate:
    sidecar: "sm-sidecar"
  val:
    sidecar: "validator-sidecar"
archival:
  token_approximation: 4
EOF
out="$("$ML" nate decision-log 2>/dev/null)"; rc=$?
if [ "$rc" = "0" ]; then ok "S4 exit 0"; else fail "S4 exit 0" "rc=$rc"; fi
if [ "$out" = "FROM-SM-SIDECAR" ]; then
  ok "S4 used config-mapped sm-sidecar"
else
  fail "S4 used config-mapped sm-sidecar" "got '$out'"
fi

# -----------------------------------------------------------------------------
echo "== AC4/S5: missing sidecar dir → empty stdout, exit 0 =="
reset
out="$("$ML" ghost all 2>/dev/null)"; rc=$?
if [ "$rc" = "0" ]; then ok "S5 exit 0"; else fail "S5 exit 0" "rc=$rc"; fi
if [ -z "$out" ]; then ok "S5 empty stdout"; else fail "S5 empty stdout" "got '$out'"; fi

# -----------------------------------------------------------------------------
echo "== AC1/S7: invalid tier → exit 1, usage on stderr =="
reset
if "$ML" nate bogus >/dev/null 2>"$TMP/stderr.s7"; then
  fail "S7 invalid tier exits non-zero" "exited 0"
else
  ok "S7 invalid tier exits non-zero"
fi
if grep -qi "tier" "$TMP/stderr.s7"; then
  ok "S7 stderr mentions tier"
else
  fail "S7 stderr mentions tier" "$(cat "$TMP/stderr.s7")"
fi

# -----------------------------------------------------------------------------
echo "== AC5/S8: --max-tokens truncates to approx n * token_approximation chars =="
reset
mkdir -p "$MEMORY_PATH/nate-sidecar"
# Write ~1000 chars
python3 -c "print('x' * 1000, end='')" > "$MEMORY_PATH/nate-sidecar/decision-log.md"
# Without config.yaml, token_approximation defaults to 4 → 100 * 4 = 400
out="$("$ML" nate decision-log --max-tokens 100 2>/dev/null)"; rc=$?
if [ "$rc" = "0" ]; then ok "S8 exit 0"; else fail "S8 exit 0" "rc=$rc"; fi
len=${#out}
if [ "$len" -le 400 ]; then
  ok "S8 length ${len} <= 400"
else
  fail "S8 length <= 400" "got ${len}"
fi

# with config.yaml specifying token_approximation: 3 → 100 * 3 = 300
cat > "$MEMORY_PATH/config.yaml" <<'EOF'
archival:
  token_approximation: 3
EOF
out2="$("$ML" nate decision-log --max-tokens 100 2>/dev/null)"
len2=${#out2}
if [ "$len2" -le 300 ]; then
  ok "S8 config token_approximation respected (len=${len2} <= 300)"
else
  fail "S8 config token_approximation respected" "got ${len2}"
fi

# -----------------------------------------------------------------------------
echo "== AC6/S9: --format inline wraps output in fenced code block =="
reset
mkdir -p "$MEMORY_PATH/nate-sidecar"
printf 'INLINE-CONTENT\n' > "$MEMORY_PATH/nate-sidecar/decision-log.md"
out="$("$ML" nate decision-log --format inline 2>/dev/null)"; rc=$?
if [ "$rc" = "0" ]; then ok "S9 exit 0"; else fail "S9 exit 0" "rc=$rc"; fi
first_line="$(printf '%s\n' "$out" | sed -n '1p')"
last_line="$(printf '%s\n' "$out" | awk 'NF{l=$0} END{print l}')"
if [ "$first_line" = '```' ]; then ok "S9 starts with fence"; else fail "S9 starts with fence" "first='$first_line'"; fi
if [ "$last_line" = '```' ]; then ok "S9 ends with fence"; else fail "S9 ends with fence" "last='$last_line'"; fi
if printf '%s' "$out" | grep -q 'INLINE-CONTENT'; then
  ok "S9 content present inside fence"
else
  fail "S9 content present inside fence" "$out"
fi

# -----------------------------------------------------------------------------
echo "== S10: --help prints usage and exits 0 =="
if out=$("$ML" --help 2>&1); then
  ok "S10 --help exit 0"
else
  fail "S10 --help exit 0" "non-zero exit"
fi
if printf '%s' "$out" | grep -qi "usage"; then
  ok "S10 --help prints usage"
else
  fail "S10 --help prints usage" "no 'usage' in output"
fi

# -----------------------------------------------------------------------------
echo "== AC3/S6: partial sidecar — only decision-log, tier=all =="
reset
mkdir -p "$MEMORY_PATH/partial-sidecar"
printf 'ONLY-DL\n' > "$MEMORY_PATH/partial-sidecar/decision-log.md"
out="$("$ML" partial all 2>/dev/null)"; rc=$?
if [ "$rc" = "0" ]; then ok "S6 exit 0"; else fail "S6 exit 0" "rc=$rc"; fi
if printf '%s' "$out" | grep -q 'ONLY-DL'; then
  ok "S6 decision-log content present"
else
  fail "S6 decision-log content present" "$out"
fi
if printf '%s' "$out" | grep -q '^## Decision Log$'; then
  ok "S6 decision-log header present"
else
  fail "S6 decision-log header present" "$out"
fi

# -----------------------------------------------------------------------------
echo "== NFR-048/S11: performance — single invocation under 1s (target 50ms) =="
reset
mkdir -p "$MEMORY_PATH/nate-sidecar"
printf 'perf-content\n' > "$MEMORY_PATH/nate-sidecar/decision-log.md"
start_ms=$(python3 -c 'import time; print(int(time.time()*1000))')
"$ML" nate decision-log >/dev/null 2>&1
end_ms=$(python3 -c 'import time; print(int(time.time()*1000))')
elapsed=$((end_ms - start_ms))
if [ "$elapsed" -lt 1000 ]; then
  ok "S11 elapsed ${elapsed}ms < 1000ms smoke budget"
else
  fail "S11 elapsed" "${elapsed}ms >= 1000ms"
fi

# -----------------------------------------------------------------------------
echo "== Missing positional args → exit 1 =="
if "$ML" 2>/dev/null; then
  fail "missing args exit != 0" "exited 0"
else
  ok "missing args exit != 0"
fi

# -----------------------------------------------------------------------------
echo
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
