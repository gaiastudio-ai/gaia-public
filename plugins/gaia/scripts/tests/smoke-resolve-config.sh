#!/usr/bin/env bash
# smoke-resolve-config.sh — manual smoke test harness for resolve-config.sh (E28-S9)
#
# One assertion per AC (AC1–AC6) and edge case (AC-EC1–AC-EC8). The full
# bats-core suite lands in E28-S17 — this is the TDD harness that drives
# the RED → GREEN cycle for E28-S9 only.
#
# Usage: bash plugins/gaia/scripts/tests/smoke-resolve-config.sh
# Exit 0 when all assertions pass, 1 on first failure.

set -uo pipefail
LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RESOLVE="$SCRIPT_DIR/resolve-config.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0

ok()   { printf "  ok  %s\n" "$1"; PASS=$((PASS + 1)); }
fail() { printf "  FAIL %s\n     %s\n" "$1" "$2"; FAIL=$((FAIL + 1)); }

# Build a valid fixture skill dir for most tests.
mk_skill_dir() {
  local dir="$1"; shift
  mkdir -p "$dir/config"
  cat > "$dir/config/project-config.yaml" <<'YAML'
project_root: /tmp/gaia-fixture-root
project_path: /tmp/gaia-fixture-root/app
memory_path: /tmp/gaia-fixture-root/_memory
checkpoint_path: /tmp/gaia-fixture-root/_memory/checkpoints
installed_path: /tmp/gaia-fixture-root/_gaia
framework_version: 1.127.2-rc.1
date: 2026-04-15
YAML
}

SKILL_DIR="$TMP/skill"
mk_skill_dir "$SKILL_DIR"

echo "== AC1: file exists, executable, header declares set -euo pipefail =="
if [ -x "$RESOLVE" ]; then ok "AC1 exec bit"; else fail "AC1 exec bit" "$RESOLVE not executable"; fi
if head -20 "$RESOLVE" 2>/dev/null | grep -q 'set -euo pipefail'; then ok "AC1 header flags"; else fail "AC1 header flags" "missing set -euo pipefail in header"; fi

echo "== AC2: reads CLAUDE_SKILL_DIR/config/project-config.yaml =="
out="$(CLAUDE_SKILL_DIR="$SKILL_DIR" "$RESOLVE" 2>/dev/null || true)"
if echo "$out" | grep -q "project_root='/tmp/gaia-fixture-root'"; then ok "AC2 reads file"; else fail "AC2 reads file" "output: $out"; fi

echo "== AC3: default shell format and --format json =="
if echo "$out" | grep -qE "^project_root='/tmp/gaia-fixture-root'$"; then ok "AC3 shell format"; else fail "AC3 shell format" "$out"; fi
json="$(CLAUDE_SKILL_DIR="$SKILL_DIR" "$RESOLVE" --format json 2>/dev/null || true)"
if echo "$json" | grep -q '"project_root"' && echo "$json" | grep -q '"/tmp/gaia-fixture-root"'; then ok "AC3 json format"; else fail "AC3 json format" "$json"; fi

echo "== AC4: required keys present =="
missing=""
for k in project_root project_path memory_path checkpoint_path installed_path framework_version date; do
  if ! echo "$out" | grep -q "^${k}="; then missing="$missing $k"; fi
done
if [ -z "$missing" ]; then ok "AC4 required keys"; else fail "AC4 required keys" "missing:$missing"; fi

echo "== AC5 / AC-EC2: missing required field → exit 2, stderr names field =="
BAD="$TMP/missing-field"
mkdir -p "$BAD/config"
cat > "$BAD/config/project-config.yaml" <<'YAML'
project_path: /tmp/gaia-fixture-root/app
memory_path: /tmp/gaia-fixture-root/_memory
checkpoint_path: /tmp/gaia-fixture-root/_memory/checkpoints
installed_path: /tmp/gaia-fixture-root/_gaia
framework_version: 1.127.2-rc.1
date: 2026-04-15
YAML
err="$(CLAUDE_SKILL_DIR="$BAD" "$RESOLVE" 2>&1 1>/dev/null)"; rc=$?
if [ "$rc" -eq 2 ] && echo "$err" | grep -q 'project_root'; then ok "AC5 missing field exit 2"; else fail "AC5 missing field exit 2" "rc=$rc err=$err"; fi

echo "== AC6 / AC-EC7: byte-identical idempotent output =="
a="$(CLAUDE_SKILL_DIR="$SKILL_DIR" "$RESOLVE" 2>/dev/null || true)"
b="$(CLAUDE_SKILL_DIR="$SKILL_DIR" "$RESOLVE" 2>/dev/null || true)"
if [ "$a" = "$b" ] && [ -n "$a" ]; then ok "AC6 idempotent"; else fail "AC6 idempotent" "diff found"; fi

echo "== AC-EC1: missing config file → exit 2, stderr names path =="
NOCFG="$TMP/nocfg"
mkdir -p "$NOCFG/config"
err="$(CLAUDE_SKILL_DIR="$NOCFG" "$RESOLVE" 2>&1 1>/dev/null)"; rc=$?
if [ "$rc" -eq 2 ] && echo "$err" | grep -q "$NOCFG/config/project-config.yaml"; then ok "AC-EC1 missing file"; else fail "AC-EC1 missing file" "rc=$rc err=$err"; fi

echo "== AC-EC3: env override wins =="
EC3="$TMP/ec3"
mk_skill_dir "$EC3"
out3="$(CLAUDE_SKILL_DIR="$EC3" GAIA_PROJECT_PATH=/tmp/from-env "$RESOLVE" 2>/dev/null || true)"
if echo "$out3" | grep -q "^project_path='/tmp/from-env'$"; then ok "AC-EC3 env wins"; else fail "AC-EC3 env wins" "$out3"; fi

echo "== AC-EC4: spaces/metachars round-trip via eval =="
EC4="$TMP/ec4"
mkdir -p "$EC4/config"
cat > "$EC4/config/project-config.yaml" <<'YAML'
project_root: /tmp/my project
project_path: /tmp/my project/app
memory_path: /tmp/my project/_memory
checkpoint_path: /tmp/my project/_memory/checkpoints
installed_path: /tmp/my project/_gaia
framework_version: 1.0.0
date: 2026-04-15
YAML
eval_out="$(CLAUDE_SKILL_DIR="$EC4" "$RESOLVE" 2>/dev/null || true)"
project_root=""
eval "$eval_out" 2>/dev/null || true
if [ "${project_root:-}" = "/tmp/my project" ]; then ok "AC-EC4 eval round-trip"; else fail "AC-EC4 eval round-trip" "got='${project_root:-}'"; fi

echo "== AC-EC5: malformed YAML with --format json → exit 2, empty stdout =="
EC5="$TMP/ec5"
mkdir -p "$EC5/config"
printf 'project_root: [unclosed\n  not valid yaml at all: : :\n' > "$EC5/config/project-config.yaml"
stdout="$(CLAUDE_SKILL_DIR="$EC5" "$RESOLVE" --format json 2>/dev/null)"; rc=$?
if [ "$rc" -eq 2 ] && [ -z "$stdout" ]; then ok "AC-EC5 malformed yaml"; else fail "AC-EC5 malformed yaml" "rc=$rc stdout='$stdout'"; fi

echo "== AC-EC6: no CLAUDE_SKILL_DIR and no --config → exit 2 with remedy =="
err="$(env -u CLAUDE_SKILL_DIR "$RESOLVE" 2>&1 1>/dev/null)"; rc=$?
if [ "$rc" -eq 2 ] && echo "$err" | grep -q -- 'CLAUDE_SKILL_DIR'; then ok "AC-EC6 no config path"; else fail "AC-EC6 no config path" "rc=$rc err=$err"; fi

echo "== AC-EC8: path traversal in project_path → exit 2 =="
EC8="$TMP/ec8"
mkdir -p "$EC8/config"
cat > "$EC8/config/project-config.yaml" <<'YAML'
project_root: /tmp/ok
project_path: ../../etc
memory_path: /tmp/ok/_memory
checkpoint_path: /tmp/ok/_memory/checkpoints
installed_path: /tmp/ok/_gaia
framework_version: 1.0.0
date: 2026-04-15
YAML
err="$(CLAUDE_SKILL_DIR="$EC8" "$RESOLVE" 2>&1 1>/dev/null)"; rc=$?
if [ "$rc" -eq 2 ] && echo "$err" | grep -qi 'traversal\|\.\.'; then ok "AC-EC8 traversal rejected"; else fail "AC-EC8 traversal rejected" "rc=$rc err=$err"; fi

echo
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
