#!/usr/bin/env bats
# lint-skill-frontmatter.bats — frontmatter linter allowed-tools validation tests (E28-S96)
#
# Validates:
#   AC1: Valid allowed-tools list passes lint (both array and space-separated formats)
#   AC2: Invalid tool name produces error with file path and tool name
#   AC3: Full-tree backward compatibility — all existing SKILL.md files pass
#   AC4: Missing allowed-tools field passes lint (optional field)
#   AC5: Single CANONICAL_TOOLS array is the sole authority
#
# Usage:
#   bats tests/skills/lint-skill-frontmatter.bats
#
# Dependencies: bats-core 1.10+

# ---------- Helpers ----------

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCRIPT="$REPO_ROOT/.github/scripts/lint-skill-frontmatter.sh"
  FIXTURE_DIR="$(mktemp -d)"
  # Create the plugins/gaia/skills directory structure in the fixture
  mkdir -p "$FIXTURE_DIR/plugins/gaia/skills/test-skill"
}

teardown() {
  rm -rf "$FIXTURE_DIR"
}

# Helper: create a SKILL.md fixture with given frontmatter content
create_skill_fixture() {
  local skill_name="${1:-test-skill}"
  local frontmatter="$2"
  local dir="$FIXTURE_DIR/plugins/gaia/skills/$skill_name"
  mkdir -p "$dir"
  cat > "$dir/SKILL.md" <<HEREDOC
---
$frontmatter
---

# $skill_name

Skill content here.
HEREDOC
}

# Helper: run the linter from the fixture directory
run_linter() {
  cd "$FIXTURE_DIR" && bash "$SCRIPT"
}

# ---------- AC1: Valid allowed-tools (YAML array format) passes lint ----------

@test "AC1: valid allowed-tools in YAML array format passes lint" {
  create_skill_fixture "valid-array" "name: valid-array
description: A test skill
allowed-tools: [Read, Write, Bash]"
  run run_linter
  [ "$status" -eq 0 ]
}

# ---------- AC1: Valid allowed-tools (space-separated format) passes lint ----------

@test "AC1: valid allowed-tools in space-separated format passes lint" {
  create_skill_fixture "valid-space" "name: valid-space
description: A test skill
allowed-tools: Read Write Bash"
  run run_linter
  [ "$status" -eq 0 ]
}

# ---------- AC2: Invalid tool name produces error ----------

@test "AC2: invalid tool name in allowed-tools produces error with tool name and file path" {
  create_skill_fixture "invalid-tool" "name: invalid-tool
description: A test skill
allowed-tools: [Read, FooBar]"
  run run_linter
  [ "$status" -eq 1 ]
  [[ "$output" == *"invalid allowed-tool"* ]]
  [[ "$output" == *"FooBar"* ]]
  [[ "$output" == *"invalid-tool/SKILL.md"* ]]
}

# ---------- AC3: Full-tree backward compatibility ----------

@test "AC3: all existing SKILL.md files in plugins/gaia/skills/ pass lint" {
  cd "$REPO_ROOT" && bash "$SCRIPT"
}

# ---------- AC4: Missing allowed-tools field passes lint ----------

@test "AC4: missing allowed-tools field does not cause error" {
  create_skill_fixture "no-allowed-tools" "name: no-allowed-tools
description: A test skill without allowed-tools"
  run run_linter
  [ "$status" -eq 0 ]
}

# ---------- AC1 variant: Both YAML array and space formats handled ----------

@test "AC1: all canonical tools in YAML array format passes lint" {
  create_skill_fixture "all-tools" "name: all-tools
description: A test skill
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Agent, Skill, WebSearch, WebFetch, Task]"
  run run_linter
  [ "$status" -eq 0 ]
}

# ---------- Edge: Empty allowed-tools value passes lint ----------

@test "Edge: empty allowed-tools value does not cause error" {
  create_skill_fixture "empty-tools" "name: empty-tools
description: A test skill
allowed-tools: "
  run run_linter
  [ "$status" -eq 0 ]
}

# ---------- AC2 variant: Multiple invalid tools each produce separate errors ----------

@test "AC2: multiple invalid tool names each produce separate error lines" {
  create_skill_fixture "multi-invalid" "name: multi-invalid
description: A test skill
allowed-tools: [Read, FooBar, BazQux]"
  run run_linter
  [ "$status" -eq 1 ]
  [[ "$output" == *"FooBar"* ]]
  [[ "$output" == *"BazQux"* ]]
}
