#!/usr/bin/env bash
# smoke-e28-s162.sh — smoke harness for the shared missing-file graceful
# fallback helper (E28-S162) and its refactored consumer next-step.sh.
#
# Covers AC1 (helper exists and is sourceable with handle_missing_file
# function), AC2 (next-step.sh delegates to the helper instead of its
# inline variant), and AC3 (missing-file behavior for next-step.sh
# matches pre-refactor semantics — exit 0 with fallback notice in
# graceful mode, exit 2 with stderr error in strict mode).
#
# Usage: bash plugins/gaia/scripts/tests/smoke-e28-s162.sh
# Exit 0 on success, 1 on first failure.

set -uo pipefail
LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HELPER="$SCRIPT_DIR/lib/missing-file-fallback.sh"
NS="$SCRIPT_DIR/next-step.sh"

PASS=0
FAIL=0

ok()  { printf "  ok  %s\n" "$1"; PASS=$((PASS + 1)); }
bad() { printf "  FAIL %s\n     %s\n" "$1" "$2"; FAIL=$((FAIL + 1)); }

assert_eq_exit() {
  if [ "$1" -eq "$2" ]; then ok "$3"; else bad "$3" "expected exit $1, got $2"; fi
}

assert_contains() {
  case "$1" in
    *"$2"*) ok "$3" ;;
    *)      bad "$3" "output missing: $2" ;;
  esac
}

assert_not_contains() {
  case "$1" in
    *"$2"*) bad "$3" "unexpected content: $2" ;;
    *)      ok "$3" ;;
  esac
}

echo "== missing-file-fallback.sh (AC1) =="

# AC1 — helper file exists on disk
if [ -f "$HELPER" ]; then ok "AC1 helper file exists at scripts/lib/missing-file-fallback.sh"
else bad "AC1 helper file exists at scripts/lib/missing-file-fallback.sh" "missing: $HELPER"; fi

# AC1 — helper is sourceable from a clean shell
set +e
sourced_out="$(bash -c ". '$HELPER' && declare -F handle_missing_file" 2>&1)"
rc=$?
set -e
assert_eq_exit 0 $rc "AC1 helper sourcing exits 0"
assert_contains "$sourced_out" "handle_missing_file" "AC1 handle_missing_file is defined after source"

echo "== helper behavior contract =="

# Graceful mode: file missing, strict var unset → sentinel 10 + stdout notice
set +e
graceful_out="$(bash -c ". '$HELPER'; handle_missing_file '/no/such/path' GAIA_TEST_STRICT 'test: legacy manifest not available' test-context" 2>/dev/null)"
graceful_rc=$?
set -e
assert_eq_exit 10 $graceful_rc "helper returns sentinel 10 when file missing and strict var unset"
assert_contains "$graceful_out" "legacy manifest not available" "helper prints graceful notice on stdout"

# Graceful mode: file missing, strict var explicitly 0 → sentinel 10
set +e
# shellcheck disable=SC2034  # stdout captured for assertion parity with graceful_out above
graceful_zero_out="$(GAIA_TEST_STRICT=0 bash -c ". '$HELPER'; handle_missing_file '/no/such/path' GAIA_TEST_STRICT 'notice' label" 2>/dev/null)"
graceful_zero_rc=$?
set -e
assert_eq_exit 10 $graceful_zero_rc "helper returns sentinel 10 when strict var is 0"

# Strict mode: file missing, strict var set to 1 → exit 2 + stderr error
set +e
strict_err="$(GAIA_TEST_STRICT=1 bash -c ". '$HELPER'; handle_missing_file '/no/such/path' GAIA_TEST_STRICT 'notice' label" 2>&1 >/dev/null)"
strict_rc=$?
set -e
assert_eq_exit 2 $strict_rc "helper returns exit 2 when strict var is 1"
assert_contains "$strict_err" "label" "helper strict-mode error includes context label on stderr"
assert_contains "$strict_err" "/no/such/path" "helper strict-mode error includes missing path on stderr"

# File exists → exit 0, no stdout output
tmpfile="$(mktemp)"
trap 'rm -f "$tmpfile"' EXIT
set +e
exists_out="$(bash -c ". '$HELPER'; handle_missing_file '$tmpfile' GAIA_TEST_STRICT 'notice' label" 2>/dev/null)"
exists_rc=$?
set -e
assert_eq_exit 0 $exists_rc "helper returns exit 0 when file exists"
assert_not_contains "$exists_out" "notice" "helper prints nothing when file exists"

echo "== next-step.sh refactor (AC2, AC3) =="

# AC2 — next-step.sh must source the shared helper (not re-implement)
ns_body="$(cat "$NS")"
assert_contains "$ns_body" "missing-file-fallback.sh" "AC2 next-step.sh references the shared helper file"
assert_contains "$ns_body" "handle_missing_file" "AC2 next-step.sh invokes handle_missing_file"

# AC3 — graceful behavior preserved: missing manifests under native plugin,
# strict var unset → exit 0 + fallback notice on stdout.
# Simulate by pointing resolve-config.sh to a temp dir with no manifests.
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP" "$tmpfile"' EXIT

# Stub resolve-config.sh that points installed_path to a manifest-less dir
cat >"$TMP/resolve-config.sh" <<EOF
#!/usr/bin/env bash
echo "installed_path='$TMP/_gaia'"
EOF
chmod +x "$TMP/resolve-config.sh"
mkdir -p "$TMP/_gaia/_config"
# Intentionally leave _config empty — no lifecycle-sequence.yaml, no manifest.

# Copy next-step.sh + helper into the tmp dir so relative-path fallbacks fail too
mkdir -p "$TMP/scripts/lib"
cp "$NS" "$TMP/scripts/next-step.sh"
cp "$HELPER" "$TMP/scripts/lib/missing-file-fallback.sh"
chmod +x "$TMP/scripts/next-step.sh"

# Run via PATH override so the script finds our stub resolver first
set +e
graceful_ns_out="$(PATH="$TMP:$PATH" "$TMP/scripts/next-step.sh" --workflow create-story 2>&1)"
graceful_ns_rc=$?
set -e
assert_eq_exit 0 $graceful_ns_rc "AC3 next-step.sh graceful mode exits 0 when manifests missing"
assert_contains "$graceful_ns_out" "legacy manifests not available" "AC3 next-step.sh prints graceful notice"

# AC3 — strict mode preserved: GAIA_NEXT_STEP_STRICT=1 + manifests missing → exit 2
set +e
strict_ns_err="$(PATH="$TMP:$PATH" GAIA_NEXT_STEP_STRICT=1 "$TMP/scripts/next-step.sh" --workflow create-story 2>&1)"
strict_ns_rc=$?
set -e
assert_eq_exit 2 $strict_ns_rc "AC3 next-step.sh strict mode exits 2 when manifests missing"
assert_contains "$strict_ns_err" "not found" "AC3 next-step.sh strict mode prints error on stderr"

echo ""
echo "== summary =="
echo "  passed: $PASS"
echo "  failed: $FAIL"

if [ "$FAIL" -gt 0 ]; then exit 1; fi
exit 0
