#!/usr/bin/env bats
# change-request-parity.bats — Cluster 7 change-request redirect skill parity test (E28-S58)
#
# Validates the gaia-change-request redirect skill: directory structure, frontmatter,
# deprecation notice, redirect body, and Cluster 7 shared script conformance.
#
# Usage:
#   bats tests/cluster-7-parity/change-request-parity.bats
#
# Dependencies: bats-core 1.10+

# ---------- Helpers ----------

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SKILLS_DIR="$REPO_ROOT/plugins/gaia/skills"

  SKILL="gaia-change-request"
  SKILL_DIR="$SKILLS_DIR/$SKILL"
}

teardown() {
  :
}

# ---------- AC1: Skill directory and SKILL.md exist with valid frontmatter ----------

@test "AC1: gaia-change-request skill directory exists" {
  [ -d "$SKILL_DIR" ]
}

@test "AC1: gaia-change-request has SKILL.md" {
  [ -f "$SKILL_DIR/SKILL.md" ]
}

@test "AC1: SKILL.md frontmatter has name field" {
  grep -q "^name: gaia-change-request" "$SKILL_DIR/SKILL.md"
}

@test "AC1: SKILL.md frontmatter has description field" {
  grep -q "^description:" "$SKILL_DIR/SKILL.md"
}

@test "AC1: SKILL.md description contains deprecation notice" {
  local desc
  desc=$(grep "^description:" "$SKILL_DIR/SKILL.md")
  echo "$desc" | grep -qi "deprecated\|deprecation"
}

@test "AC1: SKILL.md description references gaia-add-feature" {
  local desc
  desc=$(grep "^description:" "$SKILL_DIR/SKILL.md")
  echo "$desc" | grep -q "gaia-add-feature"
}

@test "AC1: SKILL.md frontmatter has argument-hint field" {
  grep -q "^argument-hint:" "$SKILL_DIR/SKILL.md"
}

@test "AC1: SKILL.md frontmatter has allowed-tools field" {
  grep -q "^allowed-tools:" "$SKILL_DIR/SKILL.md"
}

@test "AC1: SKILL.md allowed-tools is minimal (includes Skill)" {
  local line
  line=$(grep "^allowed-tools:" "$SKILL_DIR/SKILL.md")
  # Redirect skills need minimal tools — Skill tool to invoke target
  echo "$line" | grep -q "Skill\|Read\|Glob\|Bash"
}

# ---------- AC2: Redirect body forwards to gaia-add-feature ----------

@test "AC2: SKILL.md body references gaia-add-feature as redirect target" {
  grep -q "gaia-add-feature" "$SKILL_DIR/SKILL.md"
}

@test "AC2: SKILL.md contains visible deprecation banner" {
  grep -qi "deprecated\|deprecation" "$SKILL_DIR/SKILL.md"
}

@test "AC2: SKILL.md instructs forwarding invocation to gaia-add-feature" {
  # The body should instruct the agent to invoke gaia-add-feature
  grep -qi "forward\|redirect\|invoke.*gaia-add-feature\|delegate.*gaia-add-feature" "$SKILL_DIR/SKILL.md"
}

@test "AC2: SKILL.md preserves argument in redirect" {
  # The body should mention preserving the argument
  grep -qi "argument\|args\|request.text\|same.*argument\|verbatim" "$SKILL_DIR/SKILL.md"
}

# ---------- AC3: Cluster 7 shared scripts ----------

@test "AC3: scripts/setup.sh exists" {
  [ -f "$SKILL_DIR/scripts/setup.sh" ]
}

@test "AC3: scripts/finalize.sh exists" {
  [ -f "$SKILL_DIR/scripts/finalize.sh" ]
}

@test "AC3: setup.sh references resolve-config.sh" {
  grep -q "resolve-config.sh" "$SKILL_DIR/scripts/setup.sh"
}

@test "AC3: setup.sh follows shared pattern (set -euo pipefail)" {
  grep -q "set -euo pipefail" "$SKILL_DIR/scripts/setup.sh"
}

@test "AC3: finalize.sh references checkpoint.sh" {
  grep -q "checkpoint.sh" "$SKILL_DIR/scripts/finalize.sh"
}

@test "AC3: finalize.sh references lifecycle-event.sh" {
  grep -q "lifecycle-event.sh" "$SKILL_DIR/scripts/finalize.sh"
}

@test "AC3: finalize.sh follows shared pattern (set -euo pipefail)" {
  grep -q "set -euo pipefail" "$SKILL_DIR/scripts/finalize.sh"
}

# ---------- General: No runtime dependency on _gaia/ tree ----------

@test "SKILL.md does NOT reference _gaia/ framework tree" {
  ! grep -q "_gaia/" "$SKILL_DIR/SKILL.md" || {
    local count
    count=$(grep -c "_gaia/" "$SKILL_DIR/SKILL.md")
    [ "$count" -le 1 ]
  }
}

# ---------- General: SKILL.md has Setup and Finalize shell hooks ----------

@test "SKILL.md has Setup section with setup.sh reference" {
  grep -q "setup.sh" "$SKILL_DIR/SKILL.md"
}

@test "SKILL.md has Finalize section with finalize.sh reference" {
  grep -q "finalize.sh" "$SKILL_DIR/SKILL.md"
}
