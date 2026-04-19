#!/usr/bin/env bats
# gaia-deploy-checklist.bats — deployment checklist skill structural tests (E28-S92)
#
# Validates:
#   AC1: SKILL.md invokes validate-gate.sh for traceability, CI, and readiness gates
#   AC2: Gate failure halts with actionable error
#   AC3: All gates pass produces complete deployment checklist
#   AC4: setup.sh/finalize.sh follow shared pattern
#   AC5: Gate enforcement blocks checklist when traceability missing
#   AC-EC1: validate-gate.sh not found detection
#   AC-EC2: Non-zero exit with no structured output
#   AC-EC3: Empty traceability file treated as missing
#   AC-EC4: CI gate fails independently
#   AC-EC5: setup.sh failure halts before gates
#   AC-EC6: Missing docs/ directory detection
#
# Usage:
#   bats tests/skills/gaia-deploy-checklist.bats
#
# Dependencies: bats-core 1.10+

# ---------- Helpers ----------

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SKILLS_DIR="$REPO_ROOT/plugins/gaia/skills"
  SCRIPTS_DIR="$REPO_ROOT/plugins/gaia/scripts"
  SKILL_DIR="$SKILLS_DIR/gaia-deploy-checklist"
  SKILL_FILE="$SKILL_DIR/SKILL.md"
  SETUP_SCRIPT="$SKILL_DIR/scripts/setup.sh"
  FINALIZE_SCRIPT="$SKILL_DIR/scripts/finalize.sh"
  VALIDATE_GATE="$SCRIPTS_DIR/validate-gate.sh"
}

# ---------- AC1: SKILL.md exists with valid frontmatter and gate integration ----------

@test "AC1: SKILL.md exists at gaia-deploy-checklist skill directory" {
  [ -f "$SKILL_FILE" ]
}

@test "AC1: SKILL.md has YAML frontmatter delimiters" {
  head -1 "$SKILL_FILE" | grep -q "^---$"
  awk 'NR>1 && /^---$/{found=1; exit} END{exit !found}' "$SKILL_FILE"
}

@test "AC1: SKILL.md frontmatter contains name: gaia-deploy-checklist" {
  awk '/^---$/{n++; next} n==1{print}' "$SKILL_FILE" | grep -q "^name: gaia-deploy-checklist"
}

@test "AC1: SKILL.md frontmatter contains description field" {
  awk '/^---$/{n++; next} n==1{print}' "$SKILL_FILE" | grep -q "^description:"
}

@test "AC1: SKILL.md references validate-gate.sh for gate checks" {
  grep -q "validate-gate" "$SKILL_FILE"
}

@test "AC1: SKILL.md references traceability gate" {
  grep -qi "traceability" "$SKILL_FILE"
}

@test "AC1: SKILL.md references CI gate" {
  grep -qi "ci.*gate\|ci_setup_exists\|ci.*pipeline\|ci.*config" "$SKILL_FILE"
}

@test "AC1: SKILL.md references readiness gate" {
  grep -qi "readiness" "$SKILL_FILE"
}

# ---------- AC2: Gate failure produces actionable error ----------

@test "AC2: SKILL.md contains halt/error handling for gate failures" {
  grep -qi "halt\|error\|fail" "$SKILL_FILE"
}

@test "AC2: SKILL.md identifies which specific gate failed" {
  grep -qi "which.*gate\|specific.*gate\|gate.*failed\|traceability.*gate.*failed\|ci.*gate.*failed\|readiness.*gate.*failed" "$SKILL_FILE"
}

# ---------- AC3: Deployment checklist content coverage ----------

@test "AC3: SKILL.md covers infrastructure readiness" {
  grep -qi "infrastructure" "$SKILL_FILE"
}

@test "AC3: SKILL.md covers rollback plan" {
  grep -qi "rollback" "$SKILL_FILE"
}

@test "AC3: SKILL.md covers environment configuration" {
  grep -qi "environment.*config\|env.*config" "$SKILL_FILE"
}

@test "AC3: SKILL.md covers monitoring setup" {
  grep -qi "monitoring" "$SKILL_FILE"
}

@test "AC3: SKILL.md covers health check endpoints" {
  grep -qi "health.*check" "$SKILL_FILE"
}

@test "AC3: SKILL.md covers database migration status" {
  grep -qi "database.*migration\|migration.*status" "$SKILL_FILE"
}

@test "AC3: SKILL.md covers DNS/CDN readiness" {
  grep -qi "dns\|cdn" "$SKILL_FILE"
}

@test "AC3: SKILL.md covers secrets rotation" {
  grep -qi "secret" "$SKILL_FILE"
}

# ---------- AC4: Shared setup.sh/finalize.sh pattern ----------

@test "AC4: setup.sh exists and is executable" {
  [ -x "$SETUP_SCRIPT" ]
}

@test "AC4: finalize.sh exists and is executable" {
  [ -x "$FINALIZE_SCRIPT" ]
}

@test "AC4: setup.sh calls resolve-config.sh" {
  grep -q "resolve-config.sh" "$SETUP_SCRIPT"
}

@test "AC4: setup.sh calls validate-gate.sh" {
  grep -q "validate-gate.sh" "$SETUP_SCRIPT"
}

@test "AC4: setup.sh loads checkpoint" {
  grep -q "checkpoint" "$SETUP_SCRIPT"
}

@test "AC4: finalize.sh writes checkpoint" {
  grep -q "checkpoint" "$FINALIZE_SCRIPT"
}

@test "AC4: finalize.sh emits lifecycle event" {
  grep -q "lifecycle-event" "$FINALIZE_SCRIPT"
}

@test "AC4: SKILL.md invokes setup.sh at entry" {
  grep -q '!.*setup\.sh' "$SKILL_FILE"
}

@test "AC4: SKILL.md invokes finalize.sh at exit" {
  grep -q '!.*finalize\.sh' "$SKILL_FILE"
}

# ---------- AC5: validate-gate.sh blocks when traceability missing ----------

@test "AC5: validate-gate.sh fails when traceability matrix is missing" {
  # Create a temp dir with no traceability file
  local tmpdir
  tmpdir="$(mktemp -d)"
  mkdir -p "$tmpdir/docs/test-artifacts"
  # No traceability-matrix.md created — should fail
  run env TEST_ARTIFACTS="$tmpdir/docs/test-artifacts" \
      "$VALIDATE_GATE" traceability_exists
  [ "$status" -ne 0 ]
  [[ "$output" == *"traceability_exists failed"* ]]
  rm -rf "$tmpdir"
}

@test "AC5: validate-gate.sh passes when traceability matrix exists" {
  local tmpdir
  tmpdir="$(mktemp -d)"
  mkdir -p "$tmpdir/docs/test-artifacts"
  echo "# Traceability Matrix" > "$tmpdir/docs/test-artifacts/traceability-matrix.md"
  run env TEST_ARTIFACTS="$tmpdir/docs/test-artifacts" \
      "$VALIDATE_GATE" traceability_exists
  [ "$status" -eq 0 ]
  rm -rf "$tmpdir"
}

# ---------- AC-EC1: validate-gate.sh not found detection ----------

@test "AC-EC1: setup.sh checks for validate-gate.sh existence" {
  grep -q "validate-gate\|VALIDATE_GATE" "$SETUP_SCRIPT"
}

# ---------- AC-EC3: Empty traceability file treated as missing ----------

@test "AC-EC3: validate-gate.sh treats empty traceability file as missing" {
  local tmpdir
  tmpdir="$(mktemp -d)"
  mkdir -p "$tmpdir/docs/test-artifacts"
  touch "$tmpdir/docs/test-artifacts/traceability-matrix.md"  # 0 bytes
  run env TEST_ARTIFACTS="$tmpdir/docs/test-artifacts" \
      "$VALIDATE_GATE" traceability_exists
  # Empty file should be treated as missing — non-zero exit
  [ "$status" -ne 0 ]
  rm -rf "$tmpdir"
}

# ---------- AC-EC4: CI gate fails independently ----------

@test "AC-EC4: validate-gate.sh fails on CI gate when ci-setup.md missing" {
  local tmpdir
  tmpdir="$(mktemp -d)"
  mkdir -p "$tmpdir/docs/test-artifacts"
  mkdir -p "$tmpdir/docs/planning-artifacts"
  # Create traceability and readiness but NOT ci-setup
  # E28-S152: readiness-report.md lives under PLANNING_ARTIFACTS
  echo "# Trace" > "$tmpdir/docs/test-artifacts/traceability-matrix.md"
  echo "# Ready" > "$tmpdir/docs/planning-artifacts/readiness-report.md"
  run env TEST_ARTIFACTS="$tmpdir/docs/test-artifacts" \
      PLANNING_ARTIFACTS="$tmpdir/docs/planning-artifacts" \
      "$VALIDATE_GATE" ci_setup_exists
  [ "$status" -ne 0 ]
  [[ "$output" == *"ci_setup_exists failed"* ]]
  rm -rf "$tmpdir"
}

# ---------- AC-EC6: Missing docs/ directory ----------

@test "AC-EC6: validate-gate.sh fails with non-existent artifacts path" {
  local tmpdir
  tmpdir="$(mktemp -d)"
  # No docs/ directory at all
  run env TEST_ARTIFACTS="$tmpdir/nonexistent/test-artifacts" \
      "$VALIDATE_GATE" traceability_exists
  [ "$status" -ne 0 ]
  rm -rf "$tmpdir"
}

# ---------- Multi-gate chain tests ----------

@test "multi-gate: all three deployment gates pass when artifacts exist" {
  local tmpdir
  tmpdir="$(mktemp -d)"
  mkdir -p "$tmpdir/docs/test-artifacts"
  mkdir -p "$tmpdir/docs/planning-artifacts"
  # E28-S152: readiness-report.md lives under PLANNING_ARTIFACTS
  echo "# Trace" > "$tmpdir/docs/test-artifacts/traceability-matrix.md"
  echo "# CI" > "$tmpdir/docs/test-artifacts/ci-setup.md"
  echo "# Ready" > "$tmpdir/docs/planning-artifacts/readiness-report.md"
  run env TEST_ARTIFACTS="$tmpdir/docs/test-artifacts" \
      PLANNING_ARTIFACTS="$tmpdir/docs/planning-artifacts" \
      "$VALIDATE_GATE" --multi traceability_exists,ci_setup_exists,readiness_report_exists
  [ "$status" -eq 0 ]
  rm -rf "$tmpdir"
}

@test "multi-gate: chain fails when any gate fails" {
  local tmpdir
  tmpdir="$(mktemp -d)"
  mkdir -p "$tmpdir/docs/test-artifacts"
  mkdir -p "$tmpdir/docs/planning-artifacts"
  echo "# Trace" > "$tmpdir/docs/test-artifacts/traceability-matrix.md"
  # Missing ci-setup.md and readiness-report.md
  run env TEST_ARTIFACTS="$tmpdir/docs/test-artifacts" \
      PLANNING_ARTIFACTS="$tmpdir/docs/planning-artifacts" \
      "$VALIDATE_GATE" --multi traceability_exists,ci_setup_exists,readiness_report_exists
  [ "$status" -ne 0 ]
  [[ "$output" == *"ci_setup_exists failed"* ]]
  rm -rf "$tmpdir"
}
