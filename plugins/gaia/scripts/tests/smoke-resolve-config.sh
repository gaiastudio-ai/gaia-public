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

# =============================================================================
# E28-S142 — Config Split (shared + local) tests
# =============================================================================
# These cases exercise the two-file merge implemented by E28-S142. The resolver
# reads the team-shared `config/project-config.yaml` first, then overlays the
# machine-local `global.yaml`, with GAIA_* env vars winning over both layers.
# Precedence contract (ADR-044): env > local > shared.

# Minimal fixture builders that write just the files each TC needs.
mk_shared() {
  local dir="$1"; shift
  mkdir -p "$dir/config"
  cat > "$dir/config/project-config.yaml"
}

mk_local() {
  local path="$1"; shift
  mkdir -p "$(dirname "$path")"
  cat > "$path"
}

echo "== TC-1: both files present, disjoint keys (E28-S142) =="
S1="$TMP/s1"
mk_shared "$S1" <<'YAML'
project_root: /tmp/s142/root
project_path: /tmp/s142/root/app
memory_path: /tmp/s142/root/_memory
checkpoint_path: /tmp/s142/root/_memory/checkpoints
framework_version: 1.127.2-rc.1
date: 2026-04-17
YAML
L1="$TMP/l1/_gaia/_config/global.yaml"
mk_local "$L1" <<'YAML'
installed_path: /tmp/s142/root/_gaia
YAML
out1="$(CLAUDE_SKILL_DIR="$S1" "$RESOLVE" --local "$L1" 2>/dev/null || true)"
if echo "$out1" | grep -q "^project_root='/tmp/s142/root'$" && \
   echo "$out1" | grep -q "^installed_path='/tmp/s142/root/_gaia'$"; then
  ok "TC-1 disjoint merge"
else
  fail "TC-1 disjoint merge" "$out1"
fi

echo "== TC-2: both present, overlapping key — local wins (AC3) =="
S2="$TMP/s2"
mk_shared "$S2" <<'YAML'
project_root: /tmp/s142/root
project_path: /tmp/shared-app
memory_path: /tmp/s142/root/_memory
checkpoint_path: /tmp/s142/root/_memory/checkpoints
installed_path: /tmp/s142/root/_gaia
framework_version: 1.127.2-rc.1
date: 2026-04-17
YAML
L2="$TMP/l2/global.yaml"
mk_local "$L2" <<'YAML'
project_path: /tmp/local-app
YAML
out2="$(CLAUDE_SKILL_DIR="$S2" "$RESOLVE" --local "$L2" 2>/dev/null || true)"
if echo "$out2" | grep -q "^project_path='/tmp/local-app'$"; then
  ok "TC-2 local overrides shared"
else
  fail "TC-2 local overrides shared" "$out2"
fi

echo "== TC-3: only local present — AC4 backward-compat =="
L3="$TMP/l3/global.yaml"
mk_local "$L3" <<'YAML'
project_root: /tmp/l3
project_path: /tmp/l3/app
memory_path: /tmp/l3/_memory
checkpoint_path: /tmp/l3/_memory/checkpoints
installed_path: /tmp/l3/_gaia
framework_version: 1.127.2-rc.1
date: 2026-04-17
YAML
out3="$("$RESOLVE" --local "$L3" 2>/dev/null || true)"
if echo "$out3" | grep -q "^project_root='/tmp/l3'$" && \
   echo "$out3" | grep -q "^project_path='/tmp/l3/app'$"; then
  ok "TC-3 local-only backward compat"
else
  fail "TC-3 local-only backward compat" "$out3"
fi

echo "== TC-4: only shared present — resolver treats shared as sole layer =="
S4="$TMP/s4"
mk_shared "$S4" <<'YAML'
project_root: /tmp/s4
project_path: /tmp/s4/app
memory_path: /tmp/s4/_memory
checkpoint_path: /tmp/s4/_memory/checkpoints
installed_path: /tmp/s4/_gaia
framework_version: 1.127.2-rc.1
date: 2026-04-17
YAML
out4="$(CLAUDE_SKILL_DIR="$S4" "$RESOLVE" 2>/dev/null || true)"
if echo "$out4" | grep -q "^project_root='/tmp/s4'$"; then
  ok "TC-4 shared-only"
else
  fail "TC-4 shared-only" "$out4"
fi

echo "== TC-5: both missing — exit 2 with actionable message =="
err5="$(env -u CLAUDE_SKILL_DIR "$RESOLVE" --local "$TMP/does-not-exist.yaml" 2>&1 1>/dev/null)"; rc=$?
if [ "$rc" -eq 2 ]; then
  ok "TC-5 both missing"
else
  fail "TC-5 both missing" "rc=$rc err=$err5"
fi

echo "== TC-6: GAIA_* env override wins over both file layers =="
S6="$TMP/s6"
mk_shared "$S6" <<'YAML'
project_root: /tmp/s6/shared
project_path: /tmp/s6/shared/app
memory_path: /tmp/s6/shared/_memory
checkpoint_path: /tmp/s6/shared/_memory/checkpoints
installed_path: /tmp/s6/shared/_gaia
framework_version: 1.127.2-rc.1
date: 2026-04-17
YAML
L6="$TMP/l6/global.yaml"
mk_local "$L6" <<'YAML'
project_path: /tmp/s6/local/app
YAML
out6="$(CLAUDE_SKILL_DIR="$S6" GAIA_PROJECT_PATH=/tmp/from-env "$RESOLVE" --local "$L6" 2>/dev/null || true)"
if echo "$out6" | grep -q "^project_path='/tmp/from-env'$"; then
  ok "TC-6 env wins"
else
  fail "TC-6 env wins" "$out6"
fi

echo "== TC-7: malformed shared YAML — error message names shared file =="
S7="$TMP/s7"
mkdir -p "$S7/config"
printf 'project_root: [unclosed\nmore: : :\n' > "$S7/config/project-config.yaml"
L7="$TMP/l7/global.yaml"
mk_local "$L7" <<'YAML'
installed_path: /tmp/l7
YAML
err7="$(CLAUDE_SKILL_DIR="$S7" "$RESOLVE" --local "$L7" 2>&1 1>/dev/null)"; rc=$?
if [ "$rc" -eq 2 ] && echo "$err7" | grep -q "project-config.yaml"; then
  ok "TC-7 shared malformed names shared file"
else
  fail "TC-7 shared malformed names shared file" "rc=$rc err=$err7"
fi

echo "== TC-8: flattened-key override across layers =="
S8="$TMP/s8"
mk_shared "$S8" <<'YAML'
project_root: /tmp/s8
project_path: /tmp/s8/app
memory_path: /tmp/s8/_memory
checkpoint_path: /tmp/s8/_memory/checkpoints
installed_path: /tmp/s8/_gaia
framework_version: 1.127.2-rc.1
date: 2026-04-17
val_integration:
  template_output_review: false
YAML
L8="$TMP/l8/global.yaml"
mk_local "$L8" <<'YAML'
val_integration:
  template_output_review: true
YAML
out8="$(CLAUDE_SKILL_DIR="$S8" "$RESOLVE" --local "$L8" 2>/dev/null || true)"
if echo "$out8" | grep -qE "^val_integration\.template_output_review='true'$"; then
  ok "TC-8 flattened-key merge"
else
  fail "TC-8 flattened-key merge" "$out8"
fi

echo "== TC-EC3: empty shared file — local is authoritative =="
SEC3="$TMP/sec3"
mkdir -p "$SEC3/config"
: > "$SEC3/config/project-config.yaml"
LEC3="$TMP/lec3/global.yaml"
mk_local "$LEC3" <<'YAML'
project_root: /tmp/ec3
project_path: /tmp/ec3/app
memory_path: /tmp/ec3/_memory
checkpoint_path: /tmp/ec3/_memory/checkpoints
installed_path: /tmp/ec3/_gaia
framework_version: 1.127.2-rc.1
date: 2026-04-17
YAML
outec3="$(CLAUDE_SKILL_DIR="$SEC3" "$RESOLVE" --local "$LEC3" 2>/dev/null || true)"
if echo "$outec3" | grep -q "^project_root='/tmp/ec3'$"; then
  ok "TC-EC3 empty shared"
else
  fail "TC-EC3 empty shared" "$outec3"
fi

echo "== TC-EC7: path traversal in shared file's project_path — rejected post-merge =="
SEC7="$TMP/sec7"
mk_shared "$SEC7" <<'YAML'
project_root: /tmp/ec7
project_path: ../../etc
memory_path: /tmp/ec7/_memory
checkpoint_path: /tmp/ec7/_memory/checkpoints
installed_path: /tmp/ec7/_gaia
framework_version: 1.127.2-rc.1
date: 2026-04-17
YAML
errec7="$(CLAUDE_SKILL_DIR="$SEC7" "$RESOLVE" 2>&1 1>/dev/null)"; rc=$?
if [ "$rc" -eq 2 ] && echo "$errec7" | grep -qi 'traversal\|\.\.'; then
  ok "TC-EC7 traversal rejected from shared"
else
  fail "TC-EC7 traversal rejected from shared" "rc=$rc err=$errec7"
fi

echo
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
