#!/usr/bin/env bats
# performance-review-parity.bats — E28-S71 parity + tool-allowlist enforcement tests
#
# Validates:
#   AC1: SKILL.md frontmatter matches brief's reference pattern (context:fork,
#        tools: Read, Grep, Glob, Bash, NO Write, NO Edit)
#   AC2: Subagent dispatch to Juno (Performance Specialist)
#   AC3: review-gate.sh integration for verdict writing
#   AC4: Shared scaffolding (setup.sh + finalize.sh + review-gate.sh pattern)
#
# Refs: E28-S71, E28-S66 (canonical), NFR-048, NFR-052, ADR-041, ADR-045
#
# Usage:
#   bats tests/cluster-9-parity/performance-review-parity.bats
#
# Dependencies: bats-core 1.10+

# ---------- Helpers ----------

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SKILLS_DIR="$REPO_ROOT/plugins/gaia/skills"
  SCRIPTS_DIR="$REPO_ROOT/plugins/gaia/scripts"

  SKILL="gaia-review-perf"
  SKILL_DIR="$SKILLS_DIR/$SKILL"
}

# ---------- AC1: Frontmatter conformance ----------

@test "E28-S71: SKILL.md exists" {
  [ -f "$SKILL_DIR/SKILL.md" ]
}

@test "E28-S71: SKILL.md frontmatter has name: gaia-review-perf" {
  head -20 "$SKILL_DIR/SKILL.md" | grep -q '^name: gaia-review-perf'
}

@test "E28-S71: SKILL.md frontmatter has context: fork" {
  head -20 "$SKILL_DIR/SKILL.md" | grep -q '^context: fork'
}

@test "E28-S71: SKILL.md frontmatter has tools containing Read" {
  head -20 "$SKILL_DIR/SKILL.md" | grep -q 'tools:.*Read'
}

@test "E28-S71: SKILL.md frontmatter has tools containing Grep" {
  head -20 "$SKILL_DIR/SKILL.md" | grep -q 'tools:.*Grep'
}

@test "E28-S71: SKILL.md frontmatter has tools containing Glob" {
  head -20 "$SKILL_DIR/SKILL.md" | grep -q 'tools:.*Glob'
}

@test "E28-S71: SKILL.md frontmatter has tools containing Bash" {
  head -20 "$SKILL_DIR/SKILL.md" | grep -q 'tools:.*Bash'
}

# ---------- AC1: Tool-allowlist enforcement (NFR-048) ----------

@test "E28-S71: SKILL.md tools does NOT contain Write" {
  local tools_line
  tools_line=$(head -20 "$SKILL_DIR/SKILL.md" | grep '^tools:')
  [[ "$tools_line" != *"Write"* ]]
}

@test "E28-S71: SKILL.md tools does NOT contain Edit" {
  local tools_line
  tools_line=$(head -20 "$SKILL_DIR/SKILL.md" | grep '^tools:')
  [[ "$tools_line" != *"Edit"* ]]
}

# ---------- AC2: Subagent dispatch to Juno ----------

@test "E28-S71: SKILL.md references Juno performance subagent" {
  grep -q 'Juno' "$SKILL_DIR/SKILL.md"
}

@test "E28-S71: SKILL.md dispatches to Juno for performance analysis" {
  grep -qi 'dispatch.*Juno\|Juno.*subagent\|Juno.*performance' "$SKILL_DIR/SKILL.md"
}

# ---------- AC3: review-gate.sh integration ----------

@test "E28-S71: SKILL.md references review-gate.sh for verdict writing" {
  grep -q 'review-gate\.sh' "$SKILL_DIR/SKILL.md"
}

@test "E28-S71: SKILL.md uses Performance Review as gate name" {
  grep -q '"Performance Review"' "$SKILL_DIR/SKILL.md"
}

@test "E28-S71: SKILL.md maps verdict to PASSED" {
  grep -q 'PASSED' "$SKILL_DIR/SKILL.md"
}

@test "E28-S71: SKILL.md maps verdict to FAILED" {
  grep -q 'FAILED' "$SKILL_DIR/SKILL.md"
}

# ---------- AC4: Shared scaffolding ----------

@test "E28-S71: setup.sh exists and is executable" {
  [ -f "$SKILL_DIR/scripts/setup.sh" ]
  [ -x "$SKILL_DIR/scripts/setup.sh" ]
}

@test "E28-S71: finalize.sh exists and is executable" {
  [ -f "$SKILL_DIR/scripts/finalize.sh" ]
  [ -x "$SKILL_DIR/scripts/finalize.sh" ]
}

@test "E28-S71: SKILL.md references setup.sh via bang-include" {
  grep -q '!.*setup\.sh' "$SKILL_DIR/SKILL.md"
}

@test "E28-S71: SKILL.md references finalize.sh via bang-include" {
  grep -q '!.*finalize\.sh' "$SKILL_DIR/SKILL.md"
}

@test "E28-S71: setup.sh references resolve-config.sh" {
  grep -q 'resolve-config\.sh' "$SKILL_DIR/scripts/setup.sh"
}

@test "E28-S71: finalize.sh references checkpoint.sh" {
  grep -q 'checkpoint\.sh' "$SKILL_DIR/scripts/finalize.sh"
}

@test "E28-S71: finalize.sh references lifecycle-event.sh" {
  grep -q 'lifecycle-event\.sh' "$SKILL_DIR/scripts/finalize.sh"
}

# ---------- AC4: _reference-frontmatter.md ----------

@test "E28-S71: _reference-frontmatter.md exists" {
  [ -f "$SKILL_DIR/_reference-frontmatter.md" ]
}

@test "E28-S71: _reference-frontmatter.md contains verbatim brief example" {
  grep -q 'name: gaia-review-perf' "$SKILL_DIR/_reference-frontmatter.md"
  grep -q 'context: fork' "$SKILL_DIR/_reference-frontmatter.md"
  grep -q 'tools: Read, Grep, Glob, Bash' "$SKILL_DIR/_reference-frontmatter.md"
}

# ---------- Shared scripts existence ----------

@test "E28-S71: review-gate.sh exists in shared scripts dir" {
  [ -f "$SCRIPTS_DIR/review-gate.sh" ]
}

@test "E28-S71: SKILL.md has argument-hint for story-key" {
  head -20 "$SKILL_DIR/SKILL.md" | grep -q 'argument-hint:.*story-key'
}

# ---------- Auto-pass classification ----------

@test "E28-S71: SKILL.md includes auto-pass classification logic" {
  grep -q 'auto-pass\|auto-passed\|Auto-Pass' "$SKILL_DIR/SKILL.md"
}
