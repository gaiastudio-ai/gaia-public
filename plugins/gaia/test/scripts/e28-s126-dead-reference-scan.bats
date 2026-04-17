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

# ============================================================================
# E28-S127 — Extended PATTERN for retired commands/ surface (FR-329).
# The extended scanner now also flags file-path references to retired slash-command files.
# ============================================================================

@test "E28-S127: .claude/commands/gaia-*.md file-path reference triggers failure" {
  cat > "$TMP/plugins/gaia/scripts/fake.sh" <<'EOF'
#!/usr/bin/env bash
# Loads the legacy slash-command file
cat .claude/commands/gaia-dev-story.md
EOF
  run "$SCRIPT" --project-root "$TMP"
  [ "$status" -eq 1 ]
  [[ "$output" == *"gaia-dev-story.md"* ]]
}

@test "E28-S127: plugins/gaia/commands/gaia-*.md file-path reference triggers failure" {
  cat > "$TMP/plugins/gaia/scripts/fake.sh" <<'EOF'
#!/usr/bin/env bash
source plugins/gaia/commands/gaia-foo.md
EOF
  run "$SCRIPT" --project-root "$TMP"
  [ "$status" -eq 1 ]
  [[ "$output" == *"gaia-foo.md"* ]]
}

@test "E28-S127: invocation form /gaia-foo in SKILL.md prose does NOT trigger failure" {
  # The slash-command invocation form '/gaia-foo' is valid everywhere — SKILL bodies
  # and agent prose reference it constantly. It must NOT match the file-path regex.
  cat > "$TMP/plugins/gaia/skills/fake-skill/SKILL.md" <<'EOF'
# Example skill
After completing this, run /gaia-dev-story or /gaia-create-story to continue.
EOF
  run "$SCRIPT" --project-root "$TMP"
  [ "$status" -eq 0 ]
}

@test "E28-S127: docs/ reference to .claude/commands/gaia-*.md is allowlisted" {
  mkdir -p "$TMP/docs"
  cat > "$TMP/docs/legacy-note.md" <<'EOF'
Historical: the legacy slash command lived at .claude/commands/gaia-dev-story.md.
EOF
  run "$SCRIPT" --project-root "$TMP"
  [ "$status" -eq 0 ]
}

# ============================================================================
# E28-S128 — Extended PATTERN for retired workflow artifacts (FR-328).
# Three filename types (workflow.yaml, instructions.xml, checklist.md) are
# retired from active code. The scanner uses broad word-boundary matches
# combined with a negative-filter pass that excludes shell-variable forms.
# ============================================================================

@test "E28-S128: backtick-prose workflow.yaml in SKILL.md triggers failure" {
  cat > "$TMP/plugins/gaia/skills/fake-skill/SKILL.md" <<'EOF'
# Fake skill
Verify every `workflow.yaml` has its companion files.
EOF
  run "$SCRIPT" --project-root "$TMP"
  [ "$status" -eq 1 ]
  [[ "$output" == *"workflow.yaml"* ]]
}

@test "E28-S128: path-form instructions.xml reference triggers failure" {
  cat > "$TMP/plugins/gaia/scripts/fake.sh" <<'EOF'
#!/usr/bin/env bash
cat _gaia/lifecycle/workflows/foo/instructions.xml
EOF
  run "$SCRIPT" --project-root "$TMP"
  [ "$status" -eq 1 ]
  [[ "$output" == *"instructions.xml"* ]]
}

@test "E28-S128: parenthesized checklist.md in SKILL prose triggers failure" {
  cat > "$TMP/plugins/gaia/skills/fake-skill/SKILL.md" <<'EOF'
# Fake skill
See legacy source (workflow.yaml + instructions.xml + checklist.md).
EOF
  run "$SCRIPT" --project-root "$TMP"
  [ "$status" -eq 1 ]
  [[ "$output" == *"checklist.md"* ]]
}

@test "E28-S128: shell variable dollar-workflow.yaml does NOT trigger failure" {
  # checkpoint.sh has "$workflow.yaml" which is a variable expansion producing
  # runtime filenames like dev-story.yaml. MUST NOT be flagged.
  cat > "$TMP/plugins/gaia/scripts/fake.sh" <<'EOF'
#!/usr/bin/env bash
local target="$CHECKPOINT_PATH/$workflow.yaml"
EOF
  run "$SCRIPT" --project-root "$TMP"
  [ "$status" -eq 0 ]
}

@test "E28-S128: parameter expansion dollar-brace-name-dot-yaml does NOT trigger failure" {
  cat > "$TMP/plugins/gaia/scripts/fake.sh" <<'EOF'
#!/usr/bin/env bash
out="${name}.yaml"
EOF
  run "$SCRIPT" --project-root "$TMP"
  [ "$status" -eq 0 ]
}

@test "E28-S128: shell variable with suffix dollar-workflow.yaml.lock does NOT trigger failure" {
  # The negative-filter must handle lines that contain $workflow.yaml embedded
  # as a prefix of a longer token (e.g., the .lock suffix in checkpoint.sh).
  cat > "$TMP/plugins/gaia/scripts/fake.sh" <<'EOF'
#!/usr/bin/env bash
local lockfile="$CHECKPOINT_PATH/$workflow.yaml.lock"
EOF
  run "$SCRIPT" --project-root "$TMP"
  [ "$status" -eq 0 ]
}

@test "E28-S128: colon-prefixed workflow.yaml:output.primary in prose triggers failure" {
  cat > "$TMP/plugins/gaia/skills/fake-skill/SKILL.md" <<'EOF'
# Fake skill
Output path inherits from the legacy workflow.yaml:output.primary field.
EOF
  run "$SCRIPT" --project-root "$TMP"
  [ "$status" -eq 1 ]
  [[ "$output" == *"workflow.yaml"* ]]
}

@test "E28-S128: bare instructions.xml word in SKILL body triggers failure" {
  cat > "$TMP/plugins/gaia/skills/fake-skill/SKILL.md" <<'EOF'
# Fake skill
This skill replaces the legacy instructions.xml body with prose steps.
EOF
  run "$SCRIPT" --project-root "$TMP"
  [ "$status" -eq 1 ]
  [[ "$output" == *"instructions.xml"* ]]
}

@test "E28-S128: docs/ reference to workflow.yaml is allowlisted" {
  mkdir -p "$TMP/docs"
  cat > "$TMP/docs/migration-guide-v2.md" <<'EOF'
Historical: the legacy workflow.yaml file has been retired under FR-328.
EOF
  run "$SCRIPT" --project-root "$TMP"
  [ "$status" -eq 0 ]
}
