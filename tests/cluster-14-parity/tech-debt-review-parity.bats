#!/usr/bin/env bats
# tech-debt-review-parity.bats — E28-S108 parity + structure tests
#
# Validates the conversion of _gaia/lifecycle/workflows/4-implementation/tech-debt-review/
# to a native SKILL.md at plugins/gaia/skills/gaia-tech-debt-review/SKILL.md.
#
#   AC1: SKILL.md exists at the native-conversion target path with valid
#        frontmatter (name, description, allowed-tools) and passes the
#        frontmatter linter with zero errors.
#   AC2: Legacy 7-step instruction body is preserved as prose sections —
#        scan debt sources, classify debt, score and prioritize,
#        calculate aging, generate dashboard, recommend actions,
#        save to Val memory.
#   AC3: Critical rules preserved — frontmatter+findings-only reads,
#        stable TD-{N} ID assignment, STALE TARGET / UNASSIGNED handling,
#        dashboard trend preservation.
#   AC4: Zero orphaned engine-specific XML tags.
#   AC5: memory-loader.sh invocation preserved (ADR-046 hybrid memory).
#   AC6: Deterministic helper scripts exist — scan-findings.sh, td-id-assign.sh.
#   AC7: Dashboard template exists locally under skills/{name}/templates/.
#   AC8: Dashboard output path is {implementation_artifacts}/tech-debt-dashboard.md.
#   AC9: ADR-041, ADR-042, ADR-046 citations present.
#
# Refs: E28-S108, FR-323, NFR-048, NFR-053, ADR-041, ADR-042, ADR-046, ADR-048
#
# Usage:
#   bats tests/cluster-14-parity/tech-debt-review-parity.bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SKILLS_DIR="$REPO_ROOT/plugins/gaia/skills"
  SCRIPTS_DIR="$REPO_ROOT/plugins/gaia/scripts"

  SKILL="gaia-tech-debt-review"
  SKILL_DIR="$SKILLS_DIR/$SKILL"
  SKILL_FILE="$SKILL_DIR/SKILL.md"
}

# ---------- AC1: SKILL.md exists and has valid frontmatter ----------

@test "E28-S108: gaia-tech-debt-review SKILL.md exists" {
  [ -f "$SKILL_FILE" ]
}

@test "E28-S108: gaia-tech-debt-review SKILL.md has YAML frontmatter delimiters" {
  head -1 "$SKILL_FILE" | grep -q "^---$"
  awk 'NR>1 && /^---$/{found=1; exit} END{exit !found}' "$SKILL_FILE"
}

@test "E28-S108: gaia-tech-debt-review SKILL.md has name: gaia-tech-debt-review" {
  head -30 "$SKILL_FILE" | grep -q '^name: gaia-tech-debt-review$'
}

@test "E28-S108: gaia-tech-debt-review SKILL.md has a non-empty description" {
  head -30 "$SKILL_FILE" | grep -qE '^description: .+'
}

@test "E28-S108: gaia-tech-debt-review SKILL.md has allowed-tools Read" {
  head -30 "$SKILL_FILE" | grep -qE '^allowed-tools:.*Read'
}

@test "E28-S108: gaia-tech-debt-review SKILL.md has allowed-tools Write" {
  head -30 "$SKILL_FILE" | grep -qE '^allowed-tools:.*Write'
}

@test "E28-S108: gaia-tech-debt-review SKILL.md passes frontmatter linter" {
  cd "$REPO_ROOT" && bash "$REPO_ROOT/.github/scripts/lint-skill-frontmatter.sh"
}

# ---------- AC2: Legacy 7-step body preserved ----------

@test "E28-S108: gaia-tech-debt-review references Scan Debt Sources" {
  grep -qiE 'scan debt|scan.*findings|debt source' "$SKILL_FILE"
}

@test "E28-S108: gaia-tech-debt-review references Classify Debt" {
  grep -qiE 'classify debt|classification|DESIGN|CODE|TEST|INFRASTRUCTURE' "$SKILL_FILE"
}

@test "E28-S108: gaia-tech-debt-review references Score and Prioritize" {
  grep -qiE 'score|priorit|FIX NOW|PLAN NEXT|TRACK' "$SKILL_FILE"
}

@test "E28-S108: gaia-tech-debt-review references Calculate Aging" {
  grep -qiE 'aging|age.*sprint|OVERDUE|sprint_id' "$SKILL_FILE"
}

@test "E28-S108: gaia-tech-debt-review references Generate Dashboard" {
  grep -qiE 'dashboard|tech-debt-dashboard' "$SKILL_FILE"
}

@test "E28-S108: gaia-tech-debt-review references Recommend Actions" {
  grep -qiE 'recommend|/gaia-triage-findings|/gaia-correct-course' "$SKILL_FILE"
}

@test "E28-S108: gaia-tech-debt-review references Val memory save" {
  grep -qE 'validator-sidecar|decision-log\.md|val.*memory' "$SKILL_FILE"
}

# ---------- AC3: Critical rules preserved ----------

@test "E28-S108: gaia-tech-debt-review references frontmatter-only reads (token budget)" {
  grep -qiE 'frontmatter|findings section|token budget' "$SKILL_FILE"
}

@test "E28-S108: gaia-tech-debt-review references stable TD-{N} IDs" {
  grep -qE 'TD-' "$SKILL_FILE"
  grep -qiE 'stable.*ID|never renumber|preserve.*ID' "$SKILL_FILE"
}

@test "E28-S108: gaia-tech-debt-review references STALE TARGET / UNASSIGNED" {
  grep -qE 'STALE TARGET' "$SKILL_FILE"
  grep -qE 'UNASSIGNED' "$SKILL_FILE"
}

@test "E28-S108: gaia-tech-debt-review references RESOLVED detection" {
  grep -qE 'RESOLVED' "$SKILL_FILE"
}

@test "E28-S108: gaia-tech-debt-review references trend preservation" {
  grep -qiE 'trend|previous dashboard|previous.*total' "$SKILL_FILE"
}

@test "E28-S108: gaia-tech-debt-review references duplicate merge" {
  grep -qiE 'duplicate|merge.*finding|merged from' "$SKILL_FILE"
}

# ---------- AC4: Zero orphaned XML tags ----------

@test "E28-S108: gaia-tech-debt-review has no orphaned <action> tags" {
  ! grep -qE '<action[> ]|</action>' "$SKILL_FILE"
}

@test "E28-S108: gaia-tech-debt-review has no orphaned <template-output> tags" {
  ! grep -qE '<template-output[> ]|</template-output>' "$SKILL_FILE"
}

@test "E28-S108: gaia-tech-debt-review has no orphaned <workflow> tags" {
  ! grep -qE '<workflow[> ]|</workflow>' "$SKILL_FILE"
}

@test "E28-S108: gaia-tech-debt-review has no orphaned <step> tags" {
  ! grep -qE '<step[> ]|</step>' "$SKILL_FILE"
}

@test "E28-S108: gaia-tech-debt-review has no orphaned <ask> tags" {
  ! grep -qE '<ask[> ]|</ask>' "$SKILL_FILE"
}

@test "E28-S108: gaia-tech-debt-review has no orphaned <check> tags" {
  ! grep -qE '<check[> ]|</check>' "$SKILL_FILE"
}

# ---------- AC5: memory-loader.sh invocation preserved ----------

@test "E28-S108: gaia-tech-debt-review invokes memory-loader.sh (ADR-046)" {
  grep -q 'memory-loader\.sh' "$SKILL_FILE"
}

@test "E28-S108: gaia-tech-debt-review invokes memory-loader.sh for sm agent" {
  grep -qE 'memory-loader\.sh.*sm' "$SKILL_FILE"
}

# ---------- AC6: Deterministic helper scripts ----------

@test "E28-S108: gaia-tech-debt-review scan-findings.sh exists and is executable" {
  [ -f "$SKILL_DIR/scripts/scan-findings.sh" ]
  [ -x "$SKILL_DIR/scripts/scan-findings.sh" ]
}

@test "E28-S108: gaia-tech-debt-review td-id-assign.sh exists and is executable" {
  [ -f "$SKILL_DIR/scripts/td-id-assign.sh" ]
  [ -x "$SKILL_DIR/scripts/td-id-assign.sh" ]
}

@test "E28-S108: gaia-tech-debt-review references scan-findings.sh" {
  grep -q 'scan-findings\.sh' "$SKILL_FILE"
}

@test "E28-S108: gaia-tech-debt-review references td-id-assign.sh" {
  grep -q 'td-id-assign\.sh' "$SKILL_FILE"
}

# ---------- scan-findings.sh behavior ----------

@test "E28-S108: scan-findings.sh extracts tech-debt findings from story frontmatter+Findings only" {
  tmp_dir=$(mktemp -d)
  cat > "$tmp_dir/E99-S1-sample.md" <<'EOF'
---
key: "E99-S1"
status: in-progress
sprint_id: sprint-99
---

# Story

## Findings

| # | Type | Severity | Finding | Suggested Action |
|---|------|----------|---------|-----------------|
| 1 | tech-debt | medium | Duplicate config | Merge configs |
| 2 | bug | high | Crash on null | Add guard |
EOF
  run "$SKILL_DIR/scripts/scan-findings.sh" --artifacts-dir "$tmp_dir"
  [ "$status" -eq 0 ]
  [[ "$output" == *"E99-S1"* ]]
  [[ "$output" == *"tech-debt"* ]]
  rm -rf "$tmp_dir"
}

# ---------- td-id-assign.sh behavior ----------

@test "E28-S108: td-id-assign.sh assigns TD-1, TD-2 for fresh run" {
  tmp_dir=$(mktemp -d)
  # no existing dashboard
  run "$SKILL_DIR/scripts/td-id-assign.sh" --dashboard "$tmp_dir/tech-debt-dashboard.md" --count 2
  [ "$status" -eq 0 ]
  [[ "$output" == *"TD-1"* ]]
  [[ "$output" == *"TD-2"* ]]
  rm -rf "$tmp_dir"
}

@test "E28-S108: td-id-assign.sh preserves existing TD-{N} IDs" {
  tmp_dir=$(mktemp -d)
  cat > "$tmp_dir/tech-debt-dashboard.md" <<'EOF'
# Tech Debt Dashboard

| # | ID | Item |
|---|----|----|
| 1 | TD-1 | Old debt |
| 2 | TD-5 | Another |
EOF
  run "$SKILL_DIR/scripts/td-id-assign.sh" --dashboard "$tmp_dir/tech-debt-dashboard.md" --next-id
  [ "$status" -eq 0 ]
  # Next ID must be >= 6 (highest existing is TD-5)
  [[ "$output" == *"TD-6"* ]]
  rm -rf "$tmp_dir"
}

# ---------- AC7: Local template exists ----------

@test "E28-S108: gaia-tech-debt-review has templates/dashboard.md" {
  [ -f "$SKILL_DIR/templates/dashboard.md" ]
}

# ---------- AC8: Dashboard output path ----------

@test "E28-S108: gaia-tech-debt-review writes dashboard to implementation_artifacts" {
  grep -qE 'implementation-artifacts/tech-debt-dashboard\.md|\{implementation_artifacts\}/tech-debt-dashboard\.md' "$SKILL_FILE"
}

# ---------- AC9: ADR citations ----------

@test "E28-S108: gaia-tech-debt-review cites ADR-041 (native execution)" {
  grep -q 'ADR-041' "$SKILL_FILE"
}

@test "E28-S108: gaia-tech-debt-review cites ADR-042 (scripts-over-LLM)" {
  grep -q 'ADR-042' "$SKILL_FILE"
}

@test "E28-S108: gaia-tech-debt-review cites ADR-046 (hybrid memory)" {
  grep -q 'ADR-046' "$SKILL_FILE"
}

@test "E28-S108: gaia-performance-review cites ADR-041 and ADR-042" {
  perf_file="$REPO_ROOT/plugins/gaia/skills/gaia-performance-review/SKILL.md"
  grep -q 'ADR-041' "$perf_file"
  grep -q 'ADR-042' "$perf_file"
}

# ---------- Scaffolding (shared pattern) ----------

@test "E28-S108: gaia-tech-debt-review setup.sh exists and is executable" {
  [ -f "$SKILL_DIR/scripts/setup.sh" ]
  [ -x "$SKILL_DIR/scripts/setup.sh" ]
}

@test "E28-S108: gaia-tech-debt-review finalize.sh exists and is executable" {
  [ -f "$SKILL_DIR/scripts/finalize.sh" ]
  [ -x "$SKILL_DIR/scripts/finalize.sh" ]
}

@test "E28-S108: gaia-tech-debt-review references setup.sh via bang-include" {
  grep -qE '!.*setup\.sh' "$SKILL_FILE"
}

@test "E28-S108: gaia-tech-debt-review references finalize.sh via bang-include" {
  grep -qE '!.*finalize\.sh' "$SKILL_FILE"
}
