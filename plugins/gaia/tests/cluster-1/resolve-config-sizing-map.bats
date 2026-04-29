#!/usr/bin/env bats
# resolve-config-sizing-map.bats — E61-S1 / ADR-074 contract C1
#
# Verifies that resolve-config.sh resolves sizing_map with project > global
# precedence per ADR-044 §10.26.3:
#   - Test 1: project-config.yaml sizing_map block overrides global.yaml.
#   - Test 2: project-config.yaml without sizing_map falls back to global.yaml
#             defaults (S=2, M=5, L=8, XL=13).
#
# Mirrors the Cluster 1 fixture pattern (synthetic configs in TEST_TMP/skill,
# CLAUDE_SKILL_DIR-driven discovery; the real repo configs are not touched).

load 'test_helper.bash'

setup() { common_setup; SCRIPT="$SCRIPTS_DIR/resolve-config.sh"; }
teardown() { common_teardown; }

mk_required_fields() {
  # Emit the required-field block to stdout. Reused by both fixture builders
  # so the surface stays consistent — the resolver dies with exit 2 on any
  # missing required field.
  cat <<'YAML'
project_root: /tmp/gaia-szm
project_path: /tmp/gaia-szm/app
memory_path: /tmp/gaia-szm/_memory
checkpoint_path: /tmp/gaia-szm/_memory/checkpoints
installed_path: /tmp/gaia-szm/_gaia
framework_version: 1.127.2-rc.1
date: 2026-04-28
YAML
}

mk_shared_with_sizing_map() {
  # Writes a synthetic shared project-config.yaml with a custom sizing_map
  # block. Custom values are deliberately distinct from global defaults so
  # the override is unambiguously visible in the resolver output.
  local dir="$1"
  mkdir -p "$dir/config"
  {
    mk_required_fields
    cat <<'YAML'
sizing_map:
  S: 1
  M: 3
  L: 5
  XL: 8
YAML
  } > "$dir/config/project-config.yaml"
}

mk_shared_no_sizing_map() {
  # Writes a synthetic shared project-config.yaml with NO sizing_map block.
  local dir="$1"
  mkdir -p "$dir/config"
  mk_required_fields > "$dir/config/project-config.yaml"
}

# ---------------------------------------------------------------------------
# Positional `sizing_map` query (E61-S1 / ADR-074 contract C1)
# Invocation: `resolve-config.sh sizing_map` emits 4 lines: S=…, M=…, L=…, XL=…
# ---------------------------------------------------------------------------

@test "sizing_map (positional): project override wins — custom values returned" {
  mk_shared_with_sizing_map "$TEST_TMP/skill"
  cd "$TEST_TMP"  # PWD must not contain a config/ dir, otherwise L5 wins.
  run env -u CLAUDE_PROJECT_ROOT -u GAIA_SHARED_CONFIG -u GAIA_LOCAL_CONFIG \
    CLAUDE_SKILL_DIR="$TEST_TMP/skill" "$SCRIPT" sizing_map
  [ "$status" -eq 0 ]
  [[ "$output" == *"S=1"* ]]
  [[ "$output" == *"M=3"* ]]
  [[ "$output" == *"L=5"* ]]
  [[ "$output" == *"XL=8"* ]]
}

@test "sizing_map (positional): project unset — falls back to canonical Fibonacci defaults" {
  mk_shared_no_sizing_map "$TEST_TMP/skill"
  cd "$TEST_TMP"  # PWD must not contain a config/ dir, otherwise L5 wins.
  run env -u CLAUDE_PROJECT_ROOT -u GAIA_SHARED_CONFIG -u GAIA_LOCAL_CONFIG \
    CLAUDE_SKILL_DIR="$TEST_TMP/skill" "$SCRIPT" sizing_map
  [ "$status" -eq 0 ]
  [[ "$output" == *"S=2"* ]]
  [[ "$output" == *"M=5"* ]]
  [[ "$output" == *"L=8"* ]]
  [[ "$output" == *"XL=13"* ]]
}

# ---------------------------------------------------------------------------
# Default emit surface (no positional arg) — sizing_map.* keys appear ONLY
# when the project layer set the block. Absent block → no surface pollution.
# Guards the eval-friendly contract for the default emit (existing test
# `resolve-config.sh: spaces in values round-trip safely via eval`).
# ---------------------------------------------------------------------------

@test "sizing_map (default emit): project set → sizing_map.* keys appear in shell output" {
  mk_shared_with_sizing_map "$TEST_TMP/skill"
  cd "$TEST_TMP"
  run env -u CLAUDE_PROJECT_ROOT -u GAIA_SHARED_CONFIG -u GAIA_LOCAL_CONFIG \
    CLAUDE_SKILL_DIR="$TEST_TMP/skill" "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"sizing_map.S='1'"* ]]
  [[ "$output" == *"sizing_map.XL='8'"* ]]
}

@test "sizing_map (default emit): project unset → sizing_map.* keys absent (no surface pollution)" {
  mk_shared_no_sizing_map "$TEST_TMP/skill"
  cd "$TEST_TMP"
  run env -u CLAUDE_PROJECT_ROOT -u GAIA_SHARED_CONFIG -u GAIA_LOCAL_CONFIG \
    CLAUDE_SKILL_DIR="$TEST_TMP/skill" "$SCRIPT"
  [ "$status" -eq 0 ]
  ! [[ "$output" == *"sizing_map."* ]]
}
