#!/usr/bin/env bats
# infra-design-parity.bats — Cluster 6 infrastructure-design skill parity test (E28-S49 → E28-S51)
#
# Validates the gaia-infra-design skill directory, scripts, frontmatter,
# and subagent routing. Follows the Cluster 6 parity test pattern
# established by E28-S45 (parity.bats).
#
# Usage:
#   bats tests/cluster-6-parity/infra-design-parity.bats
#
# Dependencies: bats-core 1.10+

# ---------- Helpers ----------

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SKILLS_DIR="$REPO_ROOT/plugins/gaia/skills"
  SCRIPTS_DIR="$REPO_ROOT/plugins/gaia/scripts"
  FIXTURE_DIR="$REPO_ROOT/tests/cluster-6-parity/fixture"

  # Per-test isolated temp workspace
  TEST_TMP="$BATS_TEST_TMPDIR/gaia-parity-$$"
  mkdir -p "$TEST_TMP/checkpoints" "$TEST_TMP/memory" \
           "$TEST_TMP/docs/planning-artifacts" \
           "$TEST_TMP/config"

  # Copy fixture inputs into the temp workspace
  cp "$FIXTURE_DIR/config/project-config.yaml" "$TEST_TMP/config/" 2>/dev/null || true

  # Set env overrides so resolve-config.sh resolves to our fixture workspace
  export GAIA_PROJECT_ROOT="$TEST_TMP"
  export GAIA_PROJECT_PATH="$TEST_TMP"
  export GAIA_MEMORY_PATH="$TEST_TMP/memory"
  export GAIA_CHECKPOINT_PATH="$TEST_TMP/checkpoints"
  export GAIA_INSTALLED_PATH="$REPO_ROOT/plugins/gaia"
  export MEMORY_PATH="$TEST_TMP/memory"
  export CHECKPOINT_PATH="$TEST_TMP/checkpoints"
  export PROJECT_ROOT="$TEST_TMP"
  export CLAUDE_SKILL_DIR="$TEST_TMP"

  SKILL="gaia-infra-design"
}

teardown() {
  rm -rf "$TEST_TMP" 2>/dev/null || true
}

# Helper: run a skill's setup.sh
run_setup() {
  local setup_script="$SKILLS_DIR/$SKILL/scripts/setup.sh"
  [ -x "$setup_script" ] || chmod +x "$setup_script"
  run bash "$setup_script"
}

# Helper: run a skill's finalize.sh
run_finalize() {
  local finalize_script="$SKILLS_DIR/$SKILL/scripts/finalize.sh"
  [ -x "$finalize_script" ] || chmod +x "$finalize_script"
  run bash "$finalize_script"
}

# ---------- AC1: Skill directory and SKILL.md exist ----------

@test "AC1: gaia-infra-design skill directory exists" {
  [ -d "$SKILLS_DIR/$SKILL" ]
}

@test "AC1: gaia-infra-design has SKILL.md" {
  [ -f "$SKILLS_DIR/$SKILL/SKILL.md" ]
}

@test "AC1: SKILL.md frontmatter has name field" {
  grep -q "^name: gaia-infra-design" "$SKILLS_DIR/$SKILL/SKILL.md"
}

@test "AC1: SKILL.md frontmatter has description field" {
  grep -q "^description:" "$SKILLS_DIR/$SKILL/SKILL.md"
}

@test "AC1: SKILL.md frontmatter has tools field" {
  grep -q "^tools:" "$SKILLS_DIR/$SKILL/SKILL.md"
}

@test "AC1: SKILL.md frontmatter has context: fork" {
  grep -q "^context: fork" "$SKILLS_DIR/$SKILL/SKILL.md"
}

# ---------- AC2: Shared Cluster 4 script pattern ----------

@test "AC2: scripts/setup.sh exists" {
  [ -f "$SKILLS_DIR/$SKILL/scripts/setup.sh" ]
}

@test "AC2: scripts/finalize.sh exists" {
  [ -f "$SKILLS_DIR/$SKILL/scripts/finalize.sh" ]
}

@test "AC2: setup.sh references resolve-config.sh" {
  grep -q "resolve-config.sh" "$SKILLS_DIR/$SKILL/scripts/setup.sh"
}

@test "AC2: finalize.sh references checkpoint.sh" {
  grep -q "checkpoint.sh" "$SKILLS_DIR/$SKILL/scripts/finalize.sh"
}

@test "AC2: finalize.sh references lifecycle-event.sh" {
  grep -q "lifecycle-event.sh" "$SKILLS_DIR/$SKILL/scripts/finalize.sh"
}

@test "AC2: setup.sh follows shared pattern (set -euo pipefail)" {
  grep -q "set -euo pipefail" "$SKILLS_DIR/$SKILL/scripts/setup.sh"
}

@test "AC2: finalize.sh follows shared pattern (set -euo pipefail)" {
  grep -q "set -euo pipefail" "$SKILLS_DIR/$SKILL/scripts/finalize.sh"
}

# ---------- AC3: Subagent routing to devops ----------

@test "AC3: SKILL.md routes to devops subagent" {
  grep -qi "devops" "$SKILLS_DIR/$SKILL/SKILL.md"
}

@test "AC3: SKILL.md does NOT inline Soren's persona" {
  # The skill should delegate to the devops subagent, not embed the persona
  local persona_lines
  persona_lines=$(grep -ci "You are.*Soren\|identity.*senior SRE\|Communication style.*pragmatic.*metric" "$SKILLS_DIR/$SKILL/SKILL.md" || echo 0)
  [ "$persona_lines" -lt 2 ]
}

@test "AC3: SKILL.md delegates via agents/devops subagent reference" {
  grep -qi "agents/devops\|devops.*subagent\|subagent.*devops" "$SKILLS_DIR/$SKILL/SKILL.md"
}

# ---------- AC4: Frontmatter linter passes ----------

@test "AC4: frontmatter linter exits 0 for gaia-infra-design SKILL.md" {
  cd "$REPO_ROOT"
  run bash .github/scripts/lint-skill-frontmatter.sh
  [ "$status" -eq 0 ]
}

# ---------- AC4: Parity gate registration (E28-S51) ----------

@test "AC4: gaia-infra-design is registered in cluster-6-parity test" {
  grep -q "gaia-infra-design" "$REPO_ROOT/tests/cluster-6-parity/infra-design-parity.bats"
}

# ---------- Script execution tests ----------

@test "setup.sh exits 0" {
  run_setup
  [ "$status" -eq 0 ]
}

@test "finalize.sh exits 0" {
  run_finalize
  [ "$status" -eq 0 ]
}
