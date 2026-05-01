#!/usr/bin/env bats
# detect-ux-scope.bats — gaia-create-story deterministic UX detection helper (E54-S5)
#
# Validates the detect-ux-scope.sh helper script that hardens E54-S2's UX
# detection by adding word-boundary regex semantics and an explicit exclusion
# phrase list, and extracting the rules into a script that bats can invoke
# against fixture stories rather than only inspecting SKILL.md content.
#
# Acceptance Criteria coverage:
#   AC1 / TC-CSE-19: backend "data flow" -> ux_match=false, excluded_by=["data flow"]
#   AC2 / TC-CSE-20: word-boundary protects "platform" from matching "form"
#   AC3 / TC-CSE-21: figma-tagged story -> ux_match=true, rules_fired=["rule1"]
#   AC4 / TC-CSE-22: SKILL.md actually invokes the helper (integration check)
#   AC5: multiple-rule fixture -> all matching rule IDs in priority order
#   AC6: missing ux-design.md -> rule #4 omitted from rules_fired, exit 0
#
# Dependencies: bats-core 1.10+, jq, GNU or BSD grep with -E support.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
  HELPER="$REPO_ROOT/plugins/gaia/scripts/detect-ux-scope.sh"
  FIXTURES="$REPO_ROOT/tests/fixtures/ux-detection"
  SKILL_FILE="$REPO_ROOT/plugins/gaia/skills/gaia-create-story/SKILL.md"
}

# ---------- Pre-flight ----------

@test "Pre-flight: detect-ux-scope.sh exists and is executable" {
  [ -x "$HELPER" ]
}

@test "Pre-flight: jq is installed" {
  command -v jq >/dev/null 2>&1
}

@test "Pre-flight: fixture directory exists" {
  [ -d "$FIXTURES" ]
}

# ---------- AC1 / TC-CSE-19: backend data-flow exclusion ----------

@test "AC1/TC-CSE-19: backend-data-flow.md -> ux_match=false" {
  run "$HELPER" "$FIXTURES/backend-data-flow.md"
  [ "$status" -eq 0 ]
  match=$(echo "$output" | jq -r '.ux_match')
  [ "$match" = "false" ]
}

@test "AC1/TC-CSE-19: backend-data-flow.md -> excluded_by lists 'data flow'" {
  run "$HELPER" "$FIXTURES/backend-data-flow.md"
  [ "$status" -eq 0 ]
  excluded=$(echo "$output" | jq -r '.excluded_by | index("data flow")')
  [ "$excluded" != "null" ]
}

# ---------- AC2 / TC-CSE-20: word-boundary protects "platform" ----------

@test "AC2/TC-CSE-20: backend-platform.md -> ux_match=false (word-boundary blocks 'form')" {
  run "$HELPER" "$FIXTURES/backend-platform.md"
  [ "$status" -eq 0 ]
  match=$(echo "$output" | jq -r '.ux_match')
  [ "$match" = "false" ]
}

@test "AC2/TC-CSE-20: backend-platform.md -> rules_fired is empty" {
  run "$HELPER" "$FIXTURES/backend-platform.md"
  [ "$status" -eq 0 ]
  count=$(echo "$output" | jq -r '.rules_fired | length')
  [ "$count" = "0" ]
}

# ---------- AC3 / TC-CSE-21: figma-tagged story ----------

@test "AC3/TC-CSE-21: figma-tagged.md -> ux_match=true" {
  run "$HELPER" "$FIXTURES/figma-tagged.md"
  [ "$status" -eq 0 ]
  match=$(echo "$output" | jq -r '.ux_match')
  [ "$match" = "true" ]
}

@test "AC3/TC-CSE-21: figma-tagged.md -> rules_fired contains 'rule1'" {
  run "$HELPER" "$FIXTURES/figma-tagged.md"
  [ "$status" -eq 0 ]
  has_rule1=$(echo "$output" | jq -r '.rules_fired | index("rule1")')
  [ "$has_rule1" != "null" ]
}

# ---------- AC4 / TC-CSE-22: SKILL.md invokes the helper ----------

@test "AC4/TC-CSE-22: gaia-create-story SKILL.md invokes detect-ux-scope.sh" {
  grep -qE "detect-ux-scope\.sh" "$SKILL_FILE"
}

# ---------- AC5: multiple-rule fixture ----------

@test "AC5: figma-tagged.md returns rules_fired in priority order (rule1 first)" {
  run "$HELPER" "$FIXTURES/figma-tagged.md"
  [ "$status" -eq 0 ]
  first=$(echo "$output" | jq -r '.rules_fired[0]')
  [ "$first" = "rule1" ]
}

@test "AC5: ui-terms-modal.md fires rule2 (UI terms)" {
  run "$HELPER" "$FIXTURES/ui-terms-modal.md"
  [ "$status" -eq 0 ]
  has_rule2=$(echo "$output" | jq -r '.rules_fired | index("rule2")')
  [ "$has_rule2" != "null" ]
  match=$(echo "$output" | jq -r '.ux_match')
  [ "$match" = "true" ]
}

# ---------- AC6: missing ux-design.md degrades cleanly ----------

@test "AC6: missing-ux-design.md -> exit 0 even when rule #4 file is absent" {
  run "$HELPER" "$FIXTURES/missing-ux-design.md"
  [ "$status" -eq 0 ]
}

@test "AC6: missing-ux-design.md -> rule4 absent from rules_fired" {
  run "$HELPER" "$FIXTURES/missing-ux-design.md"
  [ "$status" -eq 0 ]
  has_rule4=$(echo "$output" | jq -r '.rules_fired | index("rule4")')
  [ "$has_rule4" = "null" ]
}

# ---------- Output schema ----------

@test "Schema: helper emits valid JSON with ux_match, rules_fired, excluded_by keys" {
  run "$HELPER" "$FIXTURES/backend-platform.md"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e 'has("ux_match") and has("rules_fired") and has("excluded_by")' >/dev/null
}

@test "Schema: rules_fired and excluded_by are arrays" {
  run "$HELPER" "$FIXTURES/backend-data-flow.md"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '(.rules_fired | type == "array") and (.excluded_by | type == "array")' >/dev/null
}

# ---------- Error handling ----------

@test "Error: missing story file -> exit 1" {
  run "$HELPER" "$FIXTURES/does-not-exist.md"
  [ "$status" -eq 1 ]
}

@test "Error: missing argument -> non-zero exit" {
  run "$HELPER"
  [ "$status" -ne 0 ]
}

# ---------- Word-boundary false-positive guards ----------

@test "Word-boundary: 'platform' must not match UI term 'form'" {
  tmp="$BATS_TEST_TMPDIR/platform-only.md"
  cat > "$tmp" <<'EOF'
---
key: "E99-S99"
title: "Adopt platform tooling"
---
# Story
Platform vendor selection only.
EOF
  run "$HELPER" "$tmp"
  [ "$status" -eq 0 ]
  match=$(echo "$output" | jq -r '.ux_match')
  [ "$match" = "false" ]
}

@test "Word-boundary: 'workflow' (exclusion) suppresses 'flow'" {
  tmp="$BATS_TEST_TMPDIR/workflow.md"
  cat > "$tmp" <<'EOF'
---
key: "E99-S98"
title: "Refactor CI workflow"
---
# Story
The build workflow needs simplification.
EOF
  run "$HELPER" "$tmp"
  [ "$status" -eq 0 ]
  match=$(echo "$output" | jq -r '.ux_match')
  [ "$match" = "false" ]
}
