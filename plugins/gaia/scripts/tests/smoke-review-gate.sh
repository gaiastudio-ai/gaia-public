#!/usr/bin/env bash
# smoke-review-gate.sh — smoke test harness for review-gate.sh (E28-S99)
#
# Validates that review-gate.sh uses the canonical flat story file path
# (docs/implementation-artifacts/<key>-*.md) rather than the incorrect
# nested path (docs/implementation-artifacts/stories/<key>-*.md).
#
# Also tests core subcommands: check, update, status.
#
# Usage: bash plugins/gaia/scripts/tests/smoke-review-gate.sh
# Exit 0 when all assertions pass, 1 on first aggregated failure.

set -uo pipefail
LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RG="$SCRIPT_DIR/review-gate.sh"

TMP="$(mktemp -d)"
export PROJECT_PATH="$TMP"
export IMPLEMENTATION_ARTIFACTS="$TMP/docs/implementation-artifacts"
ART="$IMPLEMENTATION_ARTIFACTS"
mkdir -p "$ART"
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0

ok()   { printf "  ok  %s\n" "$1"; PASS=$((PASS + 1)); }
fail() { printf "  FAIL %s\n     %s\n" "$1" "$2"; FAIL=$((FAIL + 1)); }

seed_story() {
  local key="$1" dir="$2"
  mkdir -p "$dir"
  cat > "$dir/${key}-fake.md" <<'EOF'
---
template: 'story'
key: "TEST-S1"
title: "Fake"
status: in-progress
---

# Story: Fake

> **Status:** in-progress

## Review Gate

| Review | Status | Report |
|--------|--------|--------|
| Code Review | UNVERIFIED | — |
| QA Tests | UNVERIFIED | — |
| Security Review | UNVERIFIED | — |
| Test Automation | UNVERIFIED | — |
| Test Review | UNVERIFIED | — |
| Performance Review | UNVERIFIED | — |
EOF
}

reset() {
  rm -rf "$ART"
  mkdir -p "$ART"
}

# ---------- AC1: Flat path resolution (critical) ----------
# Story file lives at docs/implementation-artifacts/TEST-S1-fake.md (flat).
# review-gate.sh must find it there, NOT in a stories/ subdirectory.
reset
seed_story TEST-S1 "$ART"
if "$RG" status --story TEST-S1 >/dev/null 2>&1; then
  ok "AC1 flat path: review-gate.sh finds story in flat implementation-artifacts/"
else
  fail "AC1 flat path" "review-gate.sh could not find story file in flat layout"
fi

# ---------- AC1b: stories/ subdirectory must NOT be required ----------
# If a file exists ONLY in stories/, the script should still use flat layout.
# But first verify that with the file in flat layout (not stories/), it works.
reset
mkdir -p "$ART/stories"
seed_story TEST-S1 "$ART/stories"
# File is ONLY in stories/, not in flat ART/. If the script is fixed, it
# should fail because it looks in flat ART/ and the file is not there.
if ! "$RG" status --story TEST-S1 >/dev/null 2>err; then
  ok "AC1b stories/ subdirectory not used: correctly fails when file only in stories/"
else
  fail "AC1b stories/ subdirectory" "review-gate.sh found file in stories/ (should use flat path)"
fi

# ---------- AC1c: IMPLEMENTATION_ARTIFACTS env var respected ----------
reset
CUSTOM_ART="$TMP/custom-artifacts"
mkdir -p "$CUSTOM_ART"
seed_story TEST-S1 "$CUSTOM_ART"
if IMPLEMENTATION_ARTIFACTS="$CUSTOM_ART" "$RG" status --story TEST-S1 >/dev/null 2>&1; then
  ok "AC1c IMPLEMENTATION_ARTIFACTS env var overrides default path"
else
  fail "AC1c IMPLEMENTATION_ARTIFACTS" "env var not respected"
fi

# ---------- AC3a: status subcommand returns valid JSON ----------
reset
seed_story TEST-S1 "$ART"
out=$("$RG" status --story TEST-S1 2>/dev/null)
if printf '%s' "$out" | jq -e '.gates["Code Review"]' >/dev/null 2>&1; then
  ok "AC3a status returns valid JSON with gates"
else
  fail "AC3a status JSON" "out=$out"
fi

# ---------- AC3b: check subcommand fails when not all PASSED ----------
reset
seed_story TEST-S1 "$ART"
if ! "$RG" check --story TEST-S1 >/dev/null 2>err; then
  ok "AC3b check fails when gates are UNVERIFIED"
else
  fail "AC3b check" "check succeeded but gates are UNVERIFIED"
fi

# ---------- AC3c: update subcommand changes a gate ----------
reset
seed_story TEST-S1 "$ART"
if "$RG" update --story TEST-S1 --gate "Code Review" --verdict PASSED >/dev/null 2>&1; then
  if grep -q '| Code Review | PASSED |' "$ART/TEST-S1-fake.md"; then
    ok "AC3c update rewrites gate row"
  else
    fail "AC3c update" "gate row not rewritten in file"
  fi
else
  fail "AC3c update" "update command failed"
fi

# ---------- AC3d: --help works ----------
out=$("$RG" --help 2>&1) && rc=0 || rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'check'; then
  ok "AC3d --help prints usage"
else
  fail "AC3d --help" "rc=$rc"
fi

printf "\n%d passed, %d failed\n" "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
