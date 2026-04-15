#!/usr/bin/env bats
# next-step.bats — unit tests for plugins/gaia/scripts/next-step.sh
# Public functions covered: resolve_paths, manifest_has_command, add_line,
# add_command, read_yq, main (static contract only — yaml-driven happy paths
# require yq + fixtures and are covered once yq is pinned in the CI image).

load 'test_helper.bash'

setup() { common_setup; SCRIPT="$SCRIPTS_DIR/next-step.sh"; }
teardown() { common_teardown; }

@test "next-step.sh: --help exits 0" {
  run "$SCRIPT" --help
  [ "$status" -eq 0 ]
}

@test "next-step.sh: missing --workflow exits 1" {
  run "$SCRIPT"
  [ "$status" -eq 1 ]
}

@test "next-step.sh: invalid --status rejected" {
  run "$SCRIPT" --status banana --workflow x
  [ "$status" -eq 1 ]
}

@test "next-step.sh: --status pass accepted (arg parse only)" {
  # argument-parsing contract: --status pass is valid; we don't require a
  # real yaml/manifest fixture here — the exit will be 2 (internal, missing
  # files) but must not be 1 (usage).
  run "$SCRIPT" --status pass --workflow create-story
  [ "$status" -ne 1 ]
}

@test "next-step.sh: --status fail accepted (arg parse only)" {
  run "$SCRIPT" --status fail --workflow create-story
  [ "$status" -ne 1 ]
}

@test "next-step.sh: --story pass-through does not error on parsing" {
  run "$SCRIPT" --workflow create-story --story E1-S1
  [ "$status" -ne 1 ]
}

@test "next-step.sh: unknown flag rejected" {
  run "$SCRIPT" --workflow create-story --banana
  [ "$status" -ne 0 ]
}
