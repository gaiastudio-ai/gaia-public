#!/usr/bin/env bash
# test_checkpoint.sh — smoke tests for plugins/gaia/scripts/checkpoint.sh (E28-S10)
#
# Pure-bash test harness (no bats dependency) exercising the read/write/validate
# contract defined by AC1-AC6 and AC-EC1..AC-EC6. E28-S17 will re-implement these
# assertions under bats-core using the fixtures in ./fixtures/checkpoint/.
#
# Usage: ./test_checkpoint.sh
# Exit:  0 on all-pass, 1 on any failure.

set -uo pipefail
LC_ALL=C
export LC_ALL

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PLUGIN_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
CHECKPOINT_SH="$PLUGIN_DIR/scripts/checkpoint.sh"

FAILED=0
PASSED=0

# Each test runs in its own temp CHECKPOINT_PATH sandbox so cases cannot
# contaminate one another (and so the host _memory/ tree is never touched).
SANDBOX=""
make_sandbox() {
  SANDBOX=$(mktemp -d 2>/dev/null || mktemp -d -t gaia-ck)
  export CHECKPOINT_PATH="$SANDBOX"
}

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    PASSED=$((PASSED + 1))
    printf '  PASS: %s\n' "$label"
  else
    FAILED=$((FAILED + 1))
    printf '  FAIL: %s\n    expected: %q\n    actual:   %q\n' "$label" "$expected" "$actual"
  fi
}

assert_contains() {
  local label="$1" needle="$2" haystack="$3"
  case "$haystack" in
    *"$needle"*)
      PASSED=$((PASSED + 1))
      printf '  PASS: %s\n' "$label" ;;
    *)
      FAILED=$((FAILED + 1))
      printf '  FAIL: %s\n    missing: %q\n    in:\n%s\n' "$label" "$needle" "$haystack" ;;
  esac
}

assert_file_exists() {
  local label="$1" path="$2"
  if [ -f "$path" ]; then
    PASSED=$((PASSED + 1))
    printf '  PASS: %s\n' "$label"
  else
    FAILED=$((FAILED + 1))
    printf '  FAIL: %s (missing file %s)\n' "$label" "$path"
  fi
}

# -------- AC1 — dispatcher --------
test_ac1_dispatcher() {
  printf 'AC1 — subcommand dispatcher\n'
  make_sandbox
  local out rc
  out=$("$CHECKPOINT_SH" bogus 2>&1); rc=$?
  [ "$rc" -ne 0 ] && PASSED=$((PASSED + 1)) || { FAILED=$((FAILED + 1)); printf '  FAIL: bogus subcommand must exit non-zero\n'; }
  assert_contains "usage banner on bogus" "usage" "$(printf '%s' "$out" | tr '[:upper:]' '[:lower:]')"

  out=$("$CHECKPOINT_SH" 2>&1); rc=$?
  [ "$rc" -ne 0 ] && PASSED=$((PASSED + 1)) || { FAILED=$((FAILED + 1)); printf '  FAIL: no args must exit non-zero\n'; }
}

# -------- AC2, AC5 — write happy path + determinism --------
test_ac2_write_happy() {
  printf 'AC2 — write happy path\n'
  make_sandbox; local sb="$SANDBOX"
  local tmpfile; tmpfile=$(mktemp)
  printf 'hello\n' > "$tmpfile"

  "$CHECKPOINT_SH" write --workflow foo --step 3 --var key=val --file "$tmpfile" >/dev/null
  assert_file_exists "foo.yaml written" "$sb/foo.yaml"

  local content; content=$(cat "$sb/foo.yaml")
  assert_contains "workflow field"    "workflow: foo"    "$content"
  assert_contains "step field"        "step: 3"          "$content"
  assert_contains "variables key=val" "key: val"         "$content"
  assert_contains "files_touched"     "files_touched:"   "$content"

  local expected_hex
  expected_hex=$(shasum -a 256 "$tmpfile" | awk '{print $1}')
  assert_contains "sha256 digest" "sha256:$expected_hex" "$content"

  rm -f "$tmpfile"
}

test_ac5_determinism() {
  printf 'AC5 — deterministic output\n'
  make_sandbox; local sb="$SANDBOX"
  local tmpfile; tmpfile=$(mktemp)
  printf 'stable\n' > "$tmpfile"

  "$CHECKPOINT_SH" write --workflow det --step 1 --var a=1 --var b=2 --file "$tmpfile" >/dev/null
  local first; first=$(cat "$sb/det.yaml")
  # Write a second time with the same inputs — the timestamp will differ, so
  # we normalize it out before comparing to confirm field ORDER is stable.
  sleep 1
  "$CHECKPOINT_SH" write --workflow det --step 1 --var a=1 --var b=2 --file "$tmpfile" >/dev/null
  local second; second=$(cat "$sb/det.yaml")

  local first_norm second_norm
  first_norm=$(printf '%s' "$first"  | sed -E 's/^timestamp:.*/timestamp: NORM/')
  second_norm=$(printf '%s' "$second" | sed -E 's/^timestamp:.*/timestamp: NORM/')
  assert_eq "stable field order" "$first_norm" "$second_norm"

  rm -f "$tmpfile"
}

# -------- AC3 — read --------
test_ac3_read() {
  printf 'AC3 — read subcommand\n'
  make_sandbox; local sb="$SANDBOX"
  local tmpfile; tmpfile=$(mktemp)
  printf 'r\n' > "$tmpfile"
  "$CHECKPOINT_SH" write --workflow r --step 1 --file "$tmpfile" >/dev/null

  local out rc
  out=$("$CHECKPOINT_SH" read --workflow r 2>/dev/null); rc=$?
  assert_eq "read happy exit 0" "0" "$rc"
  assert_contains "read emits workflow" "workflow: r" "$out"

  out=$("$CHECKPOINT_SH" read --workflow nope 2>&1 >/dev/null); rc=$?
  assert_eq "read missing exit 2" "2" "$rc"
  assert_contains "read missing mentions path" "nope.yaml" "$out"

  rm -f "$tmpfile"
}

# -------- AC4 — validate clean/drift/missing --------
test_ac4_validate() {
  printf 'AC4 — validate subcommand\n'
  make_sandbox; local sb="$SANDBOX"
  local tmpfile; tmpfile=$(mktemp)
  printf 'v1\n' > "$tmpfile"
  "$CHECKPOINT_SH" write --workflow v --step 1 --file "$tmpfile" >/dev/null

  # Clean
  "$CHECKPOINT_SH" validate --workflow v >/dev/null 2>&1
  assert_eq "validate clean exit 0" "0" "$?"

  # Drift
  printf 'v2-drifted\n' > "$tmpfile"
  local out rc
  out=$("$CHECKPOINT_SH" validate --workflow v 2>&1 >/dev/null); rc=$?
  assert_eq "validate drift exit 1" "1" "$rc"
  assert_contains "drift reports path" "$tmpfile" "$out"

  # Missing
  rm -f "$tmpfile"
  out=$("$CHECKPOINT_SH" validate --workflow v 2>&1 >/dev/null); rc=$?
  assert_eq "validate missing exit 2" "2" "$rc"
  assert_contains "missing reports path" "$tmpfile" "$out"
}

# -------- AC6 — concurrent writes serialized by flock --------
test_ac6_concurrency() {
  printf 'AC6 — concurrent write race\n'
  make_sandbox; local sb="$SANDBOX"
  local a; a=$(mktemp); printf 'A\n' > "$a"
  local b; b=$(mktemp); printf 'B\n' > "$b"

  "$CHECKPOINT_SH" write --workflow race --step 1 --var who=alpha --file "$a" >/dev/null &
  local p1=$!
  "$CHECKPOINT_SH" write --workflow race --step 1 --var who=bravo --file "$b" >/dev/null &
  local p2=$!
  wait "$p1" "$p2"

  assert_file_exists "race file exists" "$sb/race.yaml"
  local content; content=$(cat "$sb/race.yaml")
  # Exactly ONE of the two payloads must be present — never both interleaved.
  local has_a=0 has_b=0
  case "$content" in *"who: alpha"*) has_a=1 ;; esac
  case "$content" in *"who: bravo"*) has_b=1 ;; esac
  if [ $((has_a + has_b)) -eq 1 ]; then
    PASSED=$((PASSED + 1)); printf '  PASS: exactly one payload wins\n'
  else
    FAILED=$((FAILED + 1)); printf '  FAIL: interleaved or empty (alpha=%s bravo=%s)\n' "$has_a" "$has_b"
  fi

  rm -f "$a" "$b"
}

# -------- AC-EC1 — zero --file flags --------
test_ec1_no_files() {
  printf 'AC-EC1 — zero --file\n'
  make_sandbox; local sb="$SANDBOX"
  "$CHECKPOINT_SH" write --workflow empty --step 0 >/dev/null
  assert_eq "exit 0" "0" "$?"
  local content; content=$(cat "$sb/empty.yaml")
  assert_contains "empty files_touched" "files_touched: []" "$content"
}

# -------- AC-EC2 — unreadable file --------
test_ec2_unreadable() {
  printf 'AC-EC2 — unreadable --file\n'
  make_sandbox
  local tmpfile; tmpfile=$(mktemp); printf 'x\n' > "$tmpfile"
  chmod 000 "$tmpfile"
  local out rc
  out=$("$CHECKPOINT_SH" write --workflow perm --step 1 --file "$tmpfile" 2>&1 >/dev/null); rc=$?
  chmod 644 "$tmpfile"; rm -f "$tmpfile"
  # Accept rc=1 on macOS where chmod 000 blocks root-less reads; skip silently if root bypasses perms.
  if [ "$(id -u)" = "0" ]; then
    printf '  SKIP: running as root — perm bit cannot block read\n'
  else
    assert_eq "unreadable exit 1" "1" "$rc"
    assert_contains "error mentions cannot read" "cannot read" "$out"
  fi
}

# -------- AC-EC4 — unicode / spaces in path --------
test_ec4_unicode() {
  printf 'AC-EC4 — path with spaces and unicode\n'
  make_sandbox; local sb="$SANDBOX"
  local dir; dir=$(mktemp -d)
  local weird="$dir/has spaces/é.md"
  mkdir -p "$dir/has spaces"
  printf 'u\n' > "$weird"

  "$CHECKPOINT_SH" write --workflow uni --step 1 --file "$weird" >/dev/null
  local rc=$?
  assert_eq "unicode write exit 0" "0" "$rc"
  local content; content=$(cat "$sb/uni.yaml")
  assert_contains "unicode path present" "é.md" "$content"

  "$CHECKPOINT_SH" validate --workflow uni >/dev/null 2>&1
  assert_eq "unicode validate clean exit 0" "0" "$?"

  rm -rf "$dir"
}

# -------- AC-EC5 — missing CHECKPOINT_PATH --------
test_ec5_no_checkpoint_path() {
  printf 'AC-EC5 — CHECKPOINT_PATH unresolved\n'
  local out rc
  out=$(env -i PATH="$PATH" "$CHECKPOINT_SH" write --workflow z --step 1 2>&1 >/dev/null); rc=$?
  assert_eq "unresolved path exit 1" "1" "$rc"
  assert_contains "error names CHECKPOINT_PATH" "CHECKPOINT_PATH" "$out"
}

# -------- AC-EC6 — path traversal rejected --------
test_ec6_traversal() {
  printf 'AC-EC6 — path traversal in --workflow\n'
  make_sandbox
  local out rc
  out=$("$CHECKPOINT_SH" write --workflow "../../etc/passwd" --step 1 2>&1 >/dev/null); rc=$?
  assert_eq "traversal exit 1" "1" "$rc"
  assert_contains "error names traversal" "traversal" "$(printf '%s' "$out" | tr '[:upper:]' '[:lower:]')"
}

# -------- main --------
printf '=== checkpoint.sh smoke tests ===\n'
if [ ! -x "$CHECKPOINT_SH" ] && [ ! -f "$CHECKPOINT_SH" ]; then
  printf 'SKIP: %s does not exist yet (RED phase expected)\n' "$CHECKPOINT_SH"
  exit 1
fi

test_ac1_dispatcher
test_ac2_write_happy
test_ac5_determinism
test_ac3_read
test_ac4_validate
test_ac6_concurrency
test_ec1_no_files
test_ec2_unreadable
test_ec4_unicode
test_ec5_no_checkpoint_path
test_ec6_traversal

printf '\n=== %d passed, %d failed ===\n' "$PASSED" "$FAILED"
[ "$FAILED" -eq 0 ]
