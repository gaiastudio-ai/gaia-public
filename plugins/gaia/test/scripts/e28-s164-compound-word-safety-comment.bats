#!/usr/bin/env bats
# e28-s164-compound-word-safety-comment.bats — bats-core tests for the
# compound-word-safety comment block above the PATTERN assignment in
# dead-reference-scan.sh (E28-S164 AC1 + AC2).
#
# RED phase: the comment block does not yet exist — all tests fail until Step 7
# (Green) inserts the comment block.

PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SCRIPT="$PLUGIN_DIR/scripts/dead-reference-scan.sh"

@test "dead-reference-scan.sh exists and is readable" {
  [ -r "$SCRIPT" ]
}

@test "AC1 — comment block above PATTERN explains (^|[^-a-z]) anchor convention" {
  # Extract the lines ending at (but not including) the PATTERN= assignment and
  # scan the window directly above it for the explanation.
  run awk '
    /^PATTERN=/ { exit }
    { print }
  ' "$SCRIPT"
  [ "$status" -eq 0 ]

  # The window must mention the compound-word-safety anchor explicitly.
  [[ "$output" == *'(^|[^-a-z])'* ]]
  # And it must call it out as a "compound-word" convention (AC1 intent).
  [[ "$output" == *'compound-word'* ]]
}

@test "AC2 — comment includes a concrete example showing the compound-word risk" {
  run awk '
    /^PATTERN=/ { exit }
    { print }
  ' "$SCRIPT"
  [ "$status" -eq 0 ]

  # A concrete compound-word example must appear somewhere in the comment block.
  # The canonical example from the story is "agent-manifest.yaml" which would
  # false-positive on a naked "manifest.yaml" search without the anchor.
  [[ "$output" == *'agent-manifest.yaml'* ]]
  [[ "$output" == *'manifest.yaml'* ]]
}

@test "comment block is positioned immediately above PATTERN= line" {
  # Find the PATTERN= line number and verify the line immediately above it is a
  # comment (starts with '#'), i.e., the comment block is contiguous with PATTERN.
  local pattern_line
  pattern_line=$(grep -n '^PATTERN=' "$SCRIPT" | head -1 | cut -d: -f1)
  [ -n "$pattern_line" ]
  local prev_line_num=$((pattern_line - 1))
  local prev_line
  prev_line=$(sed -n "${prev_line_num}p" "$SCRIPT")
  [[ "$prev_line" =~ ^\# ]]
}
