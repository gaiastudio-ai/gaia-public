#!/usr/bin/env bash
# generate-cluster-8-report.sh — Cluster 8 sprint-cycle pass/fail PR report (E28-S65, AC4)
#
# Runs the 4 Cluster 8 skills' setup.sh + finalize.sh, captures per-hop
# timing and exit codes, diffs sprint-status.yaml against expected snapshots,
# and writes a markdown report.
#
# Usage: generate-cluster-8-report.sh <output-path> <repo-root>
#
# Exit codes:
#   0 — report generated (regardless of individual hop pass/fail)
#   1 — usage error

set -euo pipefail
LC_ALL=C
export LC_ALL

OUTPUT="${1:?Usage: generate-cluster-8-report.sh <output-path> <repo-root>}"
REPO_ROOT="${2:?Usage: generate-cluster-8-report.sh <output-path> <repo-root>}"

SKILLS_DIR="$REPO_ROOT/plugins/gaia/skills"
FIXTURE_DIR="$REPO_ROOT/tests/fixtures/cluster-8-sprint-cycle"

HOPS=(
  gaia-sprint-plan
  gaia-sprint-status
  gaia-correct-course
  gaia-retro
)

EXPECTED_SNAPSHOTS=(
  after-plan.yaml
  after-status.yaml
  after-correct-course.yaml
  after-retro.yaml
)

# Setup temp workspace for the report run
REPORT_TMP="$(mktemp -d)"
trap 'rm -rf "$REPORT_TMP"' EXIT

export GAIA_PROJECT_ROOT="$REPORT_TMP"
export GAIA_PROJECT_PATH="$REPORT_TMP"
export GAIA_MEMORY_PATH="$REPORT_TMP/memory"
export GAIA_CHECKPOINT_PATH="$REPORT_TMP/checkpoints"
export GAIA_INSTALLED_PATH="$REPO_ROOT/plugins/gaia"
export CLAUDE_SKILL_DIR="$REPORT_TMP"
export MEMORY_PATH="$REPORT_TMP/memory"
export CHECKPOINT_PATH="$REPORT_TMP/checkpoints"
export PROJECT_ROOT="$REPORT_TMP"
export PROJECT_PATH="$REPORT_TMP"
export IMPLEMENTATION_ARTIFACTS="$REPORT_TMP/docs/implementation-artifacts"

mkdir -p "$REPORT_TMP/checkpoints" "$REPORT_TMP/memory" \
         "$REPORT_TMP/docs/implementation-artifacts/stories" \
         "$REPORT_TMP/docs/planning-artifacts" \
         "$REPORT_TMP/docs/test-artifacts" \
         "$REPORT_TMP/config"

# Copy fixture files
cp "$FIXTURE_DIR/config/project-config.yaml" "$REPORT_TMP/config/"
cp "$FIXTURE_DIR/epics-and-stories.md" "$REPORT_TMP/docs/planning-artifacts/"
cp "$FIXTURE_DIR/architecture.md" "$REPORT_TMP/docs/planning-artifacts/"
cp "$FIXTURE_DIR/sprint-status.yaml" "$REPORT_TMP/docs/implementation-artifacts/"
cp "$FIXTURE_DIR"/stories/*.md "$REPORT_TMP/docs/implementation-artifacts/stories/"
for f in "$FIXTURE_DIR"/stories/*.md; do
  cp "$f" "$REPORT_TMP/docs/implementation-artifacts/$(basename "$f")"
done

# Normalize YAML for diffing
normalize_yaml() {
  grep -v '^#' "$1" | grep -v '^$' | LC_ALL=C sort
}

# ---------- Run chain and collect results ----------

total_pass=0
total_fail=0
rows=""
first_fail_diff=""

for i in "${!HOPS[@]}"; do
  skill="${HOPS[$i]}"
  snap="${EXPECTED_SNAPSHOTS[$i]}"
  hop_num=$((i + 1))

  start_ts=$(date +%s)
  setup_rc=0
  finalize_rc=0

  # Run setup
  if [ -f "$SKILLS_DIR/$skill/scripts/setup.sh" ]; then
    bash "$SKILLS_DIR/$skill/scripts/setup.sh" >/dev/null 2>&1 || setup_rc=$?
  else
    setup_rc=127
  fi

  # Run finalize
  if [ -f "$SKILLS_DIR/$skill/scripts/finalize.sh" ]; then
    bash "$SKILLS_DIR/$skill/scripts/finalize.sh" >/dev/null 2>&1 || finalize_rc=$?
  else
    finalize_rc=127
  fi

  end_ts=$(date +%s)
  duration=$((end_ts - start_ts))

  # Diff sprint-status.yaml against expected
  diff_rc=0
  diff_output=""
  if [ -f "$FIXTURE_DIR/expected/$snap" ]; then
    actual="$(normalize_yaml "$REPORT_TMP/docs/implementation-artifacts/sprint-status.yaml")"
    expected="$(normalize_yaml "$FIXTURE_DIR/expected/$snap")"
    if [ "$actual" != "$expected" ]; then
      diff_rc=1
      diff_output="$(diff -u <(echo "$expected") <(echo "$actual") 2>&1 || true)"
    fi
  else
    diff_rc=2
    diff_output="Expected snapshot $snap not found"
  fi

  # Determine hop verdict
  if [ "$setup_rc" -eq 0 ] && [ "$finalize_rc" -eq 0 ] && [ "$diff_rc" -eq 0 ]; then
    hop_status="PASS"
    total_pass=$((total_pass + 1))
  else
    hop_status="FAIL"
    total_fail=$((total_fail + 1))
    if [ -z "$first_fail_diff" ] && [ -n "$diff_output" ]; then
      first_fail_diff="Hop $hop_num ($skill):\n$diff_output"
    fi
  fi

  rows="$rows| $hop_num | $skill | $hop_status | ${duration}s | setup=$setup_rc finalize=$finalize_rc diff=$diff_rc |\n"
done

# ---------- Write report ----------

verdict="PASS"
[ "$total_fail" -gt 0 ] && verdict="FAIL"

{
  echo "# Cluster 8 Sprint-Cycle Integration Report"
  echo ""
  echo "**Date:** $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "**Verdict:** $verdict ($total_pass passed, $total_fail failed)"
  echo ""
  echo "## Hop Results"
  echo ""
  echo "| Hop | Skill | Status | Duration | Details |"
  echo "|-----|-------|--------|----------|---------|"
  printf '%b' "$rows"
  echo ""

  if [ -n "$first_fail_diff" ]; then
    echo "## First Failing Hop Diff"
    echo ""
    echo '```diff'
    printf '%b\n' "$first_fail_diff"
    echo '```'
    echo ""
  fi

  echo "## Invariant Check"
  echo ""
  invariant_pass=true
  for skill in "${HOPS[@]}"; do
    for script in setup.sh finalize.sh; do
      local_path="$SKILLS_DIR/$skill/scripts/$script"
      [ -f "$local_path" ] || continue
      if grep -vE '^\s*#' "$local_path" | grep -qE '(>\s*\S*sprint-status\.yaml|cp\s+\S+\s+\S*sprint-status\.yaml|mv\s+\S+\s+\S*sprint-status\.yaml|tee\s+\S*sprint-status\.yaml)' 2>/dev/null; then
        if ! grep -qE 'sprint-state\.sh' "$local_path" 2>/dev/null; then
          echo "- BREACH: $skill/$script writes sprint-status.yaml directly"
          invariant_pass=false
        fi
      fi
    done
  done
  if [ "$invariant_pass" = true ]; then
    echo "- sprint-state.sh is the sole writer to sprint-status.yaml: PASS"
  fi
} > "$OUTPUT"

echo "Report written to $OUTPUT"
exit 0
