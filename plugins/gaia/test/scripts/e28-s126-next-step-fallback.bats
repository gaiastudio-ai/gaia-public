#!/usr/bin/env bats
# e28-s126-next-step-fallback.bats — bats-core tests for the graceful-missing-file
# fallback added to next-step.sh (Val v1 Finding 2 / E28-S126 AC6).
#
# Context: before this PR, next-step.sh hard-failed (exit 2) when lifecycle-sequence.yaml or
# workflow-manifest.csv were absent. Post-cleanup those files are gone under the native plugin,
# so next-step.sh must degrade gracefully: print a clear "not available under native plugin"
# message and exit 0.
#
# RED phase: next-step.sh currently returns 2 on missing manifests; these tests fail until
# Step 7 (Green) adds the fallback.

PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SCRIPTS_DIR="$PLUGIN_DIR/scripts"
SCRIPT="$SCRIPTS_DIR/next-step.sh"

setup() {
  TMP="$(mktemp -d)"
  # Simulate a native-plugin install with no legacy manifests.
  mkdir -p "$TMP/plugins/gaia/scripts"
  mkdir -p "$TMP/_gaia/_config"
  # Intentionally do NOT create lifecycle-sequence.yaml or workflow-manifest.csv.
}

teardown() {
  [ -n "$TMP" ] && [ -d "$TMP" ] && rm -rf "$TMP"
}

@test "next-step.sh exists and is executable" {
  [ -x "$SCRIPT" ]
}

@test "missing lifecycle-sequence.yaml — exits 0 with 'not available' message" {
  # Run next-step.sh from inside the mock install so its path-discovery finds nothing.
  cd "$TMP"
  run "$SCRIPT" --workflow create-story
  [ "$status" -eq 0 ]
  [[ "$output" == *"not available"* || "$output" == *"native plugin"* || "$output" == *"legacy"* ]]
}

@test "missing workflow-manifest.csv — exits 0 with 'not available' message" {
  # Add lifecycle-sequence.yaml but NOT workflow-manifest.csv
  cat > "$TMP/_gaia/_config/lifecycle-sequence.yaml" <<EOF
phases: []
EOF
  cd "$TMP"
  run "$SCRIPT" --workflow create-story
  [ "$status" -eq 0 ]
  [[ "$output" == *"not available"* || "$output" == *"native plugin"* || "$output" == *"legacy"* ]]
}

@test "strict mode preserved via GAIA_NEXT_STEP_STRICT=1 — exits 2" {
  cd "$TMP"
  GAIA_NEXT_STEP_STRICT=1 run "$SCRIPT" --workflow create-story
  [ "$status" -eq 2 ]
}
