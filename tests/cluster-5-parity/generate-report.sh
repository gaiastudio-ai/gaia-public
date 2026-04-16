#!/usr/bin/env bash
# generate-report.sh — Cluster 5 parity pass/fail PR report (E28-S44, AC4)
#
# Runs all 5 Cluster 5 planning skills' setup.sh + finalize.sh, captures
# per-skill timing and exit codes, and writes a markdown report.
#
# Usage: generate-report.sh <output-path> <repo-root>
#
# Exit codes:
#   0 — report generated (regardless of individual skill pass/fail)
#   1 — usage error

set -euo pipefail
LC_ALL=C
export LC_ALL

OUTPUT="${1:?Usage: generate-report.sh <output-path> <repo-root>}"
REPO_ROOT="${2:?Usage: generate-report.sh <output-path> <repo-root>}"

SKILLS_DIR="$REPO_ROOT/plugins/gaia/skills"
FIXTURE_DIR="$REPO_ROOT/tests/cluster-5-parity/fixture"

SKILLS=(
  gaia-create-prd
  gaia-edit-prd
  gaia-validate-prd
  gaia-create-ux
  gaia-edit-ux
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

mkdir -p "$REPORT_TMP/memory" "$REPORT_TMP/checkpoints" \
         "$REPORT_TMP/docs/planning-artifacts" "$REPORT_TMP/config"
cp "$FIXTURE_DIR/config/project-config.yaml" "$REPORT_TMP/config/project-config.yaml"
cp "$FIXTURE_DIR/product-brief.md" "$REPORT_TMP/docs/planning-artifacts/" 2>/dev/null || true
cp "$FIXTURE_DIR/prd.md" "$REPORT_TMP/docs/planning-artifacts/" 2>/dev/null || true
cp "$FIXTURE_DIR/ux-design.md" "$REPORT_TMP/docs/planning-artifacts/" 2>/dev/null || true

overall_pass=true
total_elapsed=0

{
  printf '# Cluster 5 Parity Test Report\n\n'
  printf '| Skill | Setup | Finalize | Time (s) | Status |\n'
  printf '|-------|-------|----------|----------|--------|\n'

  for skill in "${SKILLS[@]}"; do
    setup_script="$SKILLS_DIR/$skill/scripts/setup.sh"
    finalize_script="$SKILLS_DIR/$skill/scripts/finalize.sh"

    setup_status="SKIP"
    finalize_status="SKIP"
    skill_status="SKIP"
    elapsed=0

    start_time=$(date +%s)

    # Run setup
    if [ -f "$setup_script" ]; then
      chmod +x "$setup_script"
      if bash "$setup_script" >/dev/null 2>&1; then
        setup_status="PASS"
      else
        setup_status="FAIL"
        overall_pass=false
      fi
    else
      setup_status="MISSING"
      overall_pass=false
    fi

    # Run finalize
    if [ -f "$finalize_script" ]; then
      chmod +x "$finalize_script"
      if bash "$finalize_script" >/dev/null 2>&1; then
        finalize_status="PASS"
      else
        finalize_status="FAIL"
        overall_pass=false
      fi
    else
      finalize_status="MISSING"
      overall_pass=false
    fi

    end_time=$(date +%s)
    elapsed=$(( end_time - start_time ))
    total_elapsed=$(( total_elapsed + elapsed ))

    # Determine overall skill status
    if [ "$setup_status" = "PASS" ] && [ "$finalize_status" = "PASS" ]; then
      skill_status="PASS"
    else
      skill_status="FAIL"
    fi

    printf '| %s | %s | %s | %d | %s |\n' \
      "$skill" "$setup_status" "$finalize_status" "$elapsed" "$skill_status"
  done

  printf '\n**Total time:** %ds\n' "$total_elapsed"

  if $overall_pass; then
    printf '**Overall:** PASS\n'
  else
    printf '**Overall:** FAIL\n'
  fi
} > "$OUTPUT"

printf 'Report written to %s\n' "$OUTPUT"
