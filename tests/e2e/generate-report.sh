#!/usr/bin/env bash
# generate-report.sh — Cluster 4 e2e pass/fail PR report (E28-S39, AC5)
#
# Runs all 6 Cluster 4 analysis skills' setup.sh + finalize.sh, captures
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

SKILLS=(
  gaia-brainstorm
  gaia-product-brief
  gaia-market-research
  gaia-domain-research
  gaia-tech-research
  gaia-advanced-elicitation
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

mkdir -p "$REPORT_TMP/memory" "$REPORT_TMP/checkpoints" "$REPORT_TMP/config"
cp "$REPO_ROOT/tests/fixtures/cluster-4-e2e/config/project-config.yaml" \
   "$REPORT_TMP/config/project-config.yaml"

overall_pass=true
total_elapsed=0

# Build report lines
report_lines=()

for skill in "${SKILLS[@]}"; do
  setup_script="$SKILLS_DIR/$skill/scripts/setup.sh"
  finalize_script="$SKILLS_DIR/$skill/scripts/finalize.sh"

  setup_status="SKIP"
  finalize_status="SKIP"
  skill_start=$(date +%s)

  # Run setup
  if [ -f "$setup_script" ]; then
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

  skill_end=$(date +%s)
  skill_duration=$((skill_end - skill_start))
  total_elapsed=$((total_elapsed + skill_duration))

  if [ "$setup_status" = "PASS" ] && [ "$finalize_status" = "PASS" ]; then
    combined="PASS"
  else
    combined="FAIL"
  fi

  report_lines+=("| $skill | $combined | ${skill_duration}s | setup=$setup_status finalize=$finalize_status |")
done

# Write the report
if $overall_pass; then
  verdict="PASS"
else
  verdict="FAIL"
fi

cat > "$OUTPUT" <<REPORT
# Cluster 4 Analysis Skills — E2E Report

**Verdict:** $verdict
**Total duration:** ${total_elapsed}s
**Date:** $(date -u +"%Y-%m-%dT%H:%M:%SZ")

## Per-Skill Results

| Skill | Status | Duration | Details |
|-------|--------|----------|---------|
$(printf '%s\n' "${report_lines[@]}")

## Diff Summary

No byte-for-byte artifact comparison performed (reference artifacts pending).

## Notes

- All 6 Cluster 4 analysis skills were exercised via setup.sh + finalize.sh
- Checkpoint and lifecycle-event emission verified by the bats suite
REPORT

echo "Report written to $OUTPUT"
exit 0
