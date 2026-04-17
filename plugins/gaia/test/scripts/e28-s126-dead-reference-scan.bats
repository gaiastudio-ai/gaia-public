#!/usr/bin/env bats
# e28-s126-dead-reference-scan.bats — bats-core tests for the dead-reference-scan.sh
# active-code scanner (E28-S126 Task 3 / AC6 / AC-EC7).
#
# RED phase: script does not yet exist — all tests fail until Step 7 (Green) implements it.

PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SCRIPTS_DIR="$PLUGIN_DIR/scripts"
SCRIPT="$SCRIPTS_DIR/dead-reference-scan.sh"

setup() {
  TMP="$(mktemp -d)"
  mkdir -p "$TMP/plugins/gaia/skills/fake-skill" \
           "$TMP/plugins/gaia/scripts" \
           "$TMP/plugins/gaia/agents" \
           "$TMP/docs"
}

teardown() {
  [ -n "$TMP" ] && [ -d "$TMP" ] && rm -rf "$TMP"
}

@test "dead-reference-scan.sh exists and is executable" {
  [ -x "$SCRIPT" ]
}

@test "clean tree — no references at all (exit 0)" {
  echo '# clean skill' > "$TMP/plugins/gaia/skills/fake-skill/SKILL.md"
  run "$SCRIPT" --project-root "$TMP"
  [ "$status" -eq 0 ]
}

@test "active-code ref in a skill body triggers failure (exit 1)" {
  cat > "$TMP/plugins/gaia/skills/fake-skill/SKILL.md" <<EOF
# Fake skill
Load _gaia/core/engine/workflow.xml before running.
EOF
  run "$SCRIPT" --project-root "$TMP"
  [ "$status" -eq 1 ]
  [[ "$output" == *"workflow.xml"* ]]
  [[ "$output" == *"SKILL.md"* ]]
}

@test "docs/ reference is allowlisted (exit 0)" {
  cat > "$TMP/docs/some-doc.md" <<EOF
Historical note: the old engine used _gaia/core/engine/workflow.xml.
EOF
  run "$SCRIPT" --project-root "$TMP"
  [ "$status" -eq 0 ]
}

@test "migration-guide filename is allowlisted (exit 0)" {
  cat > "$TMP/docs/migration-guide-v2.md" <<EOF
To clean up: remove workflow.xml and the .resolved/ directories.
EOF
  run "$SCRIPT" --project-root "$TMP"
  [ "$status" -eq 0 ]
}

@test "CHANGELOG.md is allowlisted (exit 0)" {
  cat > "$TMP/CHANGELOG.md" <<EOF
Removed workflow.xml per ADR-048.
EOF
  run "$SCRIPT" --project-root "$TMP"
  [ "$status" -eq 0 ]
}

@test "parity-guard bats file (e28-s133-full-lifecycle-atdd.bats) is allowlisted" {
  mkdir -p "$TMP/plugins/gaia/test"
  cat > "$TMP/plugins/gaia/test/e28-s133-full-lifecycle-atdd.bats" <<EOF
@test "AC1: zero workflow.xml reads" {
  run grep -cE 'load=.*workflow\.xml' trace.log
}
EOF
  run "$SCRIPT" --project-root "$TMP"
  [ "$status" -eq 0 ]
}

@test "multiple legacy tokens detected — manifest csv" {
  cat > "$TMP/plugins/gaia/skills/fake-skill/SKILL.md" <<EOF
Read _gaia/_config/workflow-manifest.csv at startup.
EOF
  run "$SCRIPT" --project-root "$TMP"
  [ "$status" -eq 1 ]
  [[ "$output" == *"workflow-manifest.csv"* ]]
}

@test ".resolved/ references trigger failure in active code" {
  cat > "$TMP/plugins/gaia/scripts/fake.sh" <<EOF
#!/usr/bin/env bash
cat _gaia/.resolved/out.yaml
EOF
  run "$SCRIPT" --project-root "$TMP"
  [ "$status" -eq 1 ]
  [[ "$output" == *".resolved"* ]]
}
