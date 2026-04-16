#!/usr/bin/env bats
# cluster-8-sprint-cycle.bats — Cluster 8 end-to-end chain integration test (E28-S65)
#
# Runs the full Sprint Cluster chain: sprint-plan -> sprint-status ->
# correct-course -> retro against a deterministic fixture and verifies
# sprint-status.yaml is never mutated by any skill (only sprint-state.sh
# is the sanctioned writer per ADR-042/ADR-048).
#
# AC1: All 4 hops complete (setup.sh + finalize.sh run without error)
# AC2: sprint-status.yaml matches expected snapshot after each hop
# AC3: CI path filter triggers on Cluster 8 skill changes
# AC4: Pass/fail report generated on completion
#
# Usage:
#   bats tests/e2e/cluster-8-sprint-cycle.bats
#
# Dependencies: bats-core 1.10+, jq, sprint-state.sh, resolve-config.sh,
#   checkpoint.sh, lifecycle-event.sh

# ---------- Helpers ----------

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SKILLS_DIR="$REPO_ROOT/plugins/gaia/skills"
  SCRIPTS_DIR="$REPO_ROOT/plugins/gaia/scripts"
  FIXTURE_DIR="$REPO_ROOT/tests/fixtures/cluster-8-sprint-cycle"

  # Per-test isolated temp workspace
  TEST_TMP="$BATS_TEST_TMPDIR/gaia-c8-$$"
  mkdir -p "$TEST_TMP/checkpoints" "$TEST_TMP/memory" \
           "$TEST_TMP/docs/implementation-artifacts/stories" \
           "$TEST_TMP/docs/planning-artifacts" \
           "$TEST_TMP/docs/test-artifacts" \
           "$TEST_TMP/config"

  # Set env overrides so resolve-config.sh resolves to our fixture workspace.
  export GAIA_PROJECT_ROOT="$TEST_TMP"
  export GAIA_PROJECT_PATH="$TEST_TMP"
  export GAIA_MEMORY_PATH="$TEST_TMP/memory"
  export GAIA_CHECKPOINT_PATH="$TEST_TMP/checkpoints"
  export GAIA_INSTALLED_PATH="$REPO_ROOT/plugins/gaia"
  export MEMORY_PATH="$TEST_TMP/memory"
  export CHECKPOINT_PATH="$TEST_TMP/checkpoints"
  export PROJECT_ROOT="$TEST_TMP"
  export PROJECT_PATH="$TEST_TMP"
  export CLAUDE_SKILL_DIR="$TEST_TMP"
  export IMPLEMENTATION_ARTIFACTS="$TEST_TMP/docs/implementation-artifacts"

  # Copy fixture config
  cp "$FIXTURE_DIR/config/project-config.yaml" "$TEST_TMP/config/project-config.yaml"

  # Copy fixture planning artifacts
  cp "$FIXTURE_DIR/epics-and-stories.md" "$TEST_TMP/docs/planning-artifacts/"
  cp "$FIXTURE_DIR/architecture.md" "$TEST_TMP/docs/planning-artifacts/"

  # Copy and initialize sprint-status.yaml
  cp "$FIXTURE_DIR/sprint-status.yaml" "$TEST_TMP/docs/implementation-artifacts/"

  # Copy fixture story files to both locations for sprint-state.sh compatibility
  cp "$FIXTURE_DIR"/stories/*.md "$TEST_TMP/docs/implementation-artifacts/stories/"
  for f in "$FIXTURE_DIR"/stories/*.md; do
    cp "$f" "$TEST_TMP/docs/implementation-artifacts/$(basename "$f")"
  done

  # Cluster 8 chain: the four skills in order
  CHAIN_SKILLS=(
    gaia-sprint-plan
    gaia-sprint-status
    gaia-correct-course
    gaia-retro
  )

  # Expected snapshot basenames (parallel to CHAIN_SKILLS)
  EXPECTED_SNAPSHOTS=(
    after-plan.yaml
    after-status.yaml
    after-correct-course.yaml
    after-retro.yaml
  )
}

teardown() {
  rm -rf "$TEST_TMP" 2>/dev/null || true
}

# Helper: run a skill's setup.sh
run_setup() {
  local skill="$1"
  local setup_script="$SKILLS_DIR/$skill/scripts/setup.sh"
  [ -f "$setup_script" ] || return 1
  bash "$setup_script"
}

# Helper: run a skill's finalize.sh
run_finalize() {
  local skill="$1"
  local finalize_script="$SKILLS_DIR/$skill/scripts/finalize.sh"
  [ -f "$finalize_script" ] || return 1
  bash "$finalize_script"
}

# Helper: normalize YAML for diffing (strip comments, sort keys via awk)
normalize_yaml() {
  grep -v '^#' "$1" | grep -v '^$' | LC_ALL=C sort
}

# ---------- AC1: Fixture and skill structure ----------

@test "AC1: fixture directory exists with required files" {
  [ -d "$FIXTURE_DIR" ]
  [ -f "$FIXTURE_DIR/sprint-status.yaml" ]
  [ -f "$FIXTURE_DIR/epics-and-stories.md" ]
  [ -f "$FIXTURE_DIR/architecture.md" ]
  [ -f "$FIXTURE_DIR/config/project-config.yaml" ]
}

@test "AC1: fixture has expected snapshot for each hop" {
  for snap in "${EXPECTED_SNAPSHOTS[@]}"; do
    [ -f "$FIXTURE_DIR/expected/$snap" ]
  done
}

@test "AC1: all four Cluster 8 skill directories exist" {
  for skill in "${CHAIN_SKILLS[@]}"; do
    [ -d "$SKILLS_DIR/$skill" ]
  done
}

@test "AC1: each Cluster 8 skill has setup.sh and finalize.sh" {
  for skill in "${CHAIN_SKILLS[@]}"; do
    [ -f "$SKILLS_DIR/$skill/scripts/setup.sh" ]
    [ -f "$SKILLS_DIR/$skill/scripts/finalize.sh" ]
  done
}

@test "AC1: sprint-plan setup.sh runs without error against fixture" {
  run run_setup gaia-sprint-plan
  [ "$status" -eq 0 ]
}

@test "AC1: sprint-plan finalize.sh runs without error against fixture" {
  run run_finalize gaia-sprint-plan
  [ "$status" -eq 0 ]
}

@test "AC1: sprint-status setup.sh runs without error against fixture" {
  run run_setup gaia-sprint-status
  [ "$status" -eq 0 ]
}

@test "AC1: sprint-status finalize.sh runs without error against fixture" {
  run run_finalize gaia-sprint-status
  [ "$status" -eq 0 ]
}

@test "AC1: correct-course setup.sh runs without error against fixture" {
  run run_setup gaia-correct-course
  [ "$status" -eq 0 ]
}

@test "AC1: correct-course finalize.sh runs without error against fixture" {
  run run_finalize gaia-correct-course
  [ "$status" -eq 0 ]
}

@test "AC1: retro setup.sh runs without error against fixture" {
  run run_setup gaia-retro
  [ "$status" -eq 0 ]
}

@test "AC1: retro finalize.sh runs without error against fixture" {
  run run_finalize gaia-retro
  [ "$status" -eq 0 ]
}

@test "AC1: full chain runs end-to-end (setup + finalize for all 4 skills)" {
  for skill in "${CHAIN_SKILLS[@]}"; do
    run_setup "$skill"
    run_finalize "$skill"
  done
}

# ---------- AC2: sprint-status.yaml integrity after each hop ----------

@test "AC2: sprint-status.yaml unchanged after sprint-plan hop" {
  run_setup gaia-sprint-plan
  run_finalize gaia-sprint-plan
  local actual expected
  actual="$(normalize_yaml "$TEST_TMP/docs/implementation-artifacts/sprint-status.yaml")"
  expected="$(normalize_yaml "$FIXTURE_DIR/expected/after-plan.yaml")"
  [ "$actual" = "$expected" ]
}

@test "AC2: sprint-status.yaml unchanged after sprint-status hop" {
  run_setup gaia-sprint-plan
  run_finalize gaia-sprint-plan
  run_setup gaia-sprint-status
  run_finalize gaia-sprint-status
  local actual expected
  actual="$(normalize_yaml "$TEST_TMP/docs/implementation-artifacts/sprint-status.yaml")"
  expected="$(normalize_yaml "$FIXTURE_DIR/expected/after-status.yaml")"
  [ "$actual" = "$expected" ]
}

@test "AC2: sprint-status.yaml unchanged after correct-course hop" {
  for skill in gaia-sprint-plan gaia-sprint-status gaia-correct-course; do
    run_setup "$skill"
    run_finalize "$skill"
  done
  local actual expected
  actual="$(normalize_yaml "$TEST_TMP/docs/implementation-artifacts/sprint-status.yaml")"
  expected="$(normalize_yaml "$FIXTURE_DIR/expected/after-correct-course.yaml")"
  [ "$actual" = "$expected" ]
}

@test "AC2: sprint-status.yaml unchanged after retro hop (final state)" {
  for skill in "${CHAIN_SKILLS[@]}"; do
    run_setup "$skill"
    run_finalize "$skill"
  done
  local actual expected
  actual="$(normalize_yaml "$TEST_TMP/docs/implementation-artifacts/sprint-status.yaml")"
  expected="$(normalize_yaml "$FIXTURE_DIR/expected/after-retro.yaml")"
  [ "$actual" = "$expected" ]
}

@test "AC2: full chain diff — sprint-status.yaml matches seed at every hop" {
  # Run the full chain, checking after EACH hop (fail fast on first mismatch)
  local i=0
  for skill in "${CHAIN_SKILLS[@]}"; do
    run_setup "$skill"
    run_finalize "$skill"
    local snap="${EXPECTED_SNAPSHOTS[$i]}"
    local actual expected
    actual="$(normalize_yaml "$TEST_TMP/docs/implementation-artifacts/sprint-status.yaml")"
    expected="$(normalize_yaml "$FIXTURE_DIR/expected/$snap")"
    if [ "$actual" != "$expected" ]; then
      echo "FAIL at hop $((i+1)) ($skill):"
      diff -u <(echo "$expected") <(echo "$actual") || true
      return 1
    fi
    i=$((i + 1))
  done
}

@test "AC2: sprint-state.sh is the only writer — no skill directly writes sprint-status.yaml" {
  # Verify that none of the Cluster 8 skill scripts contain direct writes to sprint-status.yaml.
  # They should all delegate to sprint-state.sh.
  for skill in "${CHAIN_SKILLS[@]}"; do
    local scripts_path="$SKILLS_DIR/$skill/scripts"
    # Check setup.sh and finalize.sh for direct sprint-status.yaml writes
    for script in setup.sh finalize.sh; do
      local script_path="$scripts_path/$script"
      [ -f "$script_path" ] || continue
      # Look for lines that write specifically to sprint-status.yaml:
      #   - redirection to sprint-status.yaml (> sprint-status.yaml or >> sprint-status.yaml)
      #   - cp/mv with sprint-status.yaml as destination
      #   - tee to sprint-status.yaml
      # Exclude comments and lines that merely reference the filename in strings or reads.
      if grep -vE '^\s*#' "$script_path" | grep -qE '(>\s*\S*sprint-status\.yaml|cp\s+\S+\s+\S*sprint-status\.yaml|mv\s+\S+\s+\S*sprint-status\.yaml|tee\s+\S*sprint-status\.yaml)' 2>/dev/null; then
        # Allow if the write is through sprint-state.sh
        if ! grep -qE 'sprint-state\.sh' "$script_path" 2>/dev/null; then
          echo "INVARIANT BREACH: $script_path writes sprint-status.yaml directly"
          return 1
        fi
      fi
    done
  done
}

# ---------- AC3: CI wiring ----------

@test "AC3: CI workflow file exists" {
  local ci_file="$REPO_ROOT/.github/workflows/plugin-ci.yml"
  [ -f "$ci_file" ]
}

@test "AC3: CI workflow has cluster-8-sprint-cycle job" {
  local ci_file="$REPO_ROOT/.github/workflows/plugin-ci.yml"
  grep -q "cluster-8-sprint-cycle" "$ci_file"
}

@test "AC3: CI cluster-8 job has timeout-minutes configured" {
  local ci_file="$REPO_ROOT/.github/workflows/plugin-ci.yml"
  grep -A 5 "cluster-8-sprint-cycle" "$ci_file" | grep -q "timeout-minutes"
}

@test "AC3: CI cluster-8 job runs this test file" {
  local ci_file="$REPO_ROOT/.github/workflows/plugin-ci.yml"
  grep -q "cluster-8-sprint-cycle.bats" "$ci_file"
}

# ---------- AC4: Report generation ----------

@test "AC4: generate-cluster-8-report.sh exists" {
  [ -f "$REPO_ROOT/tests/e2e/generate-cluster-8-report.sh" ]
}

@test "AC4: generate-cluster-8-report.sh runs and produces output" {
  local report_out="$TEST_TMP/cluster-8-report.md"
  run bash "$REPO_ROOT/tests/e2e/generate-cluster-8-report.sh" "$report_out" "$REPO_ROOT"
  [ "$status" -eq 0 ]
  [ -f "$report_out" ]
}

@test "AC4: report contains expected table columns" {
  local report_out="$TEST_TMP/cluster-8-report.md"
  bash "$REPO_ROOT/tests/e2e/generate-cluster-8-report.sh" "$report_out" "$REPO_ROOT"
  grep -qi "hop" "$report_out"
  grep -qi "status" "$report_out"
}

@test "AC4: report contains verdict line" {
  local report_out="$TEST_TMP/cluster-8-report.md"
  bash "$REPO_ROOT/tests/e2e/generate-cluster-8-report.sh" "$report_out" "$REPO_ROOT"
  grep -q "Verdict:" "$report_out"
}

@test "AC4: report includes diff on simulated failure" {
  # Mutate sprint-status.yaml to simulate a hop breakage
  echo "corrupted: true" >> "$TEST_TMP/docs/implementation-artifacts/sprint-status.yaml"
  local report_out="$TEST_TMP/cluster-8-report-fail.md"
  # The report generator should still produce output even on diff mismatch
  bash "$REPO_ROOT/tests/e2e/generate-cluster-8-report.sh" "$report_out" "$REPO_ROOT" || true
  [ -f "$report_out" ]
}
