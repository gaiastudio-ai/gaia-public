#!/usr/bin/env bats
# template-header.bats — unit tests for plugins/gaia/scripts/template-header.sh
# Public functions covered: sq_escape, resolve_framework_version, iso_date,
# main.

load 'test_helper.bash'

setup() { common_setup; SCRIPT="$SCRIPTS_DIR/template-header.sh"; }
teardown() { common_teardown; }

@test "template-header.sh: --help exits 0" {
  run "$SCRIPT" --help
  [ "$status" -eq 0 ]
}

@test "template-header.sh: happy path emits fixed four-key header" {
  run "$SCRIPT" --template story --workflow create-story --var foo=bar
  [ "$status" -eq 0 ]
  [[ "$output" == *"workflow: create-story"* ]]
  [[ "$output" == *"template: story"* ]]
  [[ "$output" == *"framework_version: "* ]]
  [[ "$output" == *"foo: 'bar'"* ]]
}

@test "template-header.sh: --var keys rendered in sorted order" {
  run "$SCRIPT" --template story --workflow create-story --var beta=2 --var alpha=1
  [ "$status" -eq 0 ]
  local expected
  expected=$(printf "alpha: '1'\nbeta: '2'")
  [[ "$output" == *"$expected"* ]]
}

@test "template-header.sh: shell metachars in --var values rendered literally" {
  run "$SCRIPT" --template story --workflow create-story --var "foo=\$(rm -rf /)"
  [ "$status" -eq 0 ]
  [[ "$output" == *"foo: '\$(rm -rf /)'"* ]]
}

@test "template-header.sh: empty --var key exits 1" {
  run "$SCRIPT" --template story --workflow create-story --var =bar
  [ "$status" -eq 1 ]
  [[ "$output" == *"key is empty"* ]]
}

@test "template-header.sh: non-identifier --var key rejected" {
  run "$SCRIPT" --template story --workflow create-story --var "bad-key=x"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not a valid identifier"* ]]
}

@test "template-header.sh: missing --workflow exits 1" {
  run "$SCRIPT" --template story
  [ "$status" -eq 1 ]
}

@test "template-header.sh: idempotent with SOURCE_DATE_EPOCH pinned" {
  local a b
  a=$(SOURCE_DATE_EPOCH=1700000000 "$SCRIPT" --template story --workflow create-story --var foo=bar)
  b=$(SOURCE_DATE_EPOCH=1700000000 "$SCRIPT" --template story --workflow create-story --var foo=bar)
  [ "$a" = "$b" ]
}

@test "template-header.sh: emits open and close markers" {
  run "$SCRIPT" --template story --workflow create-story
  [ "$status" -eq 0 ]
  [[ "$output" == *"<!-- GAIA template header -->"* ]]
  [[ "$output" == *"<!-- /GAIA template header -->"* ]]
}
