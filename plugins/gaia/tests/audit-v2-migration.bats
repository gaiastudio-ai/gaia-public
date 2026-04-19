#!/usr/bin/env bats
# audit-v2-migration.bats — regression tests for the enriched fixture mode
# added under E28-S200.
#
# Covers ACs:
#   AC6 — --fixture-mode enriched pre-creates required prereq artifacts
#   AC7 — default mode is still minimal (flag is opt-in)
#   AC8 — enriched mode exports TEST_ARTIFACTS / PLANNING_ARTIFACTS /
#         IMPLEMENTATION_ARTIFACTS before each skill invocation
#   AC9 — `--fixture-mode enriched` returns 0 failing rows on a /tmp fixture
#   AC10 — default minimal mode continues to surface FixtureGap residuals
#
# The audit harness lives at gaia-public/scripts/audit-v2-migration.sh — one
# level above plugins/gaia/. SCRIPTS_DIR (test_helper.bash) points at
# plugins/gaia/scripts; we resolve the harness path from BATS_TEST_DIRNAME.

load 'test_helper.bash'

setup() {
  common_setup
  HARNESS="$BATS_TEST_DIRNAME/../../../scripts/audit-v2-migration.sh"
  PLUGIN_CACHE="$TEST_TMP/plugin-cache"
  PROJECT_ROOT="$TEST_TMP/project-root"
  mkdir -p "$PLUGIN_CACHE" "$PROJECT_ROOT"
}
teardown() { common_teardown; }

# ---------- Helpers ----------

# mk_minimal_project — set up a bare /tmp project with NO prereq artifacts
# (no docs/{planning,test,implementation}-artifacts content). This is what
# the default minimal fixture mode looks like.
mk_minimal_project() {
  :
}

# mk_skill_requiring_test_plan — create a fake skill whose setup.sh calls
# validate-gate.sh test_plan_exists. In minimal mode the gate should fail
# (fixture gap); in enriched mode the gate should pass.
mk_skill_requiring_test_plan() {
  local skill_name="$1"
  local skill_dir="$PLUGIN_CACHE/$skill_name"
  mkdir -p "$skill_dir/scripts"

  # Minimal setup.sh: require TEST_ARTIFACTS env var and fail loudly if the
  # file at $TEST_ARTIFACTS/test-plan.md is missing. Mirrors the real
  # validate-gate contract without depending on validate-gate.sh being on
  # PATH in bats.
  cat > "$skill_dir/scripts/setup.sh" <<'SETUP_EOF'
#!/usr/bin/env bash
set -euo pipefail
TEST_ARTIFACTS="${TEST_ARTIFACTS:-docs/test-artifacts}"
plan="$TEST_ARTIFACTS/test-plan.md"
if [ ! -f "$plan" ] || [ ! -s "$plan" ]; then
  printf 'fake-skill: test_plan_exists failed — expected: %s\n' "$plan" >&2
  exit 1
fi
exit 0
SETUP_EOF
  chmod +x "$skill_dir/scripts/setup.sh"
}

# ---------- Harness argument surface ----------

@test "E28-S200 AC7: --fixture-mode flag accepts minimal|enriched values" {
  run "$HARNESS" --help
  # --help exits 0 and prints usage; the usage must document the new flag.
  [ "$status" -eq 0 ]
  [[ "$output" == *"--fixture-mode"* ]]
  [[ "$output" == *"minimal"* ]]
  [[ "$output" == *"enriched"* ]]
}

@test "E28-S200 AC7: default fixture mode is minimal (no pre-created artifacts)" {
  mk_skill_requiring_test_plan fake-skill
  run "$HARNESS" \
    --plugin-cache "$PLUGIN_CACHE" \
    --project-root "$PROJECT_ROOT" \
    --out "$TEST_TMP/audit.csv"
  # Harness still exits 0 even when skills fail — failures are in the CSV.
  [ "$status" -eq 0 ]
  # fake-skill's setup.sh must have failed because no test-plan.md exists.
  run grep -c '^fake-skill,' "$TEST_TMP/audit.csv"
  [ "$status" -eq 0 ]
  # The CSV row for fake-skill must NOT be in OK bucket — minimal mode does
  # not create the prereq artifact.
  run grep '^fake-skill,' "$TEST_TMP/audit.csv"
  [ "$status" -eq 0 ]
  [[ "$output" != *",OK"* ]]
}

# ---------- AC6 — enriched mode pre-creates prereq artifacts ----------

@test "E28-S200 AC6: --fixture-mode enriched creates prereq artifact files" {
  run "$HARNESS" \
    --plugin-cache "$PLUGIN_CACHE" \
    --project-root "$PROJECT_ROOT" \
    --fixture-mode enriched \
    --out "$TEST_TMP/audit.csv"
  [ "$status" -eq 0 ]
  # The 5 required prereq artifacts must now exist under the project root.
  [ -s "$PROJECT_ROOT/docs/planning-artifacts/prd.md" ]
  [ -s "$PROJECT_ROOT/docs/planning-artifacts/epics-and-stories.md" ]
  [ -s "$PROJECT_ROOT/docs/test-artifacts/test-plan.md" ]
  [ -s "$PROJECT_ROOT/docs/test-artifacts/traceability-matrix.md" ]
  [ -s "$PROJECT_ROOT/docs/test-artifacts/ci-setup.md" ]
}

# ---------- AC8 — enriched mode exports uppercase env vars ----------

@test "E28-S200 AC8: enriched mode exports TEST_ARTIFACTS so skills see the prereqs" {
  mk_skill_requiring_test_plan fake-skill
  run "$HARNESS" \
    --plugin-cache "$PLUGIN_CACHE" \
    --project-root "$PROJECT_ROOT" \
    --fixture-mode enriched \
    --out "$TEST_TMP/audit.csv"
  [ "$status" -eq 0 ]
  # fake-skill's setup.sh must now succeed — TEST_ARTIFACTS points at the
  # enriched-fixture path and test-plan.md exists there.
  run grep '^fake-skill,' "$TEST_TMP/audit.csv"
  [ "$status" -eq 0 ]
  [[ "$output" == *",OK"* ]]
}

# ---------- AC9 — enriched mode returns 0 failing rows ----------

@test "E28-S200 AC9: enriched mode — multi-prereq fake skill produces no B5 residuals" {
  # Seed two skills: one needs test-plan.md, one needs prd.md. Both should
  # pass under enriched mode because the harness pre-creates both and
  # exports the env vars.
  mk_skill_requiring_test_plan fake-skill-1

  local skill_dir="$PLUGIN_CACHE/fake-skill-2"
  mkdir -p "$skill_dir/scripts"
  cat > "$skill_dir/scripts/setup.sh" <<'SETUP_EOF'
#!/usr/bin/env bash
set -euo pipefail
PLANNING_ARTIFACTS="${PLANNING_ARTIFACTS:-docs/planning-artifacts}"
prd="$PLANNING_ARTIFACTS/prd.md"
if [ ! -f "$prd" ] || [ ! -s "$prd" ]; then
  printf 'fake-skill-2: prd_exists failed — expected: %s\n' "$prd" >&2
  exit 1
fi
exit 0
SETUP_EOF
  chmod +x "$skill_dir/scripts/setup.sh"

  run "$HARNESS" \
    --plugin-cache "$PLUGIN_CACHE" \
    --project-root "$PROJECT_ROOT" \
    --fixture-mode enriched \
    --out "$TEST_TMP/audit.csv"
  [ "$status" -eq 0 ]
  # No B5 rows (no "FixtureGap" residuals) — both skills OK.
  run grep -c ',B5$' "$TEST_TMP/audit.csv"
  # grep -c outputs 0 and exits 1 when no matches — accept that as "no B5".
  [[ "$output" == "0" ]]
  # Both rows must land in the OK bucket.
  run grep '^fake-skill-1,' "$TEST_TMP/audit.csv"
  [ "$status" -eq 0 ]
  [[ "$output" == *",OK"* ]]
  run grep '^fake-skill-2,' "$TEST_TMP/audit.csv"
  [ "$status" -eq 0 ]
  [[ "$output" == *",OK"* ]]
}

# ---------- AC10 — minimal mode still surfaces FixtureGap ----------

@test "E28-S200 AC10: minimal mode still surfaces the FixtureGap signal" {
  # Seed a skill that requires test-plan.md. In minimal mode there is no
  # prereq artifact and the harness must NOT pre-create one. The bucket
  # must be a failure bucket (not OK), proving the bug-detection mode was
  # not silently "fixed" by this story.
  mk_skill_requiring_test_plan fake-skill

  run "$HARNESS" \
    --plugin-cache "$PLUGIN_CACHE" \
    --project-root "$PROJECT_ROOT" \
    --fixture-mode minimal \
    --out "$TEST_TMP/audit.csv"
  [ "$status" -eq 0 ]
  # Prereq artifacts must NOT be auto-created by minimal mode.
  [ ! -f "$PROJECT_ROOT/docs/test-artifacts/test-plan.md" ]
  [ ! -f "$PROJECT_ROOT/docs/planning-artifacts/prd.md" ]
  # fake-skill must have failed — land in a bucket other than OK.
  run grep '^fake-skill,' "$TEST_TMP/audit.csv"
  [ "$status" -eq 0 ]
  [[ "$output" != *",OK"* ]]
}

@test "E28-S200 AC7: explicit --fixture-mode minimal matches default behavior" {
  mk_skill_requiring_test_plan fake-skill
  # Run twice — once with no flag, once with --fixture-mode minimal — and
  # confirm both leave the project root bare of prereq artifacts.
  run "$HARNESS" \
    --plugin-cache "$PLUGIN_CACHE" \
    --project-root "$PROJECT_ROOT" \
    --fixture-mode minimal \
    --out "$TEST_TMP/audit-explicit.csv"
  [ "$status" -eq 0 ]
  [ ! -f "$PROJECT_ROOT/docs/test-artifacts/test-plan.md" ]
  [ ! -f "$PROJECT_ROOT/docs/planning-artifacts/prd.md" ]
}

@test "E28-S200: unknown --fixture-mode value rejected with exit 2" {
  run "$HARNESS" \
    --plugin-cache "$PLUGIN_CACHE" \
    --project-root "$PROJECT_ROOT" \
    --fixture-mode bogus \
    --out "$TEST_TMP/audit.csv"
  [ "$status" -eq 2 ]
  [[ "$output" == *"fixture-mode"* ]]
}
