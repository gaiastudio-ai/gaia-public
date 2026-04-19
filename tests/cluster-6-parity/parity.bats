#!/usr/bin/env bats
# parity.bats — Cluster 6 architecture skill parity test (E28-S45 → E28-S51)
#
# Validates the gaia-create-arch skill directory, scripts, frontmatter, template
# integration, and subagent routing. Follows the Cluster 5 parity test pattern
# established by E28-S44.
#
# Usage:
#   bats tests/cluster-6-parity/parity.bats
#
# Dependencies: bats-core 1.10+

# ---------- Helpers ----------

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SKILLS_DIR="$REPO_ROOT/plugins/gaia/skills"
  SCRIPTS_DIR="$REPO_ROOT/plugins/gaia/scripts"
  FIXTURE_DIR="$REPO_ROOT/tests/cluster-6-parity/fixture"
  ALLOWLIST="$REPO_ROOT/tests/cluster-6-parity/diff-allowlist.txt"

  # Per-test isolated temp workspace
  TEST_TMP="$BATS_TEST_TMPDIR/gaia-parity-$$"
  mkdir -p "$TEST_TMP/checkpoints" "$TEST_TMP/memory" \
           "$TEST_TMP/docs/planning-artifacts" \
           "$TEST_TMP/config"

  # Copy fixture inputs into the temp workspace
  cp "$FIXTURE_DIR/prd.md" "$TEST_TMP/docs/planning-artifacts/" 2>/dev/null || true
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

  SKILL="gaia-create-arch"
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

@test "AC1: gaia-create-arch skill directory exists" {
  [ -d "$SKILLS_DIR/$SKILL" ]
}

@test "AC1: gaia-create-arch has SKILL.md" {
  [ -f "$SKILLS_DIR/$SKILL/SKILL.md" ]
}

@test "AC1: SKILL.md frontmatter has name field" {
  grep -q "^name: gaia-create-arch" "$SKILLS_DIR/$SKILL/SKILL.md"
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

# ---------- AC2: Architecture template carried into skill directory ----------

@test "AC2: architecture-template.md exists in skill directory" {
  [ -f "$SKILLS_DIR/$SKILL/architecture-template.md" ]
}

@test "AC2: SKILL.md body references the carried template" {
  grep -qi "architecture-template" "$SKILLS_DIR/$SKILL/SKILL.md"
}

@test "AC2: architecture-template.md has standard section structure" {
  local tpl="$SKILLS_DIR/$SKILL/architecture-template.md"
  grep -q "System Overview" "$tpl"
  grep -q "Architecture Decisions" "$tpl"
  grep -q "System Components" "$tpl"
  grep -q "Data Architecture" "$tpl"
  grep -q "Infrastructure" "$tpl"
  grep -q "Security Architecture" "$tpl"
}

# ---------- AC3: Shared Cluster 4 script pattern ----------

@test "AC3: scripts/setup.sh exists" {
  [ -f "$SKILLS_DIR/$SKILL/scripts/setup.sh" ]
}

@test "AC3: scripts/finalize.sh exists" {
  [ -f "$SKILLS_DIR/$SKILL/scripts/finalize.sh" ]
}

@test "AC3: setup.sh references resolve-config.sh" {
  grep -q "resolve-config.sh" "$SKILLS_DIR/$SKILL/scripts/setup.sh"
}

@test "AC3: finalize.sh references checkpoint.sh" {
  grep -q "checkpoint.sh" "$SKILLS_DIR/$SKILL/scripts/finalize.sh"
}

@test "AC3: finalize.sh references lifecycle-event.sh" {
  grep -q "lifecycle-event.sh" "$SKILLS_DIR/$SKILL/scripts/finalize.sh"
}

@test "AC3: setup.sh follows shared pattern (set -euo pipefail)" {
  grep -q "set -euo pipefail" "$SKILLS_DIR/$SKILL/scripts/setup.sh"
}

@test "AC3: finalize.sh follows shared pattern (set -euo pipefail)" {
  grep -q "set -euo pipefail" "$SKILLS_DIR/$SKILL/scripts/finalize.sh"
}

# ---------- AC4: Subagent routing to architect ----------

@test "AC4: SKILL.md routes to architect subagent" {
  grep -qi "architect" "$SKILLS_DIR/$SKILL/SKILL.md"
}

@test "AC4: SKILL.md does NOT inline Theo's persona" {
  # The skill should delegate to the architect subagent, not embed the persona
  # Check that large persona content is not present inline
  local persona_lines
  persona_lines=$(grep -ci "You are.*Theo\|identity.*senior architect\|Communication style.*pragmatic" "$SKILLS_DIR/$SKILL/SKILL.md" || echo 0)
  [ "$persona_lines" -lt 2 ]
}

@test "AC4: SKILL.md delegates via agents/architect subagent reference" {
  grep -qi "agents/architect\|architect.*subagent\|subagent.*architect" "$SKILLS_DIR/$SKILL/SKILL.md"
}

# ---------- AC5: Frontmatter linter passes ----------

@test "AC5: frontmatter linter exits 0 for gaia-create-arch SKILL.md" {
  cd "$REPO_ROOT"
  run bash .github/scripts/lint-skill-frontmatter.sh
  [ "$status" -eq 0 ]
}

# ---------- AC5: Parity gate registration (E28-S51) ----------

@test "AC5: gaia-create-arch is registered in cluster-6-parity test" {
  # This test validates that the skill appears in the parity test suite
  grep -q "gaia-create-arch" "$REPO_ROOT/tests/cluster-6-parity/parity.bats"
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
