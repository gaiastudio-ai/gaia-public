#!/usr/bin/env bats
# skill-frontmatter-guard.bats — E28-S185 regression guard.
#
# Claude Code's native skill loader expects YAML frontmatter key `tools:` as a
# comma-separated string (e.g., `tools: Read, Bash`). Not `allowed-tools:`, not
# a YAML list. If any plugin SKILL.md regresses to the legacy `allowed-tools:`
# key (or uses a bracketed/list shape for `tools:`), /reload-plugins reports
# `0 skills` and the plugin is broken end-to-end.
#
# These assertions fail loudly in CI so the regression cannot land.

load test_helper

setup() {
  common_setup
  PLUGIN_SKILLS_DIR="$(cd "$BATS_TEST_DIRNAME/../skills" && pwd)"
  export PLUGIN_SKILLS_DIR
}

teardown() { common_teardown; }

@test "no plugin SKILL.md uses the legacy allowed-tools frontmatter key" {
  local hits
  hits="$(grep -l '^allowed-tools:' "$PLUGIN_SKILLS_DIR"/*/SKILL.md 2>/dev/null || true)"
  if [ -n "$hits" ]; then
    echo "SKILL.md files still using the legacy allowed-tools: key:"
    printf '  %s\n' $hits
    return 1
  fi
}

@test "every plugin SKILL.md declares a tools: frontmatter key" {
  local total with_tools
  total="$(ls "$PLUGIN_SKILLS_DIR"/*/SKILL.md | wc -l | tr -d ' ')"
  with_tools="$(grep -l '^tools:' "$PLUGIN_SKILLS_DIR"/*/SKILL.md | wc -l | tr -d ' ')"
  [ "$total" -ge 115 ]
  [ "$with_tools" = "$total" ]
}

@test "no plugin SKILL.md uses a bracketed YAML list for tools:" {
  local hits
  hits="$(grep -lE '^tools:[[:space:]]*\[' "$PLUGIN_SKILLS_DIR"/*/SKILL.md 2>/dev/null || true)"
  if [ -n "$hits" ]; then
    echo "SKILL.md files with bracketed tools: list (must be comma-separated string):"
    printf '  %s\n' $hits
    return 1
  fi
}
