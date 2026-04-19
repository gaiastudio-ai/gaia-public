#!/usr/bin/env bats
# threat-model-parity.bats — Cluster 6 threat-model skill parity test (E28-S50 → E28-S51)
#
# Validates the gaia-threat-model skill directory, scripts, frontmatter,
# STRIDE/DREAD methodology preservation, and subagent routing. Follows the
# Cluster 6 parity test pattern established by E28-S45 (parity.bats).
#
# Usage:
#   bats tests/cluster-6-parity/threat-model-parity.bats
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

  SKILL="gaia-threat-model"
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

@test "AC1: gaia-threat-model skill directory exists" {
  [ -d "$SKILLS_DIR/$SKILL" ]
}

@test "AC1: gaia-threat-model has SKILL.md" {
  [ -f "$SKILLS_DIR/$SKILL/SKILL.md" ]
}

@test "AC1: SKILL.md frontmatter has name field" {
  grep -q "^name: gaia-threat-model" "$SKILLS_DIR/$SKILL/SKILL.md"
}

@test "AC1: SKILL.md frontmatter has description field" {
  grep -q "^description:" "$SKILLS_DIR/$SKILL/SKILL.md"
}

@test "AC1: SKILL.md frontmatter has tools field" {
  grep -q "^tools:" "$SKILLS_DIR/$SKILL/SKILL.md"
}

@test "AC1: SKILL.md frontmatter has context field" {
  grep -q "^context:" "$SKILLS_DIR/$SKILL/SKILL.md"
}

# ---------- AC2: STRIDE categories preserved verbatim ----------

@test "AC2: STRIDE — Spoofing category present verbatim" {
  grep -q "Spoofing" "$SKILLS_DIR/$SKILL/SKILL.md"
}

@test "AC2: STRIDE — Tampering category present verbatim" {
  grep -q "Tampering" "$SKILLS_DIR/$SKILL/SKILL.md"
}

@test "AC2: STRIDE — Repudiation category present verbatim" {
  grep -q "Repudiation" "$SKILLS_DIR/$SKILL/SKILL.md"
}

@test "AC2: STRIDE — Information Disclosure category present verbatim" {
  grep -q "Information Disclosure" "$SKILLS_DIR/$SKILL/SKILL.md"
}

@test "AC2: STRIDE — Denial of Service category present verbatim" {
  grep -q "Denial of Service" "$SKILLS_DIR/$SKILL/SKILL.md"
}

@test "AC2: STRIDE — Elevation of Privilege category present verbatim" {
  grep -q "Elevation of Privilege" "$SKILLS_DIR/$SKILL/SKILL.md"
}

# ---------- AC2: DREAD scoring dimensions preserved verbatim ----------

@test "AC2: DREAD — Damage potential dimension present" {
  grep -q "Damage potential" "$SKILLS_DIR/$SKILL/SKILL.md"
}

@test "AC2: DREAD — Reproducibility dimension present" {
  grep -q "Reproducibility" "$SKILLS_DIR/$SKILL/SKILL.md"
}

@test "AC2: DREAD — Exploitability dimension present" {
  grep -q "Exploitability" "$SKILLS_DIR/$SKILL/SKILL.md"
}

@test "AC2: DREAD — Affected users dimension present" {
  grep -q "Affected users" "$SKILLS_DIR/$SKILL/SKILL.md"
}

@test "AC2: DREAD — Discoverability dimension present" {
  grep -q "Discoverability" "$SKILLS_DIR/$SKILL/SKILL.md"
}

@test "AC2: DREAD risk levels preserved (Critical, High, Medium, Low)" {
  grep -q "Critical (8-10)" "$SKILLS_DIR/$SKILL/SKILL.md"
  grep -q "High (6-8)" "$SKILLS_DIR/$SKILL/SKILL.md"
  grep -q "Medium (4-6)" "$SKILLS_DIR/$SKILL/SKILL.md"
  grep -q "Low (1-4)" "$SKILLS_DIR/$SKILL/SKILL.md"
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

@test "AC3: setup.sh references validate-gate.sh" {
  grep -q "validate-gate.sh" "$SKILLS_DIR/$SKILL/scripts/setup.sh"
}

@test "AC3: setup.sh references checkpoint.sh" {
  grep -q "checkpoint.sh" "$SKILLS_DIR/$SKILL/scripts/setup.sh"
}

@test "AC3: finalize.sh references checkpoint.sh" {
  grep -q "checkpoint.sh" "$SKILLS_DIR/$SKILL/scripts/finalize.sh"
}

@test "AC3: finalize.sh references lifecycle-event.sh" {
  grep -q "lifecycle-event.sh" "$SKILLS_DIR/$SKILL/scripts/finalize.sh"
}

@test "AC3: setup.sh is executable or can be made executable" {
  [ -f "$SKILLS_DIR/$SKILL/scripts/setup.sh" ]
  chmod +x "$SKILLS_DIR/$SKILL/scripts/setup.sh"
  [ -x "$SKILLS_DIR/$SKILL/scripts/setup.sh" ]
}

@test "AC3: finalize.sh is executable or can be made executable" {
  [ -f "$SKILLS_DIR/$SKILL/scripts/finalize.sh" ]
  chmod +x "$SKILLS_DIR/$SKILL/scripts/finalize.sh"
  [ -x "$SKILLS_DIR/$SKILL/scripts/finalize.sh" ]
}

# ---------- AC4: Subagent routing to security ----------

@test "AC4: SKILL.md routes to security subagent" {
  grep -q "security" "$SKILLS_DIR/$SKILL/SKILL.md"
  grep -q "agents/security" "$SKILLS_DIR/$SKILL/SKILL.md"
}

@test "AC4: SKILL.md does not inline Zara persona content" {
  # The skill should reference the subagent, not embed the full persona
  ! grep -q "You are \*\*Zara\*\*" "$SKILLS_DIR/$SKILL/SKILL.md"
}

# ---------- AC5: Frontmatter lint ----------

@test "AC5: frontmatter linter passes on SKILL.md" {
  LINTER="$REPO_ROOT/.github/scripts/lint-skill-frontmatter.sh"
  if [ -x "$LINTER" ]; then
    run bash "$LINTER"
    [ "$status" -eq 0 ]
  else
    # If linter is not available, verify minimal frontmatter manually
    grep -q "^name:" "$SKILLS_DIR/$SKILL/SKILL.md"
    grep -q "^description:" "$SKILLS_DIR/$SKILL/SKILL.md"
  fi
}

# ---------- AC5: SKILL.md references setup and finalize ----------

@test "SKILL.md references setup.sh in Setup section" {
  grep -q "setup.sh" "$SKILLS_DIR/$SKILL/SKILL.md"
}

@test "SKILL.md references finalize.sh in Finalize section" {
  grep -q "finalize.sh" "$SKILLS_DIR/$SKILL/SKILL.md"
}

# ---------- Legacy methodology step ordering preserved ----------

@test "Step ordering: Load Architecture before STRIDE Analysis" {
  local arch_line stride_line
  arch_line=$(grep -n "Load Architecture" "$SKILLS_DIR/$SKILL/SKILL.md" | head -1 | cut -d: -f1)
  stride_line=$(grep -n "STRIDE Analysis" "$SKILLS_DIR/$SKILL/SKILL.md" | head -1 | cut -d: -f1)
  [ "$arch_line" -lt "$stride_line" ]
}

@test "Step ordering: STRIDE Analysis before DREAD Scoring" {
  local stride_line dread_line
  stride_line=$(grep -n "STRIDE Analysis" "$SKILLS_DIR/$SKILL/SKILL.md" | head -1 | cut -d: -f1)
  dread_line=$(grep -n "DREAD Scoring" "$SKILLS_DIR/$SKILL/SKILL.md" | head -1 | cut -d: -f1)
  [ "$stride_line" -lt "$dread_line" ]
}

@test "Step ordering: DREAD Scoring before Mitigation" {
  local dread_line mitigation_line
  dread_line=$(grep -n "DREAD Scoring" "$SKILLS_DIR/$SKILL/SKILL.md" | head -1 | cut -d: -f1)
  mitigation_line=$(grep -n "Mitigation" "$SKILLS_DIR/$SKILL/SKILL.md" | head -1 | cut -d: -f1)
  [ "$dread_line" -lt "$mitigation_line" ]
}
