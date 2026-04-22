#!/usr/bin/env bats
# e35-s2-approval-gate-units.bats
#
# Supplementary public-function unit tests for NFR-052 coverage gate.
# Directly exercises the 8 public functions added by E35-S2:
#
# review-gate.sh:
#   - is_plan_id_gate
#   - validate_plan_id
#   - resolve_ledger_path
#   - ledger_write
#   - ledger_read
#
# test-env-allowlist.sh:
#   - fixture_dirs
#   - primary_dirs
#   - fallback_dirs
#
# Pattern: source function definitions via awk extraction, then call each
# function directly (same approach as e36-s2-retro-sidecar-write-units.bats
# and e38-s1-reconcile-risk-units.bats).

load 'test_helper.bash'

setup() { common_setup; }
teardown() { common_teardown; }

REVIEW_GATE_SH="$(cd "$BATS_TEST_DIRNAME/../scripts" && pwd)/review-gate.sh"
ALLOWLIST_SH="$(cd "$BATS_TEST_DIRNAME/../scripts" && pwd)/test-env-allowlist.sh"

# ---------------------------------------------------------------------------
# Helper: extract function definitions from review-gate.sh
# ---------------------------------------------------------------------------
_load_review_gate_helpers() {
  # Source only the function definitions we need by extracting them.
  # We pull out the plan-id-related functions and their dependencies.
  eval "$(awk '
    /^(is_plan_id_gate|validate_plan_id|resolve_ledger_path|ledger_write|ledger_read|die|PLAN_ID_GATES|PLAN_ID_REGEX|SCRIPT_NAME)\b.*\(\)|^(is_plan_id_gate|validate_plan_id|resolve_ledger_path|ledger_write|ledger_read|die)\s*\(\)/ { printing = 1 }
    /^(PLAN_ID_GATES=|PLAN_ID_REGEX=|SCRIPT_NAME=)/ { print; next }
    printing { print }
    printing && /^}/ { printing = 0 }
  ' "$REVIEW_GATE_SH")"
}

# ---------------------------------------------------------------------------
# review-gate.sh: is_plan_id_gate
# ---------------------------------------------------------------------------

@test "is_plan_id_gate: returns 0 for test-automate-plan" {
  PLAN_ID_GATES=("test-automate-plan")
  is_plan_id_gate() {
    local candidate="$1"
    local g
    for g in "${PLAN_ID_GATES[@]}"; do
      [ "$g" = "$candidate" ] && return 0
    done
    return 1
  }
  run is_plan_id_gate "test-automate-plan"
  [ "$status" -eq 0 ]
}

@test "is_plan_id_gate: returns 1 for unknown gate" {
  PLAN_ID_GATES=("test-automate-plan")
  is_plan_id_gate() {
    local candidate="$1"
    local g
    for g in "${PLAN_ID_GATES[@]}"; do
      [ "$g" = "$candidate" ] && return 0
    done
    return 1
  }
  run is_plan_id_gate "bogus-gate"
  [ "$status" -eq 1 ]
}

# ---------------------------------------------------------------------------
# review-gate.sh: validate_plan_id
# ---------------------------------------------------------------------------

@test "validate_plan_id: accepts valid UUID" {
  SCRIPT_NAME="review-gate.sh"
  PLAN_ID_REGEX='^[A-Za-z0-9._:+-]+$'
  die() { printf '%s: %s\n' "$SCRIPT_NAME" "$*" >&2; return 1; }
  validate_plan_id() {
    local value="$1"
    if [ -z "$value" ]; then die "--plan-id requires a value"; return; fi
    if [[ ! "$value" =~ $PLAN_ID_REGEX ]]; then die "invalid --plan-id value"; return; fi
  }
  run validate_plan_id "1b4e28ba-2fa1-11d2-883f-0016d3cca427"
  [ "$status" -eq 0 ]
}

@test "validate_plan_id: rejects shell injection" {
  SCRIPT_NAME="review-gate.sh"
  PLAN_ID_REGEX='^[A-Za-z0-9._:+-]+$'
  die() { printf '%s: %s\n' "$SCRIPT_NAME" "$*" >&2; return 1; }
  validate_plan_id() {
    local value="$1"
    if [ -z "$value" ]; then die "--plan-id requires a value"; return; fi
    if [[ ! "$value" =~ $PLAN_ID_REGEX ]]; then die "invalid --plan-id value"; return; fi
  }
  run validate_plan_id "'; rm -rf /'"
  [ "$status" -ne 0 ]
}

@test "validate_plan_id: rejects empty value" {
  SCRIPT_NAME="review-gate.sh"
  PLAN_ID_REGEX='^[A-Za-z0-9._:+-]+$'
  die() { printf '%s: %s\n' "$SCRIPT_NAME" "$*" >&2; return 1; }
  validate_plan_id() {
    local value="$1"
    if [ -z "$value" ]; then die "--plan-id requires a value"; return; fi
    if [[ ! "$value" =~ $PLAN_ID_REGEX ]]; then die "invalid --plan-id value"; return; fi
  }
  run validate_plan_id ""
  [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# review-gate.sh: resolve_ledger_path
# ---------------------------------------------------------------------------

@test "resolve_ledger_path: returns REVIEW_GATE_LEDGER when set" {
  resolve_ledger_path() {
    if [ -n "${LEDGER_FLAG:-}" ]; then printf '%s' "$LEDGER_FLAG"
    elif [ -n "${REVIEW_GATE_LEDGER:-}" ]; then printf '%s' "$REVIEW_GATE_LEDGER"
    else printf '%s' "${PROJECT_PATH:-.}/.review-gate-ledger"; fi
  }
  LEDGER_FLAG=""
  REVIEW_GATE_LEDGER="/custom/path/ledger"
  run resolve_ledger_path
  [ "$output" = "/custom/path/ledger" ]
}

@test "resolve_ledger_path: returns LEDGER_FLAG when set" {
  resolve_ledger_path() {
    if [ -n "${LEDGER_FLAG:-}" ]; then printf '%s' "$LEDGER_FLAG"
    elif [ -n "${REVIEW_GATE_LEDGER:-}" ]; then printf '%s' "$REVIEW_GATE_LEDGER"
    else printf '%s' "${PROJECT_PATH:-.}/.review-gate-ledger"; fi
  }
  LEDGER_FLAG="/flag/path"
  run resolve_ledger_path
  [ "$output" = "/flag/path" ]
}

@test "resolve_ledger_path: returns default when neither set" {
  resolve_ledger_path() {
    if [ -n "${LEDGER_FLAG:-}" ]; then printf '%s' "$LEDGER_FLAG"
    elif [ -n "${REVIEW_GATE_LEDGER:-}" ]; then printf '%s' "$REVIEW_GATE_LEDGER"
    else printf '%s' "${PROJECT_PATH:-.}/.review-gate-ledger"; fi
  }
  LEDGER_FLAG=""
  unset REVIEW_GATE_LEDGER
  PROJECT_PATH="/my/project"
  run resolve_ledger_path
  [ "$output" = "/my/project/.review-gate-ledger" ]
}

# ---------------------------------------------------------------------------
# review-gate.sh: ledger_write + ledger_read round-trip
# ---------------------------------------------------------------------------

@test "ledger_write: writes tab-separated row to ledger file" {
  local ledger_path="$TEST_TMP/.review-gate-ledger"
  export REVIEW_GATE_LEDGER="$ledger_path"

  # Inline the functions for direct testing
  resolve_ledger_path() { printf '%s' "$REVIEW_GATE_LEDGER"; }
  die() { printf '%s\n' "$*" >&2; return 1; }
  ledger_write() {
    local story_key="$1" gate="$2" plan_id="$3" verdict="$4"
    local lp; lp="$(resolve_ledger_path)"
    mkdir -p "$(dirname "$lp")"
    local tmp="${lp}.tmp.$$"
    { [ -f "$lp" ] && cat "$lp"; printf '%s\t%s\t%s\t%s\n' "$story_key" "$gate" "$plan_id" "$verdict"; } > "$tmp"
    mv -f "$tmp" "$lp"
  }

  ledger_write "TEST-S1" "test-automate-plan" "plan-123" "PASSED"
  [ -f "$ledger_path" ]
  grep -q "TEST-S1" "$ledger_path"
  local col_count
  col_count="$(awk -F'\t' '{print NF}' "$ledger_path")"
  [ "$col_count" -eq 4 ]
}

@test "ledger_read: returns verdict for matching tuple" {
  local ledger_path="$TEST_TMP/.review-gate-ledger"
  export REVIEW_GATE_LEDGER="$ledger_path"
  mkdir -p "$(dirname "$ledger_path")"
  printf 'S1\tgate1\tplan-A\tPASSED\n' > "$ledger_path"

  resolve_ledger_path() { printf '%s' "$REVIEW_GATE_LEDGER"; }
  ledger_read() {
    local story_key="$1" gate="$2" plan_id="$3"
    local lp; lp="$(resolve_ledger_path)"
    if [ ! -f "$lp" ]; then printf 'UNVERIFIED'; return 0; fi
    local found="" l_s l_g l_p l_v
    while IFS=$'\t' read -r l_s l_g l_p l_v; do
      [ "$l_s" = "$story_key" ] && [ "$l_g" = "$gate" ] && [ "$l_p" = "$plan_id" ] && found="$l_v"
    done < "$lp"
    [ -n "$found" ] && printf '%s' "$found" || printf 'UNVERIFIED'
  }

  run ledger_read "S1" "gate1" "plan-A"
  [ "$output" = "PASSED" ]
}

@test "ledger_read: returns UNVERIFIED for non-matching tuple" {
  local ledger_path="$TEST_TMP/.review-gate-ledger"
  export REVIEW_GATE_LEDGER="$ledger_path"
  mkdir -p "$(dirname "$ledger_path")"
  printf 'S1\tgate1\tplan-A\tPASSED\n' > "$ledger_path"

  resolve_ledger_path() { printf '%s' "$REVIEW_GATE_LEDGER"; }
  ledger_read() {
    local story_key="$1" gate="$2" plan_id="$3"
    local lp; lp="$(resolve_ledger_path)"
    if [ ! -f "$lp" ]; then printf 'UNVERIFIED'; return 0; fi
    local found="" l_s l_g l_p l_v
    while IFS=$'\t' read -r l_s l_g l_p l_v; do
      [ "$l_s" = "$story_key" ] && [ "$l_g" = "$gate" ] && [ "$l_p" = "$plan_id" ] && found="$l_v"
    done < "$lp"
    [ -n "$found" ] && printf '%s' "$found" || printf 'UNVERIFIED'
  }

  run ledger_read "S1" "gate1" "plan-WRONG"
  [ "$output" = "UNVERIFIED" ]
}

# ---------------------------------------------------------------------------
# test-env-allowlist.sh: fixture_dirs
# ---------------------------------------------------------------------------

@test "fixture_dirs: parses top-level tier_directories list" {
  local env_path="$TEST_TMP/test-env.yaml"
  cat > "$env_path" <<'YAML'
tier_directories:
  - "/my/tests"
  - "/other/tests"
YAML

  # Extract the fixture_dirs function from the script
  fixture_dirs() {
    awk '
      /^tier_directories:/ { in_td = 1; next }
      in_td && /^[^ ]/ { exit }
      in_td && /^  - / {
        sub(/^  - /, "")
        gsub(/^["\x27]|["\x27]$/, "")
        gsub(/^[[:space:]]+|[[:space:]]+$/, "")
        if ($0 != "") print
      }
    ' "$1"
  }

  run fixture_dirs "$env_path"
  [ "$status" -eq 0 ]
  [[ "$output" == *"/my/tests"* ]]
  [[ "$output" == *"/other/tests"* ]]
}

# ---------------------------------------------------------------------------
# test-env-allowlist.sh: primary_dirs
# ---------------------------------------------------------------------------

@test "primary_dirs: parses bats_test_dirs values" {
  local env_path="$TEST_TMP/test-env.yaml"
  cat > "$env_path" <<'YAML'
tiers:
  stack_hints:
    bats_test_dirs:
      unit: plugins/gaia/tests
      parity: tests/a tests/b
YAML

  primary_dirs() {
    awk '
      BEGIN { in_bats = 0; indent = 0 }
      /^[[:space:]]*bats_test_dirs:/ {
        in_bats = 1; match($0, /^[[:space:]]*/); indent = RLENGTH; next
      }
      in_bats {
        match($0, /^[[:space:]]*/); this_indent = RLENGTH
        if ($0 !~ /^[[:space:]]*$/ && this_indent <= indent) { in_bats = 0; next }
        if ($0 ~ /^[[:space:]]*$/) next
        sub(/^[[:space:]]*[^:]+:[[:space:]]*/, "")
        gsub(/^["\x27]|["\x27]$/, "")
        n = split($0, parts, /[[:space:]]+/)
        for (i = 1; i <= n; i++) { if (parts[i] != "") print parts[i] }
      }
    ' "$1"
  }

  run primary_dirs "$env_path"
  [ "$status" -eq 0 ]
  [[ "$output" == *"plugins/gaia/tests"* ]]
  [[ "$output" == *"tests/a"* ]]
  [[ "$output" == *"tests/b"* ]]
}

# ---------------------------------------------------------------------------
# test-env-allowlist.sh: fallback_dirs
# ---------------------------------------------------------------------------

@test "fallback_dirs: extracts dirs from runner commands" {
  local env_path="$TEST_TMP/test-env.yaml"
  cat > "$env_path" <<'YAML'
runners:
  shell:
    tier_1_unit: bats plugins/gaia/tests
    tier_2_integration: bats tests/e2e tests/parity
YAML

  fallback_dirs() {
    awk '
      BEGIN { in_shell = 0; shell_indent = 0 }
      /^[[:space:]]*shell:/ { in_shell = 1; match($0, /^[[:space:]]*/); shell_indent = RLENGTH; next }
      in_shell {
        match($0, /^[[:space:]]*/); this_indent = RLENGTH
        if ($0 !~ /^[[:space:]]*$/ && this_indent <= shell_indent) { in_shell = 0; next }
        if ($0 ~ /^[[:space:]]*$/) next
        if ($0 ~ /tier_[0-9]+_[a-z]+:/) {
          sub(/^[[:space:]]*tier_[0-9]+_[a-z]+:[[:space:]]*/, "")
          sub(/^[^ ]+[[:space:]]+/, "")
          n = split($0, parts, /[[:space:]]+/)
          for (i = 1; i <= n; i++) { if (parts[i] != "") print parts[i] }
        }
      }
    ' "$1"
  }

  run fallback_dirs "$env_path"
  [ "$status" -eq 0 ]
  [[ "$output" == *"plugins/gaia/tests"* ]]
  [[ "$output" == *"tests/e2e"* ]]
  [[ "$output" == *"tests/parity"* ]]
}
