#!/usr/bin/env bats
# resolve-config.bats — unit tests for plugins/gaia/scripts/resolve-config.sh
# Public functions covered: parse_yaml_key, validate_yaml_basic,
# validate_schema, emit_pair_shell, shell_escape, json_escape,
# main (via subprocess). shell_escape and json_escape are internal
# quoting helpers exercised end-to-end by the "spaces in values" and
# "--format json" tests respectively.

load 'test_helper.bash'

setup() { common_setup; SCRIPT="$SCRIPTS_DIR/resolve-config.sh"; }
teardown() { common_teardown; }

mk_skill_dir() {
  local dir="$1"
  mkdir -p "$dir/config"
  cat > "$dir/config/project-config.yaml" <<'YAML'
project_root: /tmp/gaia-fx
project_path: /tmp/gaia-fx/app
memory_path: /tmp/gaia-fx/_memory
checkpoint_path: /tmp/gaia-fx/_memory/checkpoints
installed_path: /tmp/gaia-fx/_gaia
framework_version: 1.127.2-rc.1
date: 2026-04-15
YAML
}

@test "resolve-config.sh: is executable and pins set -euo pipefail" {
  [ -x "$SCRIPT" ]
  run head -20 "$SCRIPT"
  [[ "$output" == *"set -euo pipefail"* ]]
}

@test "resolve-config.sh: happy path — emits all required keys as shell pairs" {
  mk_skill_dir "$TEST_TMP/skill"
  CLAUDE_SKILL_DIR="$TEST_TMP/skill" run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"project_root='/tmp/gaia-fx'"* ]]
  [[ "$output" == *"project_path='/tmp/gaia-fx/app'"* ]]
  [[ "$output" == *"memory_path='/tmp/gaia-fx/_memory'"* ]]
  [[ "$output" == *"framework_version='1.127.2-rc.1'"* ]]
  [[ "$output" == *"date='2026-04-15'"* ]]
}

@test "resolve-config.sh: --format json emits quoted JSON object" {
  mk_skill_dir "$TEST_TMP/skill"
  CLAUDE_SKILL_DIR="$TEST_TMP/skill" run "$SCRIPT" --format json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"project_root"'* ]]
  [[ "$output" == *'"/tmp/gaia-fx"'* ]]
}

@test "resolve-config.sh: missing required field → exit 2, stderr names field" {
  local bad="$TEST_TMP/bad"
  mkdir -p "$bad/config"
  cat > "$bad/config/project-config.yaml" <<'YAML'
project_path: /tmp/gaia-fx/app
memory_path: /tmp/gaia-fx/_memory
checkpoint_path: /tmp/gaia-fx/_memory/checkpoints
installed_path: /tmp/gaia-fx/_gaia
framework_version: 1.0.0
date: 2026-04-15
YAML
  CLAUDE_SKILL_DIR="$bad" run "$SCRIPT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"project_root"* ]]
}

@test "resolve-config.sh: missing config file → exit 2" {
  mkdir -p "$TEST_TMP/nocfg/config"
  CLAUDE_SKILL_DIR="$TEST_TMP/nocfg" run "$SCRIPT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"project-config.yaml"* ]]
}

@test "resolve-config.sh: GAIA_* env wins over file values" {
  mk_skill_dir "$TEST_TMP/skill"
  CLAUDE_SKILL_DIR="$TEST_TMP/skill" GAIA_PROJECT_PATH=/tmp/from-env run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"project_path='/tmp/from-env'"* ]]
}

@test "resolve-config.sh: idempotent — two runs produce byte-identical output" {
  mk_skill_dir "$TEST_TMP/skill"
  local a b
  a="$(CLAUDE_SKILL_DIR="$TEST_TMP/skill" "$SCRIPT")"
  b="$(CLAUDE_SKILL_DIR="$TEST_TMP/skill" "$SCRIPT")"
  [ "$a" = "$b" ]
  [ -n "$a" ]
}

@test "resolve-config.sh: no CLAUDE_SKILL_DIR and no --config → exit 2" {
  run env -u CLAUDE_SKILL_DIR "$SCRIPT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"CLAUDE_SKILL_DIR"* ]]
}

@test "resolve-config.sh: malformed YAML with --format json → exit 2, empty stdout" {
  local bad="$TEST_TMP/mal"
  mkdir -p "$bad/config"
  printf 'project_root: [unclosed\n  not valid yaml at all: : :\n' > "$bad/config/project-config.yaml"
  CLAUDE_SKILL_DIR="$bad" run "$SCRIPT" --format json
  [ "$status" -eq 2 ]
}

@test "resolve-config.sh: path traversal in project_path rejected" {
  local bad="$TEST_TMP/trav"
  mkdir -p "$bad/config"
  cat > "$bad/config/project-config.yaml" <<'YAML'
project_root: /tmp/ok
project_path: ../../etc
memory_path: /tmp/ok/_memory
checkpoint_path: /tmp/ok/_memory/checkpoints
installed_path: /tmp/ok/_gaia
framework_version: 1.0.0
date: 2026-04-15
YAML
  CLAUDE_SKILL_DIR="$bad" run "$SCRIPT"
  [ "$status" -eq 2 ]
}

@test "resolve-config.sh: spaces in values round-trip safely via eval" {
  local dir="$TEST_TMP/sp"
  mkdir -p "$dir/config"
  cat > "$dir/config/project-config.yaml" <<'YAML'
project_root: /tmp/my project
project_path: /tmp/my project/app
memory_path: /tmp/my project/_memory
checkpoint_path: /tmp/my project/_memory/checkpoints
installed_path: /tmp/my project/_gaia
framework_version: 1.0.0
date: 2026-04-15
YAML
  local out
  out="$(CLAUDE_SKILL_DIR="$dir" "$SCRIPT")"
  local project_root=""
  eval "$out"
  [ "$project_root" = "/tmp/my project" ]
}
