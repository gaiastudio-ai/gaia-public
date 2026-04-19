#!/usr/bin/env bats
# e28-s126-cleanup-legacy-engine.bats — bats-core tests for the migration CLI
# gaia-cleanup-legacy-engine.sh (E28-S126 Task 5 / AC1..AC5 / AC-EC1..AC-EC8).
#
# RED phase: script does not yet exist — all tests fail until Step 7 (Green) implements it.

PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SCRIPTS_DIR="$PLUGIN_DIR/scripts"
FIXTURES_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/fixtures/e28-s126" && pwd)"
SCRIPT="$SCRIPTS_DIR/gaia-cleanup-legacy-engine.sh"
GATES_OK="$FIXTURES_DIR/gates-all-passed"

# Copy the legacy-tree fixture to a temp dir so each test runs against a clean writable tree.
setup() {
  TMP="$(mktemp -d)"
  cp -R "$FIXTURES_DIR/legacy-tree/." "$TMP/"
  # Copy gate stories into TMP so verify-cluster-gates can run there too.
  mkdir -p "$TMP/docs/implementation-artifacts"
  cp "$GATES_OK/docs/implementation-artifacts/"*.md "$TMP/docs/implementation-artifacts/"
  # Remove the in-flight checkpoint by default; tests that need it re-create it.
  rm -f "$TMP/_memory/checkpoints/dev-story-E28-DEMO.yaml"
}

teardown() {
  [ -n "$TMP" ] && [ -d "$TMP" ] && rm -rf "$TMP"
}

@test "gaia-cleanup-legacy-engine.sh exists and is executable" {
  [ -x "$SCRIPT" ]
}

@test "--dry-run prints manifest and modifies nothing (AC: dry-run)" {
  local before
  before="$(find "$TMP/_gaia" -type f | sort)"
  run "$SCRIPT" --project-root "$TMP" --dry-run --force-dirty
  [ "$status" -eq 0 ]
  [[ "$output" == *"workflow.xml"* ]]
  local after
  after="$(find "$TMP/_gaia" -type f | sort)"
  [ "$before" = "$after" ]
}

@test "happy path — removes engine, protocols, .resolved, module configs, manifests (AC1–AC5)" {
  run "$SCRIPT" --project-root "$TMP" --force-dirty
  [ "$status" -eq 0 ]
  # AC1 — engine gone
  [ ! -e "$TMP/_gaia/core/engine/workflow.xml" ]
  [ ! -e "$TMP/_gaia/core/engine/error-recovery.xml" ]
  [ ! -e "$TMP/_gaia/core/engine/task-runner.xml" ]
  # AC2 — protocols gone
  [ ! -d "$TMP/_gaia/core/protocols" ]
  # AC3 — all .resolved/ gone including nested
  [ -z "$(find "$TMP/_gaia" -type d -name .resolved 2>/dev/null)" ]
  # AC4 — five module configs gone
  [ ! -e "$TMP/_gaia/core/config.yaml" ]
  [ ! -e "$TMP/_gaia/lifecycle/config.yaml" ]
  [ ! -e "$TMP/_gaia/dev/config.yaml" ]
  [ ! -e "$TMP/_gaia/creative/config.yaml" ]
  [ ! -e "$TMP/_gaia/testing/config.yaml" ]
  # AC5 — four _config manifests gone
  [ ! -e "$TMP/_gaia/_config/lifecycle-sequence.yaml" ]
  [ ! -e "$TMP/_gaia/_config/workflow-manifest.csv" ]
  [ ! -e "$TMP/_gaia/_config/task-manifest.csv" ]
  [ ! -e "$TMP/_gaia/_config/skill-manifest.csv" ]
}

@test "survivors preserved — global.yaml, agent-manifest.csv, files-manifest.csv, gaia-help.csv" {
  run "$SCRIPT" --project-root "$TMP" --force-dirty
  [ "$status" -eq 0 ]
  [ -f "$TMP/_gaia/_config/global.yaml" ]
  [ -f "$TMP/_gaia/_config/agent-manifest.csv" ]
  [ -f "$TMP/_gaia/_config/files-manifest.csv" ]
  [ -f "$TMP/_gaia/_config/gaia-help.csv" ]
}

@test "idempotent re-run — second invocation exits 0 with nothing to delete (AC-EC3)" {
  "$SCRIPT" --project-root "$TMP" --force-dirty
  run "$SCRIPT" --project-root "$TMP" --force-dirty
  [ "$status" -eq 0 ]
}

@test "nested .resolved/ (depth 5) is removed (AC-EC5)" {
  run "$SCRIPT" --project-root "$TMP" --force-dirty
  [ "$status" -eq 0 ]
  [ ! -e "$TMP/_gaia/dev/skills/deeply/nested/.resolved/deep.yaml" ]
}

@test "in-flight legacy-engine checkpoint halts execution (AC-EC2)" {
  # Re-create the in-flight checkpoint referencing the legacy engine.
  cat > "$TMP/_memory/checkpoints/dev-story-E28-DEMO.yaml" <<EOF
workflow: dev-story
loaded: _gaia/core/engine/workflow.xml
EOF
  run "$SCRIPT" --project-root "$TMP" --force-dirty
  # Must be a real refusal (1-99), not "command not found" (127) or segfault-like (>=128)
  [ "$status" -ge 1 ] && [ "$status" -lt 127 ]
  [[ "$output" == *"checkpoint"* || "$output" == *"in-flight"* ]]
  # And the engine files must still be present (no partial deletion)
  [ -e "$TMP/_gaia/core/engine/workflow.xml" ]
}

@test "cluster-gate failure blocks deletion (AC-EC4)" {
  rm -rf "$TMP/docs/implementation-artifacts"
  mkdir -p "$TMP/docs/implementation-artifacts"
  cp "$FIXTURES_DIR/gates-one-failed/docs/implementation-artifacts/"*.md "$TMP/docs/implementation-artifacts/"
  run "$SCRIPT" --project-root "$TMP" --force-dirty
  [ "$status" -ge 1 ] && [ "$status" -lt 127 ]
  [[ "$output" == *"E28-S136"* || "$output" == *"gate"* || "$output" == *"PASSED"* ]]
  [ -e "$TMP/_gaia/core/engine/workflow.xml" ]  # no deletion
}

@test "dirty working tree without --force-dirty refuses to run (AC-EC8)" {
  # Initialize a git repo with a dirty _gaia/ file.
  ( cd "$TMP" && git init -q && git add -A && git -c user.email=t@t -c user.name=t commit -q -m init )
  echo "dirty" >> "$TMP/_gaia/core/engine/workflow.xml"
  run "$SCRIPT" --project-root "$TMP"
  [ "$status" -ge 1 ] && [ "$status" -lt 127 ]
  [[ "$output" == *"dirty"* || "$output" == *"uncommitted"* ]]
  [ -e "$TMP/_gaia/core/engine/workflow.xml" ]
}

@test "--force-dirty bypass lets cleanup run on dirty tree" {
  ( cd "$TMP" && git init -q && git add -A && git -c user.email=t@t -c user.name=t commit -q -m init )
  echo "dirty" >> "$TMP/_gaia/core/engine/workflow.xml"
  run "$SCRIPT" --project-root "$TMP" --force-dirty
  [ "$status" -eq 0 ]
  [ ! -e "$TMP/_gaia/core/engine/workflow.xml" ]
}

@test "locked (read-only) path aborts with non-zero exit (AC-EC1)" {
  # Make the engine dir read-only so rm cannot proceed.
  chmod -w "$TMP/_gaia/core/engine"
  run "$SCRIPT" --project-root "$TMP" --force-dirty
  chmod +w "$TMP/_gaia/core/engine"  # restore before teardown
  [ "$status" -ge 1 ] && [ "$status" -lt 127 ]
  # Offending path must be surfaced in output
  [[ "$output" == *"engine"* || "$output" == *"permission"* || "$output" == *"denied"* || "$output" == *"locked"* ]]
}

@test "missing --project-root — usage and non-zero exit" {
  run "$SCRIPT"
  [ "$status" -ge 1 ] && [ "$status" -lt 127 ]
  [[ "$output" == *"project-root"* || "$output" == *"usage"* || "$output" == *"Usage"* ]]
}
