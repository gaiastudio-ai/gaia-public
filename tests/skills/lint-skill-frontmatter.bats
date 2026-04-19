#!/usr/bin/env bats
# lint-skill-frontmatter.bats — frontmatter linter tools validation tests (E28-S96)
#
# Validates:
#   AC1: Valid tools list passes lint (both array and space-separated formats)
#   AC2: Invalid tool name produces error with file path and tool name
#   AC3: Full-tree backward compatibility — all existing SKILL.md files pass
#   AC4: Missing tools field passes lint (optional field)
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

# ---------- AC1: Valid tools (comma-separated string) passes lint ----------

@test "AC1: valid tools in comma-separated string format passes lint" {
  create_skill_fixture "valid-csv" "name: valid-csv
description: A test skill
tools: Read, Write, Bash"
  run run_linter
  [ "$status" -eq 0 ]
}

# ---------- E28-S185: Bracketed tools: list is REJECTED ----------

@test "AC1: bracketed tools: list is rejected (E28-S185)" {
  create_skill_fixture "bracketed" "name: bracketed
description: A test skill
tools: [Read, Write, Bash]"
  run run_linter
  [ "$status" -eq 1 ]
  [[ "$output" == *"bracketed list"* ]] || [[ "$output" == *"comma-separated string"* ]]
}

# ---------- AC1: Valid tools (space-separated format) passes lint ----------

@test "AC1: valid tools in space-separated format passes lint" {
  create_skill_fixture "valid-space" "name: valid-space
description: A test skill
tools: Read Write Bash"
  run run_linter
  [ "$status" -eq 0 ]
}

# ---------- AC2: Invalid tool name produces error ----------

@test "AC2: invalid tool name in tools produces error with tool name and file path" {
  create_skill_fixture "invalid-tool" "name: invalid-tool
description: A test skill
tools: Read, FooBar"
  run run_linter
  [ "$status" -eq 1 ]
  [[ "$output" == *"invalid tool"* ]]
  [[ "$output" == *"FooBar"* ]]
  [[ "$output" == *"invalid-tool/SKILL.md"* ]]
}

# ---------- AC3: Full-tree backward compatibility ----------

@test "AC3: all existing SKILL.md files in plugins/gaia/skills/ pass lint" {
  cd "$REPO_ROOT" && bash "$SCRIPT"
}

# ---------- AC4: Missing tools field passes lint ----------

@test "AC4: missing tools field does not cause error" {
  create_skill_fixture "no-tools" "name: no-tools
description: A test skill without tools"
  run run_linter
  [ "$status" -eq 0 ]
}

# ---------- AC1 variant: All canonical tools accepted ----------

@test "AC1: all canonical tools in comma-separated format pass lint" {
  create_skill_fixture "all-tools" "name: all-tools
description: A test skill
tools: Read, Write, Edit, Grep, Glob, Bash, Agent, Skill, WebSearch, WebFetch, Task"
  run run_linter
  [ "$status" -eq 0 ]
}

# ---------- E28-S185: Retired allowed-tools key is REJECTED ----------

@test "E28-S185: retired allowed-tools key is rejected" {
  create_skill_fixture "legacy" "name: legacy
description: A test skill
allowed-tools: Read, Write"
  run run_linter
  [ "$status" -eq 1 ]
  [[ "$output" == *"retired"* ]] || [[ "$output" == *"allowed-tools"* ]]
}

# ---------- Edge: Empty tools value passes lint ----------

@test "Edge: empty tools value does not cause error" {
  create_skill_fixture "empty-tools" "name: empty-tools
description: A test skill
tools: "
  run run_linter
  [ "$status" -eq 0 ]
}

# ---------- AC2 variant: Multiple invalid tools each produce separate errors ----------

@test "AC2: multiple invalid tool names each produce separate error lines" {
  create_skill_fixture "multi-invalid" "name: multi-invalid
description: A test skill
tools: [Read, FooBar, BazQux]"
  run run_linter
  [ "$status" -eq 1 ]
  [[ "$output" == *"FooBar"* ]]
  [[ "$output" == *"BazQux"* ]]
}
