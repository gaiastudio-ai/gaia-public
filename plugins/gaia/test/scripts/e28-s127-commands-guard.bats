#!/usr/bin/env bats
# e28-s127-commands-guard.bats — bats-core tests for the FR-329 regression guard
# commands-guard.sh (E28-S127 Task 6 / AC5).
#
# RED phase: script does not yet exist — tests fail until Step 7 (Green) implements it.

PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SCRIPTS_DIR="$PLUGIN_DIR/scripts"
SCRIPT="$SCRIPTS_DIR/commands-guard.sh"

setup() {
  TMP="$(mktemp -d)"
  mkdir -p "$TMP/plugins/gaia"
}

teardown() {
  [ -n "$TMP" ] && [ -d "$TMP" ] && rm -rf "$TMP"
}

@test "commands-guard.sh exists and is executable" {
  [ -x "$SCRIPT" ]
}

@test "clean tree — commands/ directory absent (exit 0)" {
  run "$SCRIPT" --project-root "$TMP"
  [ "$status" -eq 0 ]
}

@test "clean tree — commands/ exists but empty (exit 0)" {
  mkdir -p "$TMP/plugins/gaia/commands"
  run "$SCRIPT" --project-root "$TMP"
  [ "$status" -eq 0 ]
}

@test "clean tree — commands/ contains only non-gaia file (exit 0)" {
  mkdir -p "$TMP/plugins/gaia/commands"
  echo "readme" > "$TMP/plugins/gaia/commands/README.md"
  run "$SCRIPT" --project-root "$TMP"
  [ "$status" -eq 0 ]
}

@test "regression — single gaia-*.md triggers failure with offending path (exit 1)" {
  mkdir -p "$TMP/plugins/gaia/commands"
  echo "legacy" > "$TMP/plugins/gaia/commands/gaia-foo.md"
  run "$SCRIPT" --project-root "$TMP"
  [ "$status" -ge 1 ] && [ "$status" -lt 127 ]
  [[ "$output" == *"gaia-foo.md"* ]]
  [[ "$output" == *"FR-329"* || "$output" == *"commands"* ]]
}

@test "regression — mixed tree only flags gaia-*.md files (exit 1)" {
  mkdir -p "$TMP/plugins/gaia/commands"
  echo "legacy" > "$TMP/plugins/gaia/commands/gaia-dev-story.md"
  echo "readme" > "$TMP/plugins/gaia/commands/README.md"
  run "$SCRIPT" --project-root "$TMP"
  [ "$status" -ge 1 ] && [ "$status" -lt 127 ]
  [[ "$output" == *"gaia-dev-story.md"* ]]
  # README should NOT appear in the output as an offender
  ! [[ "$output" == *"flagged: README.md"* ]]
}

@test "regression — multiple gaia files all surfaced (exit 1)" {
  mkdir -p "$TMP/plugins/gaia/commands"
  echo "1" > "$TMP/plugins/gaia/commands/gaia-a.md"
  echo "2" > "$TMP/plugins/gaia/commands/gaia-b.md"
  run "$SCRIPT" --project-root "$TMP"
  [ "$status" -ge 1 ] && [ "$status" -lt 127 ]
  [[ "$output" == *"gaia-a.md"* ]]
  [[ "$output" == *"gaia-b.md"* ]]
}

@test "missing --project-root arg — usage (exit 64)" {
  run "$SCRIPT"
  [ "$status" -eq 64 ]
  [[ "$output" == *"project-root"* || "$output" == *"usage"* || "$output" == *"Usage"* ]]
}

@test "non-existent --project-root — exit 64" {
  run "$SCRIPT" --project-root "/nonexistent/path/12345"
  [ "$status" -eq 64 ]
}
