#!/usr/bin/env bash
# smoke-e28-s16.sh — manual smoke harness for template-header.sh,
# next-step.sh, and init-project.sh (E28-S16).
#
# Covers every AC (AC1-AC7) and the AC-EC edge cases that do NOT require
# yq on PATH. next-step.sh happy paths are left to the bats suite in
# E28-S17 where yq is pinned in the test image.
#
# Usage: bash plugins/gaia/scripts/tests/smoke-e28-s16.sh
# Exit 0 on success, 1 on first failure.

set -uo pipefail
LC_ALL=C
# shellcheck disable=SC2015  # A && B || C idiom is acceptable in this smoke harness


SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TH="$SCRIPT_DIR/template-header.sh"
NS="$SCRIPT_DIR/next-step.sh"
IP="$SCRIPT_DIR/init-project.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0

ok()   { printf "  ok  %s\n" "$1"; PASS=$((PASS + 1)); }
bad()  { printf "  FAIL %s\n     %s\n" "$1" "$2"; FAIL=$((FAIL + 1)); }

assert_eq_exit() {
  # assert_eq_exit <expected> <actual> <desc>
  if [ "$1" -eq "$2" ]; then ok "$3"; else bad "$3" "expected exit $1, got $2"; fi
}

assert_contains() {
  # assert_contains <haystack> <needle> <desc>
  case "$1" in
    *"$2"*) ok "$3" ;;
    *)      bad "$3" "output missing: $2" ;;
  esac
}

assert_empty() {
  if [ -z "$1" ]; then ok "$2"; else bad "$2" "expected empty, got: $1"; fi
}

echo "== template-header.sh =="

out="$("$TH" --template story --workflow create-story --var foo=bar 2>&1)"
rc=$?
assert_eq_exit 0 $rc "AC1 happy path exits 0"
assert_contains "$out" "workflow: create-story" "AC1 workflow line present"
assert_contains "$out" "template: story" "AC1 template line present"
assert_contains "$out" "framework_version: " "AC1 framework_version line present"
assert_contains "$out" "foo: 'bar'" "AC1 --var rendered single-quoted"

out="$("$TH" --template story --workflow create-story --var beta=2 --var alpha=1 2>&1)"
expected_order=$(printf "alpha: '1'\nbeta: '2'")
case "$out" in *"$expected_order"*) ok "AC1 --var output sorted by key" ;; *) bad "sort" "$out" ;; esac

out=$("$TH" --template story --workflow create-story --var "foo=\$(rm -rf /)" 2>&1)
assert_contains "$out" "foo: '\$(rm -rf /)'" "AC-EC2 shell metacharacters rendered literally"

set +e
out=$("$TH" --template story --workflow create-story --var =bar 2>&1)
rc=$?
set -e
assert_eq_exit 1 $rc "AC-EC1 empty --var key exits 1"
assert_contains "$out" "ERROR: --var key is empty" "AC-EC1 stderr message"

set +e
out=$("$TH" --template story --workflow create-story --var "bad-key=x" 2>&1)
rc=$?
set -e
assert_eq_exit 1 $rc "AC7 metachar key exits 1"
assert_contains "$out" "not a valid identifier" "AC7 stderr message"

set +e
out=$("$TH" --template story 2>&1)
rc=$?
set -e
assert_eq_exit 1 $rc "missing --workflow exits 1"

# Idempotency — byte-identical output with SOURCE_DATE_EPOCH pinned.
a=$(SOURCE_DATE_EPOCH=1700000000 "$TH" --template story --workflow create-story --var foo=bar)
b=$(SOURCE_DATE_EPOCH=1700000000 "$TH" --template story --workflow create-story --var foo=bar)
if [ "$a" = "$b" ]; then ok "AC4 idempotent output (SOURCE_DATE_EPOCH)"; else bad "idempotency" "drift"; fi

echo
echo "== init-project.sh =="

set +e
"$IP" --name demo --path "$TMP/demo" >/dev/null 2>&1
rc=$?
set -e
assert_eq_exit 0 $rc "AC3 happy path exits 0"
[ -d "$TMP/demo/docs/planning-artifacts" ] && ok "AC3 planning-artifacts created" || bad "planning" ""
[ -d "$TMP/demo/docs/implementation-artifacts" ] && ok "AC3 implementation-artifacts created" || bad "impl" ""
[ -d "$TMP/demo/docs/test-artifacts" ] && ok "AC3 test-artifacts created" || bad "test" ""
[ -d "$TMP/demo/docs/creative-artifacts" ] && ok "AC3 creative-artifacts created" || bad "creative" ""
[ -d "$TMP/demo/_memory/checkpoints" ] && ok "AC3 _memory/checkpoints created" || bad "memory" ""
[ -d "$TMP/demo/config" ] && ok "AC3 config/ created" || bad "config" ""
[ -s "$TMP/demo/config/project-config.yaml" ] && ok "AC3 project-config.yaml written" || bad "cfg" ""
[ -s "$TMP/demo/CLAUDE.md" ] && ok "AC3 CLAUDE.md written" || bad "claude" ""

lines=$(wc -l < "$TMP/demo/CLAUDE.md" | tr -d ' ')
if [ "$lines" -le 60 ]; then ok "AC3 CLAUDE.md <=60 lines ($lines)"; else bad "claude-len" "$lines"; fi

# Idempotent re-run.
set +e
"$IP" --name demo --path "$TMP/demo" >/dev/null 2>&1
rc=$?
set -e
assert_eq_exit 0 $rc "AC4 idempotent re-run exits 0"

# Non-empty git repo guard.
mkdir -p "$TMP/gitrepo"
(cd "$TMP/gitrepo" && git init -q && echo x > a && git add a && git -c user.email=x@x -c user.name=x commit -qm x)
set +e
out=$("$IP" --name g --path "$TMP/gitrepo" 2>&1)
rc=$?
set -e
assert_eq_exit 1 $rc "AC5 non-empty git repo exits 1 without --force"
assert_contains "$out" "non-empty git repo" "AC5 stderr message"

# --force overrides.
set +e
"$IP" --name g --path "$TMP/gitrepo" --force >/dev/null 2>&1
rc=$?
set -e
assert_eq_exit 0 $rc "AC5 --force overrides git guard"

# Non-empty CLAUDE.md clobber guard (AC-EC7).
mkdir -p "$TMP/nonempty"
printf "user content\n" > "$TMP/nonempty/CLAUDE.md"
set +e
out=$("$IP" --name ne --path "$TMP/nonempty" 2>&1)
rc=$?
set -e
assert_eq_exit 1 $rc "AC-EC7 non-empty file refused without --force"
assert_contains "$out" "refusing to clobber" "AC-EC7 stderr message"

# Unicode path (AC-EC9).
set +e
"$IP" --name uni --path "$TMP/démo projet" >/dev/null 2>&1
rc=$?
set -e
assert_eq_exit 0 $rc "AC-EC9 unicode+space path"
[ -s "$TMP/démo projet/CLAUDE.md" ] && ok "AC-EC9 skeleton written under unicode path" || bad "unicode" ""

echo
echo "== next-step.sh =="

# Static contract tests — --help and missing --workflow.
set +e
"$NS" --help >/dev/null 2>&1
rc=$?
set -e
assert_eq_exit 0 $rc "next-step --help exits 0"

set +e
out=$("$NS" 2>&1)
rc=$?
set -e
assert_eq_exit 1 $rc "next-step missing --workflow exits 1"

set +e
out=$("$NS" --status banana --workflow x 2>&1)
rc=$?
set -e
assert_eq_exit 1 $rc "next-step bad --status exits 1"

echo
echo "Summary: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
