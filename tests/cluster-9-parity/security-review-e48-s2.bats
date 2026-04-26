#!/usr/bin/env bats
# security-review-e48-s2.bats — E48-S2 threat-model context plumbing into Zara
#
# Validates that gaia-security-review SKILL.md:
#   AC1: Conditionally includes threat-model.md content in the Zara dispatch
#        context when docs/planning-artifacts/threat-model.md exists.
#   AC2: Instructs Zara to cross-reference OWASP findings against modeled
#        threat IDs (e.g., "see T3 in threat model") when threat-model
#        context is present.
#   AC3: Skips silently when threat-model.md is absent (no error, no warning,
#        no user-visible message about missing file).
#
# Cross-cutting structural requirements:
#   - ADR-063: Mandatory verdict surfacing (PASS/WARNING/CRITICAL) for the
#     Zara return.
#   - ADR-037: Structured subagent return schema
#     ({status, summary, artifacts, findings, next}).
#   - ADR-045: Fork-context read-only subagent dispatch
#     (allowed-tools: Read Grep Glob Bash).
#   - ADR-067: YOLO behavior — CRITICAL still halts.
#   - ADR-042: No new scripts (only setup.sh + finalize.sh in scripts/).
#   - ADR-064: Threat-model context plumbing pattern.
#
# Refs: E48-S2, FR-363, ADR-037, ADR-041, ADR-042, ADR-045, ADR-063,
#       ADR-064, ADR-067, NFR-046, NFR-048
#
# Usage:
#   bats tests/cluster-9-parity/security-review-e48-s2.bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SKILLS_DIR="$REPO_ROOT/plugins/gaia/skills"
  SKILL="gaia-security-review"
  SKILL_DIR="$SKILLS_DIR/$SKILL"
  SKILL_FILE="$SKILL_DIR/SKILL.md"
}

# ---------- Existence + frontmatter sanity ----------

@test "E48-S2: gaia-security-review SKILL.md exists" {
  [ -f "$SKILL_FILE" ]
}

@test "E48-S2: SKILL.md frontmatter declares context: fork (ADR-045)" {
  head -20 "$SKILL_FILE" | grep -q '^context: fork'
}

@test "E48-S2: SKILL.md frontmatter allowed-tools is Read Grep Glob Bash (read-only)" {
  local tools_line
  tools_line=$(head -20 "$SKILL_FILE" | grep '^allowed-tools:')
  [[ "$tools_line" == *"Read"* ]]
  [[ "$tools_line" == *"Grep"* ]]
  [[ "$tools_line" == *"Glob"* ]]
  [[ "$tools_line" == *"Bash"* ]]
  [[ "$tools_line" != *"Write"* ]]
  [[ "$tools_line" != *"Edit"* ]]
}

# ---------- AC1: threat-model detection step ----------

@test "E48-S2: SKILL.md declares threat-model detection logic" {
  grep -qE 'docs/planning-artifacts/threat-model\.md' "$SKILL_FILE"
}

@test "E48-S2: SKILL.md describes a Threat Model Context section in dispatch" {
  grep -qiE 'threat[- ]model context' "$SKILL_FILE"
}

@test "E48-S2: SKILL.md uses Read tool for threat-model (fork-context allowlist)" {
  # The skill must read the file via the Read tool — not via a new script.
  # Verify the threat-model detection narrative uses the Read tool.
  grep -qE 'Read.*threat-model|threat-model.*Read' "$SKILL_FILE"
}

# ---------- AC2: cross-reference instruction to Zara ----------

@test "E48-S2: SKILL.md instructs Zara to cross-reference threat IDs when present" {
  grep -qiE 'cross[- ]reference' "$SKILL_FILE"
  grep -qE 'T[0-9]' "$SKILL_FILE"
}

@test "E48-S2: SKILL.md cross-reference format example uses 'see T{n} in threat model'" {
  grep -qE 'see T[0-9]+ in threat model' "$SKILL_FILE"
}

# ---------- AC3: graceful skip when threat-model.md absent ----------

@test "E48-S2: SKILL.md describes graceful skip when threat-model.md absent" {
  # Must mention "skip" or "absent" or "missing" alongside threat-model
  # without producing a user-visible warning/error.
  grep -qiE 'threat-model.*(absent|missing|does not exist|skip)' "$SKILL_FILE"
}

@test "E48-S2: SKILL.md states no warning/error when threat-model.md absent" {
  grep -qiE '(no (error|warning|user-visible)|silent|silently)' "$SKILL_FILE"
}

# ---------- ADR-063: Subagent Dispatch Contract / verdict surfacing ----------

@test "E48-S2: SKILL.md includes Subagent Dispatch Contract section" {
  grep -qE '^## Subagent Dispatch Contract|^### Subagent Dispatch Contract' "$SKILL_FILE"
}

@test "E48-S2: SKILL.md surfaces verdict vocabulary (PASS/WARNING/CRITICAL)" {
  grep -q 'CRITICAL' "$SKILL_FILE"
  grep -q 'WARNING' "$SKILL_FILE"
  grep -qE 'PASS|status' "$SKILL_FILE"
}

@test "E48-S2: SKILL.md codifies halt-on-CRITICAL semantics (ADR-063)" {
  grep -qiE 'halt.*CRITICAL|CRITICAL.*halt' "$SKILL_FILE"
}

@test "E48-S2: SKILL.md references ADR-037 structured return schema" {
  grep -q 'ADR-037' "$SKILL_FILE"
}

# ---------- ADR-067: YOLO behavior ----------

@test "E48-S2: SKILL.md includes YOLO Behavior section" {
  grep -qE '^## YOLO Behavior|^### YOLO Behavior' "$SKILL_FILE"
}

@test "E48-S2: YOLO mode auto-displays verdict but halts on CRITICAL" {
  grep -qiE 'CRITICAL.*still.*halt|CRITICAL.*halt.*YOLO|YOLO.*CRITICAL.*halt' "$SKILL_FILE"
}

# ---------- ADR refs and traceability ----------

@test "E48-S2: SKILL.md references ADR-041 (Native Execution)" {
  grep -q 'ADR-041' "$SKILL_FILE"
}

@test "E48-S2: SKILL.md references ADR-042 (Scripts-over-LLM)" {
  grep -q 'ADR-042' "$SKILL_FILE"
}

@test "E48-S2: SKILL.md references ADR-045 (fork-context isolation)" {
  grep -q 'ADR-045' "$SKILL_FILE"
}

@test "E48-S2: SKILL.md references ADR-063 (Subagent Dispatch Contract)" {
  grep -q 'ADR-063' "$SKILL_FILE"
}

@test "E48-S2: SKILL.md references ADR-064 (Threat-Model Context Plumbing)" {
  grep -q 'ADR-064' "$SKILL_FILE"
}

@test "E48-S2: SKILL.md references ADR-067 (YOLO Mode Contract)" {
  grep -q 'ADR-067' "$SKILL_FILE"
}

# ---------- ADR-042 no-new-scripts: only setup/finalize allowed ----------

@test "E48-S2: gaia-security-review scripts/ contains only setup.sh and finalize.sh" {
  cd "$SKILL_DIR/scripts"
  count="$(ls -1 | wc -l | tr -d ' ')"
  [ "$count" = "2" ]
  [ -f "setup.sh" ]
  [ -f "finalize.sh" ]
}

# ---------- Layout constraints (native skill) ----------

@test "E48-S2: gaia-security-review/ has no workflow.yaml (native skill)" {
  [ ! -f "$SKILL_DIR/workflow.yaml" ]
}

@test "E48-S2: gaia-security-review/ has no instructions.xml (native skill)" {
  [ ! -f "$SKILL_DIR/instructions.xml" ]
}

# ---------- Linter compliance ----------

@test "E48-S2: lint-skill-frontmatter.sh passes on gaia-security-review SKILL.md" {
  cd "$REPO_ROOT"
  bash .github/scripts/lint-skill-frontmatter.sh
}
