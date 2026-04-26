#!/usr/bin/env bats
# review-security-e48-s3.bats — E48-S3 threat-model linkage, live-secret escalation,
# and optional Review Gate integration for the anytime review variant.
#
# Validates that gaia-review-security SKILL.md:
#   AC1: Cross-references modeled threats by threat ID (Related Threat column)
#        when docs/planning-artifacts/threat-model.md exists.
#   AC2: Escalates live-secret patterns (AWS AKIA, GCP service account JSON,
#        GitHub PAT prefixes) above generic hardcoded strings in severity.
#   AC3: Offers optional Review Gate integration when a story in 'review'
#        status is identifiable from context.
#   AC4: Skips silently when threat-model.md is absent (no error, no warning,
#        no behavioral change from current V2).
#
# Cross-cutting structural requirements:
#   - ADR-064: Threat-model context plumbing — anytime variant reads
#     threat-model.md directly (no fork-context limitation).
#   - ADR-067: YOLO Mode Contract — Review Gate offer auto-confirms in YOLO
#     mode (auto-confirm at template-output prompts).
#   - ADR-042: No new scripts — review-gate.sh already exists; this skill
#     introduces zero new shell scripts.
#   - ADR-041: Native Execution Model preserved.
#
# Refs: E48-S3, FR-364, ADR-041, ADR-042, ADR-064, ADR-067, NFR-053
#
# Usage:
#   bats tests/cluster-9-parity/review-security-e48-s3.bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SKILLS_DIR="$REPO_ROOT/plugins/gaia/skills"
  SKILL="gaia-review-security"
  SKILL_DIR="$SKILLS_DIR/$SKILL"
  SKILL_FILE="$SKILL_DIR/SKILL.md"
}

# ---------- Existence + frontmatter sanity ----------

@test "E48-S3: gaia-review-security SKILL.md exists" {
  [ -f "$SKILL_FILE" ]
}

@test "E48-S3: SKILL.md frontmatter does NOT declare context: fork (anytime variant)" {
  # The anytime review variant runs inline (no fork). Only the pre-merge
  # /gaia-security-review uses context: fork.
  ! head -20 "$SKILL_FILE" | grep -qE '^context:\s*fork'
}

@test "E48-S3: SKILL.md frontmatter declares Read in allowed-tools (threat-model load)" {
  local tools_line
  tools_line=$(head -20 "$SKILL_FILE" | grep '^allowed-tools:')
  [[ "$tools_line" == *"Read"* ]]
}

# ---------- AC1: threat-model detection + cross-reference ----------

@test "E48-S3: SKILL.md declares threat-model.md detection logic" {
  grep -qE 'docs/planning-artifacts/threat-model\.md' "$SKILL_FILE"
}

@test "E48-S3: SKILL.md describes Threat Model Context section in OWASP evaluation" {
  grep -qiE 'threat[- ]model context' "$SKILL_FILE"
}

@test "E48-S3: SKILL.md uses Read tool for threat-model loading" {
  grep -qE 'Read.*threat-model|threat-model.*Read' "$SKILL_FILE"
}

@test "E48-S3: SKILL.md introduces a Related Threat column on findings" {
  grep -qiE 'Related Threat' "$SKILL_FILE"
}

@test "E48-S3: SKILL.md cross-reference example uses 'see T{n} in threat model' format" {
  grep -qE 'see T[0-9]+ in threat model' "$SKILL_FILE"
}

@test "E48-S3: SKILL.md describes T{N} regex extraction for threat IDs" {
  grep -qE 'T\{N\}|T\{n\}|T[0-9]+' "$SKILL_FILE"
}

@test "E48-S3: SKILL.md notes anytime variant reads threat-model directly (no fork limitation)" {
  grep -qiE '(no fork|not.*fork|directly|inline.*read|anytime)' "$SKILL_FILE"
}

# ---------- AC2: live-secret severity escalation ----------

@test "E48-S3: SKILL.md describes live-secret severity escalation" {
  grep -qiE 'live[- ]secret' "$SKILL_FILE"
}

@test "E48-S3: SKILL.md lists AWS AKIA key shape pattern" {
  grep -qE 'AKIA' "$SKILL_FILE"
}

@test "E48-S3: SKILL.md lists GCP service account JSON pattern" {
  grep -qiE 'service[_ ]account' "$SKILL_FILE"
}

@test "E48-S3: SKILL.md lists GitHub PAT prefix patterns" {
  grep -qE 'ghp_' "$SKILL_FILE"
}

@test "E48-S3: SKILL.md states live-secrets escalate above generic hardcoded strings" {
  grep -qiE '(escalat|above generic|higher.*severity|critical|rank.*above)' "$SKILL_FILE"
}

@test "E48-S3: SKILL.md classifies live-secret findings at critical severity" {
  grep -qiE 'live[- ]secret.*critical|critical.*live[- ]secret' "$SKILL_FILE"
}

# ---------- AC3: optional Review Gate integration ----------

@test "E48-S3: SKILL.md describes optional Review Gate integration step" {
  grep -qiE 'review gate' "$SKILL_FILE"
}

@test "E48-S3: SKILL.md references review-gate.sh for the optional write" {
  grep -qE 'review-gate\.sh' "$SKILL_FILE"
}

@test "E48-S3: SKILL.md uses 'Security Review' as the canonical gate name" {
  grep -qE 'Security Review' "$SKILL_FILE"
}

@test "E48-S3: SKILL.md uses PASSED|FAILED canonical Review Gate verdict vocabulary" {
  grep -qE 'PASSED' "$SKILL_FILE"
  grep -qE 'FAILED' "$SKILL_FILE"
}

@test "E48-S3: SKILL.md detects review-status story from context" {
  grep -qiE '(review[- ]status|status.*review|review.*status|story.*review)' "$SKILL_FILE"
}

@test "E48-S3: SKILL.md offers (not forces) the Review Gate write" {
  grep -qiE '(offer|optional|opt[- ]in)' "$SKILL_FILE"
}

@test "E48-S3: SKILL.md silently skips Review Gate offer when no review-status story is identified" {
  grep -qiE '(no.*review.*story|no.*story.*review|silently skip|skip.*silently)' "$SKILL_FILE"
}

# ---------- AC4: graceful skip when threat-model.md absent ----------

@test "E48-S3: SKILL.md describes graceful skip when threat-model.md absent" {
  grep -qiE 'threat-model.*(absent|missing|does not exist|skip)' "$SKILL_FILE"
}

@test "E48-S3: SKILL.md states no warning/error when threat-model.md absent" {
  grep -qiE '(no (error|warning|user-visible)|silent|silently|graceful)' "$SKILL_FILE"
}

# ---------- ADR-067: YOLO behavior on Review Gate offer ----------

@test "E48-S3: SKILL.md includes YOLO Behavior section" {
  grep -qE '^## YOLO Behavior|^### YOLO Behavior|^## YOLO Mode' "$SKILL_FILE"
}

@test "E48-S3: YOLO mode auto-proceeds with Review Gate offer (per ADR-067 auto-confirm)" {
  grep -qiE '(yolo.*auto[- ]proceed|yolo.*auto[- ]confirm|auto[- ]confirm.*review gate|review gate.*auto)' "$SKILL_FILE"
}

# ---------- ADR refs and traceability ----------

@test "E48-S3: SKILL.md references ADR-041 (Native Execution)" {
  grep -q 'ADR-041' "$SKILL_FILE"
}

@test "E48-S3: SKILL.md references ADR-042 (Scripts-over-LLM, no new scripts)" {
  grep -q 'ADR-042' "$SKILL_FILE"
}

@test "E48-S3: SKILL.md references ADR-064 (Threat-Model Context Plumbing)" {
  grep -q 'ADR-064' "$SKILL_FILE"
}

@test "E48-S3: SKILL.md references ADR-067 (YOLO Mode Contract)" {
  grep -q 'ADR-067' "$SKILL_FILE"
}

@test "E48-S3: SKILL.md references FR-364" {
  grep -q 'FR-364' "$SKILL_FILE"
}

# ---------- ADR-042 no-new-scripts: gaia-review-security has no scripts/ ----------

@test "E48-S3: gaia-review-security has no scripts/ directory (no new scripts)" {
  [ ! -d "$SKILL_DIR/scripts" ]
}

# ---------- Layout constraints (native skill) ----------

@test "E48-S3: gaia-review-security/ has no workflow.yaml (native skill)" {
  [ ! -f "$SKILL_DIR/workflow.yaml" ]
}

@test "E48-S3: gaia-review-security/ has no instructions.xml (native skill)" {
  [ ! -f "$SKILL_DIR/instructions.xml" ]
}

# ---------- Linter compliance ----------

@test "E48-S3: lint-skill-frontmatter.sh passes on gaia-review-security SKILL.md" {
  cd "$REPO_ROOT"
  bash .github/scripts/lint-skill-frontmatter.sh
}
