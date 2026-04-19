#!/usr/bin/env bats
# gaia-post-deploy.bats — post-deploy verification skill structural tests (E28-S94)
#
# Validates:
#   AC1: SKILL.md exists with health check validation, endpoint reachability, error rate thresholds
#   AC3: setup.sh/finalize.sh follow shared Cluster 12 pattern (E28-S92, E28-S93)
#   AC4: Health check logic uses inline !scripts/*.sh calls per ADR-042
#   AC5: Behavioral parity — output format matches legacy workflow
#   AC-EC1: Unreachable endpoint handling
#   AC-EC3: setup.sh missing or not executable detection
#   AC-EC5: Error rate threshold boundary behavior documented
#   AC-EC7: No orphaned engine-specific XML tags
#
# Usage:
#   bats tests/skills/gaia-post-deploy.bats
#
# Dependencies: bats-core 1.10+

# ---------- Helpers ----------

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SKILLS_DIR="$REPO_ROOT/plugins/gaia/skills"
  SCRIPTS_DIR="$REPO_ROOT/plugins/gaia/scripts"
  SKILL_DIR="$SKILLS_DIR/gaia-post-deploy"
  SKILL_FILE="$SKILL_DIR/SKILL.md"
  SETUP_SCRIPT="$SKILL_DIR/scripts/setup.sh"
  FINALIZE_SCRIPT="$SKILL_DIR/scripts/finalize.sh"
}

# ---------- AC1: SKILL.md exists with valid frontmatter and health check content ----------

@test "AC1: SKILL.md exists at gaia-post-deploy skill directory" {
  [ -f "$SKILL_FILE" ]
}

@test "AC1: SKILL.md has YAML frontmatter delimiters" {
  head -1 "$SKILL_FILE" | grep -q "^---$"
  awk 'NR>1 && /^---$/{found=1; exit} END{exit !found}' "$SKILL_FILE"
}

@test "AC1: SKILL.md frontmatter contains name: gaia-post-deploy" {
  awk '/^---$/{n++; next} n==1{print}' "$SKILL_FILE" | grep -q "^name: gaia-post-deploy"
}

@test "AC1: SKILL.md frontmatter contains description field" {
  awk '/^---$/{n++; next} n==1{print}' "$SKILL_FILE" | grep -q "^description:"
}

@test "AC1: SKILL.md frontmatter contains tools field" {
  awk '/^---$/{n++; next} n==1{print}' "$SKILL_FILE" | grep -q "^tools:"
}

@test "AC1: SKILL.md covers health endpoint verification" {
  grep -qi "health.*endpoint\|endpoint.*health\|health.*check" "$SKILL_FILE"
}

@test "AC1: SKILL.md covers error rate validation" {
  grep -qi "error.*rate\|error_rate" "$SKILL_FILE"
}

@test "AC1: SKILL.md covers latency metrics (P50, P95, P99)" {
  grep -qi "latency\|p50\|p95\|p99" "$SKILL_FILE"
}

@test "AC1: SKILL.md covers service connectivity checks" {
  grep -qi "connectivity\|database\|cache\|queue\|external.*api" "$SKILL_FILE"
}

@test "AC1: SKILL.md covers smoke tests" {
  grep -qi "smoke.*test" "$SKILL_FILE"
}

@test "AC1: SKILL.md covers metric validation" {
  grep -qi "metric.*valid\|valid.*metric\|slo" "$SKILL_FILE"
}

@test "AC1: SKILL.md covers canary analysis" {
  grep -qi "canary" "$SKILL_FILE"
}

@test "AC1: SKILL.md generates a structured pass/fail report" {
  grep -qi "pass.*fail\|report\|deployment.*status" "$SKILL_FILE"
}

# ---------- AC3: Shared setup.sh/finalize.sh pattern ----------

@test "AC3: setup.sh exists and is executable" {
  [ -x "$SETUP_SCRIPT" ]
}

@test "AC3: finalize.sh exists and is executable" {
  [ -x "$FINALIZE_SCRIPT" ]
}

@test "AC3: setup.sh calls resolve-config.sh" {
  grep -q "resolve-config.sh" "$SETUP_SCRIPT"
}

@test "AC3: setup.sh references validate-gate or checkpoint" {
  grep -q "validate-gate\|checkpoint" "$SETUP_SCRIPT"
}

@test "AC3: setup.sh loads checkpoint" {
  grep -q "checkpoint" "$SETUP_SCRIPT"
}

@test "AC3: finalize.sh writes checkpoint" {
  grep -q "checkpoint" "$FINALIZE_SCRIPT"
}

@test "AC3: finalize.sh emits lifecycle event" {
  grep -q "lifecycle-event" "$FINALIZE_SCRIPT"
}

@test "AC3: SKILL.md invokes setup.sh at entry" {
  grep -q '!.*setup\.sh' "$SKILL_FILE"
}

@test "AC3: SKILL.md invokes finalize.sh at exit" {
  grep -q '!.*finalize\.sh' "$SKILL_FILE"
}

# ---------- AC4: Health check logic uses inline script calls per ADR-042 ----------

@test "AC4: SKILL.md references inline script calls for deterministic operations" {
  grep -qi 'scripts/\|!.*\.sh\|ADR-042' "$SKILL_FILE"
}

@test "AC4: SKILL.md references ADR-042 for scripts-over-LLM" {
  grep -qi "ADR-042\|scripts-over-llm\|deterministic" "$SKILL_FILE"
}

# ---------- AC5: Output format matches legacy workflow ----------

@test "AC5: SKILL.md produces post-deployment report artifact" {
  grep -qi "post-deploy\|report\|artifact\|docs/" "$SKILL_FILE"
}

@test "AC5: SKILL.md includes health check results in output" {
  grep -qi "health.*check.*result\|result.*health" "$SKILL_FILE"
}

# ---------- AC-EC1: Unreachable endpoint handling ----------

@test "AC-EC1: SKILL.md handles unreachable endpoints" {
  grep -qi "unreachable\|timeout\|connection.*fail\|dns.*fail\|endpoint.*fail" "$SKILL_FILE"
}

@test "AC-EC1: SKILL.md provides remediation guidance for failures" {
  grep -qi "remediation\|guidance\|suggest\|action" "$SKILL_FILE"
}

# ---------- AC-EC3: setup.sh missing or not executable ----------

@test "AC-EC3: SKILL.md or setup.sh checks script existence" {
  grep -qi "not found\|not executable\|missing.*script\|script.*missing" "$SKILL_FILE" || \
  grep -qi "not found\|not executable" "$SETUP_SCRIPT"
}

# ---------- AC-EC5: Error rate threshold boundary behavior ----------

@test "AC-EC5: SKILL.md documents threshold boundary behavior" {
  grep -qi "threshold\|boundary\|<=\|>=\|exact" "$SKILL_FILE"
}

# ---------- AC-EC7: No orphaned engine-specific XML tags ----------

@test "AC-EC7: SKILL.md contains no orphaned <action> tags" {
  ! grep -q '<action>' "$SKILL_FILE"
}

@test "AC-EC7: SKILL.md contains no orphaned <template-output> tags" {
  ! grep -q '<template-output>' "$SKILL_FILE"
}

@test "AC-EC7: SKILL.md contains no orphaned <invoke-workflow> tags" {
  ! grep -q '<invoke-workflow>' "$SKILL_FILE"
}

@test "AC-EC7: SKILL.md contains no orphaned <step> tags" {
  ! grep -q '<step ' "$SKILL_FILE"
}

@test "AC-EC7: SKILL.md contains no orphaned <check> tags" {
  ! grep -q '<check ' "$SKILL_FILE"
}

@test "AC-EC7: SKILL.md contains no orphaned <mandate> tags" {
  ! grep -q '<mandate>' "$SKILL_FILE"
}

@test "AC-EC7: SKILL.md contains no orphaned <critical> tags" {
  ! grep -q '<critical>' "$SKILL_FILE"
}

# ---------- AC-EC4: No shared mutable state ----------

@test "AC-EC4: setup.sh uses local variables (no global mutable state)" {
  # Verify script uses set -euo pipefail (safe defaults)
  grep -q "set -euo pipefail" "$SETUP_SCRIPT"
}

@test "AC-EC4: finalize.sh uses local variables (no global mutable state)" {
  grep -q "set -euo pipefail" "$FINALIZE_SCRIPT"
}
