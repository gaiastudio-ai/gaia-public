#!/usr/bin/env bash
# smoke-sprint-state.sh — manual smoke test harness for sprint-state.sh (E28-S11)
#
# One assertion (or set) per AC (AC1–AC6) plus the 8 edge-case scenarios
# from the story spec. The full bats-core suite lands in E28-S17 — this is
# the TDD harness that drives the RED → GREEN cycle for E28-S11 only.
#
# Usage: bash plugins/gaia/scripts/tests/smoke-sprint-state.sh
# Exit 0 when all assertions pass, 1 on first aggregated failure.

set -uo pipefail
LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SS="$SCRIPT_DIR/sprint-state.sh"

TMP="$(mktemp -d)"
export MEMORY_PATH="$TMP/_memory"
export PROJECT_PATH="$TMP"
ART="$TMP/docs/implementation-artifacts"
mkdir -p "$ART"
JSONL="$MEMORY_PATH/lifecycle-events.jsonl"
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0

ok()   { printf "  ok  %s\n" "$1"; PASS=$((PASS + 1)); }
fail() { printf "  FAIL %s\n     %s\n" "$1" "$2"; FAIL=$((FAIL + 1)); }

seed_story() {
  local key="$1" status="$2" all_passed="${3:-PASSED}"
  cat > "$ART/${key}-fake.md" <<EOF
---
key: "$key"
title: "Fake"
status: $status
---

# Story: Fake

> **Status:** $status

## Review Gate

| Review | Status | Report |
|--------|--------|--------|
| Code Review | $all_passed | — |
| QA Tests | $all_passed | — |
| Security Review | $all_passed | — |
| Test Automation | $all_passed | — |
| Test Review | $all_passed | — |
| Performance Review | $all_passed | — |
EOF
}

seed_yaml() {
  local key="$1" status="$2"
  cat > "$ART/sprint-status.yaml" <<EOF
sprint_id: "sprint-test"
stories:
  - key: "$key"
    title: "Fake"
    status: "$status"
EOF
}

reset() {
  rm -rf "$ART" "$MEMORY_PATH"
  mkdir -p "$ART"
}

# ---------- AC1: --help ----------
out=$("$SS" --help 2>&1) && rc=0 || rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'transition' \
   && printf '%s' "$out" | grep -q 'get' \
   && printf '%s' "$out" | grep -q 'validate'; then
  ok "AC1 --help prints usage with three subcommands"
else
  fail "AC1 --help" "rc=$rc out=$out"
fi

# ---------- AC2: illegal adjacency ----------
reset; seed_story E1-S1 backlog; seed_yaml E1-S1 backlog
if ! "$SS" transition --story E1-S1 --to done >/dev/null 2>err; then
  if grep -q "illegal transition" err && ! grep -q done < "$ART/E1-S1-fake.md" 2>/dev/null \
     || ! grep -q 'status: done' "$ART/E1-S1-fake.md"; then
    ok "AC2 illegal adjacency rejected, file unchanged"
  else
    fail "AC2" "file mutated"
  fi
else
  fail "AC2" "transition succeeded"
fi

# ---------- AC3: happy path transition ----------
reset; seed_story E1-S1 ready-for-dev; seed_yaml E1-S1 ready-for-dev
if "$SS" transition --story E1-S1 --to in-progress >/dev/null 2>&1; then
  if grep -q '^status: in-progress' "$ART/E1-S1-fake.md" \
     && grep -q '^> \*\*Status:\*\* in-progress' "$ART/E1-S1-fake.md" \
     && grep -q 'status: "in-progress"' "$ART/sprint-status.yaml" \
     && [ -s "$JSONL" ] && grep -q '"event_type":"state_transition"' "$JSONL"; then
    ok "AC3 transition rewrites story + yaml + emits event"
  else
    fail "AC3" "partial update"
  fi
else
  fail "AC3" "transition failed"
fi

# ---------- AC4: concurrent transitions serialized ----------
reset; seed_story E1-S1 ready-for-dev; seed_story E1-S2 ready-for-dev
cat > "$ART/sprint-status.yaml" <<'EOF'
stories:
  - key: "E1-S1"
    status: "ready-for-dev"
  - key: "E1-S2"
    status: "ready-for-dev"
EOF
"$SS" transition --story E1-S1 --to in-progress >/dev/null 2>&1 &
P1=$!
"$SS" transition --story E1-S2 --to in-progress >/dev/null 2>&1 &
P2=$!
wait $P1; wait $P2
if grep -q '"E1-S1"' "$ART/sprint-status.yaml" \
   && grep -q '"E1-S2"' "$ART/sprint-status.yaml" \
   && grep -c 'status: "in-progress"' "$ART/sprint-status.yaml" | grep -q '^2$'; then
  ok "AC4 concurrent transitions both persisted under lock"
else
  fail "AC4" "concurrent writes lost or interleaved"
fi

# ---------- AC5: get + validate ----------
reset; seed_story E1-S1 in-progress; seed_yaml E1-S1 in-progress
out=$("$SS" get --story E1-S1) && [ "$out" = "in-progress" ] \
  && ok "AC5 get returns current state" || fail "AC5.get" "out=$out"
"$SS" validate --story E1-S1 >/dev/null 2>&1 \
  && ok "AC5 validate clean" || fail "AC5.validate-clean" ""
# induce drift
sed -i.bak 's/status: "in-progress"/status: "done"/' "$ART/sprint-status.yaml"
rm -f "$ART/sprint-status.yaml.bak"
if ! "$SS" validate --story E1-S1 >/dev/null 2>err; then
  grep -q "drift detected" err && ok "AC5 validate detects drift" || fail "AC5.drift" "$(cat err)"
else
  fail "AC5.drift" "validate returned 0"
fi

# ---------- AC6: review gate blocks -> done ----------
reset; seed_story E1-S1 review UNVERIFIED; seed_yaml E1-S1 review
if ! "$SS" transition --story E1-S1 --to done >/dev/null 2>err; then
  grep -q "Review Gate not fully PASSED" err && ok "AC6 blocks done when gates not PASSED" \
    || fail "AC6" "$(cat err)"
else
  fail "AC6" "transition succeeded"
fi

# ---------- AC6: review gate allows -> done when all PASSED ----------
reset; seed_story E1-S1 review PASSED; seed_yaml E1-S1 review
if "$SS" transition --story E1-S1 --to done >/dev/null 2>&1; then
  grep -q '^status: done' "$ART/E1-S1-fake.md" \
    && ok "AC6 allows done when all six PASSED" || fail "AC6.allow" "story not done"
else
  fail "AC6.allow" "transition failed"
fi

# ---------- AC-EC1: missing sprint-status.yaml ----------
reset; seed_story E1-S1 ready-for-dev
if ! "$SS" transition --story E1-S1 --to in-progress >/dev/null 2>err; then
  grep -qi "sprint-status.yaml" err && ok "AC-EC1 missing yaml detected" \
    || fail "AC-EC1" "$(cat err)"
else
  fail "AC-EC1" "transition succeeded"
fi

# ---------- AC-EC5: glob zero match / multi match ----------
reset; seed_yaml NOPE-S999 ready-for-dev
if ! "$SS" get --story NOPE-S999 >/dev/null 2>err; then
  grep -q "no story file found" err && ok "AC-EC5 zero-match detected" \
    || fail "AC-EC5.zero" "$(cat err)"
else
  fail "AC-EC5.zero" "get succeeded"
fi
reset; seed_story E1-S1 backlog; cp "$ART/E1-S1-fake.md" "$ART/E1-S1-dup.md"; seed_yaml E1-S1 backlog
if ! "$SS" get --story E1-S1 >/dev/null 2>err; then
  grep -q "multiple story files" err && ok "AC-EC5 multi-match detected" \
    || fail "AC-EC5.multi" "$(cat err)"
else
  fail "AC-EC5.multi" "get succeeded"
fi

printf "\n%d passed, %d failed\n" "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
