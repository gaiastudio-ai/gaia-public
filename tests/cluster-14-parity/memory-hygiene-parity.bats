#!/usr/bin/env bats
# memory-hygiene-parity.bats — E28-S107 parity + structure tests
#
# Validates the conversion of _gaia/lifecycle/workflows/anytime/memory-hygiene/
# to a native SKILL.md at plugins/gaia/skills/gaia-memory-hygiene/SKILL.md.
#
#   AC1: SKILL.md exists with valid YAML frontmatter (name, description,
#        argument-hint, allowed-tools) per E28-S74 schema; passes the
#        frontmatter linter with zero errors.
#   AC2: Twelve legacy steps preserved as prose — Dynamic Sidecar Discovery,
#        Tier-Aware Multi-File Scanning, Reference Artifact Loading,
#        Cross-Reference Validation, Stale Detection, Classification,
#        Token Budget Reporting, Archival Recommendations, Ground Truth
#        Refresh Trigger, Enhanced Report, User Action on Flagged Items,
#        Optional Checkpoint Pruning.
#   AC3: Cross-reference matrix and tier classification read from
#        _memory/config.yaml — NOT hard-coded in the SKILL.md body.
#   AC4: Five classification statuses preserved (ACTIVE, STALE, CONTRADICTED,
#        ORPHANED, UNVERIFIABLE-FORMAT).
#   AC5: Frontmatter linter passes zero errors.
#   AC6: Parity harness — 7-section enhanced report preserved (Summary,
#        Token Budget Table, Detailed Findings, Archival Recommendations,
#        Ground Truth Refresh Recommendations, Untiered Agent Report,
#        Skipped Sidecars).
#   AC7: memory-loader.sh wired via inline ${CLAUDE_PLUGIN_ROOT} pattern
#        per ADR-046.
#   AC8: Deterministic scripts either reuse foundation scripts or live
#        under skills/gaia-memory-hygiene/scripts/.
#
# Refs: E28-S107, FR-323, FR-331, NFR-048, NFR-053, ADR-041, ADR-042, ADR-046
#
# Usage:
#   bats tests/cluster-14-parity/memory-hygiene-parity.bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SKILLS_DIR="$REPO_ROOT/plugins/gaia/skills"
  SCRIPTS_DIR="$REPO_ROOT/plugins/gaia/scripts"

  SKILL="gaia-memory-hygiene"
  SKILL_DIR="$SKILLS_DIR/$SKILL"
  SKILL_FILE="$SKILL_DIR/SKILL.md"
}

# ---------- AC1: SKILL.md exists and has valid frontmatter ----------

@test "E28-S107: SKILL.md exists at plugins/gaia/skills/gaia-memory-hygiene/" {
  [ -f "$SKILL_FILE" ]
}

@test "E28-S107: SKILL.md has YAML frontmatter delimiters" {
  head -1 "$SKILL_FILE" | grep -q "^---$"
  awk 'NR>1 && /^---$/{found=1; exit} END{exit !found}' "$SKILL_FILE"
}

@test "E28-S107: SKILL.md frontmatter has name: gaia-memory-hygiene" {
  awk '/^---$/{n++; next} n==1{print}' "$SKILL_FILE" | grep -q '^name: gaia-memory-hygiene'
}

@test "E28-S107: SKILL.md frontmatter description includes 'memory' or 'hygiene' trigger" {
  awk '/^---$/{n++; next} n==1{print}' "$SKILL_FILE" | grep -qiE '^description:.*(memory|hygiene|sidecar)'
}

@test "E28-S107: SKILL.md frontmatter has allowed-tools field" {
  awk '/^---$/{n++; next} n==1{print}' "$SKILL_FILE" | grep -q '^allowed-tools:'
}

@test "E28-S107: SKILL.md frontmatter allowed-tools contains Read, Write, Edit, Bash, Grep" {
  fm=$(awk '/^---$/{n++; next} n==1{print}' "$SKILL_FILE")
  echo "$fm" | grep -q 'allowed-tools:.*Read'
  echo "$fm" | grep -q 'allowed-tools:.*Write'
  echo "$fm" | grep -q 'allowed-tools:.*Edit'
  echo "$fm" | grep -q 'allowed-tools:.*Bash'
  echo "$fm" | grep -q 'allowed-tools:.*Grep'
}

# ---------- AC2: Twelve legacy steps preserved as prose sections ----------

@test "E28-S107: SKILL.md body contains Dynamic Sidecar Discovery step" {
  grep -qiE 'dynamic sidecar discovery|sidecar discovery' "$SKILL_FILE"
}

@test "E28-S107: SKILL.md body contains Tier-Aware Multi-File Scanning step" {
  grep -qiE 'tier[- ]?aware.*scan|multi[- ]?file scanning' "$SKILL_FILE"
}

@test "E28-S107: SKILL.md body contains Reference Artifact Loading step" {
  grep -qiE 'reference artifact|load.*reference' "$SKILL_FILE"
}

@test "E28-S107: SKILL.md body contains Cross-Reference Validation step" {
  grep -qiE 'cross[- ]?reference validation' "$SKILL_FILE"
}

@test "E28-S107: SKILL.md body contains Stale Detection step" {
  grep -qiE 'stale detection' "$SKILL_FILE"
}

@test "E28-S107: SKILL.md body contains Classification / Classify Entries step" {
  grep -qiE 'classif(y|ication)' "$SKILL_FILE"
}

@test "E28-S107: SKILL.md body contains Token Budget Reporting step" {
  grep -qiE 'token budget' "$SKILL_FILE"
}

@test "E28-S107: SKILL.md body contains Archival Recommendations step" {
  grep -qiE 'archival recommendation' "$SKILL_FILE"
}

@test "E28-S107: SKILL.md body contains Ground Truth Refresh Trigger step" {
  grep -qiE 'ground truth.*(refresh|trigger)' "$SKILL_FILE"
}

@test "E28-S107: SKILL.md body contains Enhanced Report step / 7 sections" {
  grep -qiE 'enhanced report|7 sections|seven sections' "$SKILL_FILE"
}

@test "E28-S107: SKILL.md body contains User Action on Flagged Items step" {
  grep -qiE 'user action|keep.*archive.*delete|flagged items' "$SKILL_FILE"
}

@test "E28-S107: SKILL.md body contains Optional Checkpoint Pruning step" {
  grep -qiE 'checkpoint pruning|prune.*checkpoint' "$SKILL_FILE"
}

# ---------- AC3: Config-driven — no hard-coded tier/matrix ----------

@test "E28-S107: SKILL.md reads tier classification from _memory/config.yaml" {
  grep -q '_memory/config.yaml' "$SKILL_FILE"
}

@test "E28-S107: SKILL.md references cross-reference matrix from config" {
  grep -qiE 'cross[- ]?reference.*(matrix|config)' "$SKILL_FILE"
}

@test "E28-S107: SKILL.md does NOT hard-code Tier 1 agent list as literal ids" {
  # Should reference reading from config, not a literal enumeration like
  # `agents: [val, theo, derek, nate]`. The Ground Truth step legitimately
  # names Tier 1 agents for human readability — we check that the body
  # includes a reference to the config file, which the prior test does.
  # Here we assert that the JSON/YAML array literal pattern does NOT appear.
  ! grep -qE 'tier_1:.*\[.*(val|theo|derek|nate).*\]' "$SKILL_FILE"
}

# ---------- AC4: Five classification statuses preserved ----------

@test "E28-S107: SKILL.md references ACTIVE classification" {
  grep -q 'ACTIVE' "$SKILL_FILE"
}

@test "E28-S107: SKILL.md references STALE classification" {
  grep -q 'STALE' "$SKILL_FILE"
}

@test "E28-S107: SKILL.md references CONTRADICTED classification" {
  grep -q 'CONTRADICTED' "$SKILL_FILE"
}

@test "E28-S107: SKILL.md references ORPHANED classification" {
  grep -q 'ORPHANED' "$SKILL_FILE"
}

@test "E28-S107: SKILL.md references UNVERIFIABLE-FORMAT classification" {
  grep -q 'UNVERIFIABLE-FORMAT' "$SKILL_FILE"
}

# ---------- AC6: Seven enhanced report sections preserved ----------

@test "E28-S107: SKILL.md report preserves Summary section" {
  grep -qiE 'summary' "$SKILL_FILE"
}

@test "E28-S107: SKILL.md report preserves Token Budget Table section" {
  grep -qiE 'token budget table' "$SKILL_FILE"
}

@test "E28-S107: SKILL.md report preserves Detailed Findings section" {
  grep -qiE 'detailed findings' "$SKILL_FILE"
}

@test "E28-S107: SKILL.md report preserves Archival Recommendations section" {
  grep -qiE 'archival recommendation' "$SKILL_FILE"
}

@test "E28-S107: SKILL.md report preserves Ground Truth Refresh Recommendations section" {
  grep -qiE 'ground truth refresh recommendation' "$SKILL_FILE"
}

@test "E28-S107: SKILL.md report preserves Untiered Agent Report section" {
  grep -qiE 'untiered agent report' "$SKILL_FILE"
}

@test "E28-S107: SKILL.md report preserves Skipped Sidecars section" {
  grep -qiE 'skipped sidecars' "$SKILL_FILE"
}

# ---------- AC7: Report output path preserved ----------

@test "E28-S107: SKILL.md writes to memory-hygiene-report-{date}.md" {
  grep -qE 'memory-hygiene-report-\{date\}\.md|memory-hygiene-report' "$SKILL_FILE"
}

# ---------- AC8: Foundation scripts wired (ADR-042 / ADR-046) ----------

@test "E28-S107: SKILL.md wires setup.sh via CLAUDE_PLUGIN_ROOT" {
  grep -qE '\$\{CLAUDE_PLUGIN_ROOT\}.*setup\.sh' "$SKILL_FILE"
}

@test "E28-S107: SKILL.md wires finalize.sh via CLAUDE_PLUGIN_ROOT" {
  grep -qE '\$\{CLAUDE_PLUGIN_ROOT\}.*finalize\.sh' "$SKILL_FILE"
}

@test "E28-S107: SKILL.md references memory-loader.sh (ADR-046 hybrid memory loading)" {
  grep -q 'memory-loader.sh' "$SKILL_FILE"
}

@test "E28-S107: SKILL.md memory-loader signature includes tier parameter" {
  # Per E28-S13 AC1: memory-loader.sh <agent_name> <tier>
  grep -qE 'memory-loader\.sh.*(<agent|agent_name).*(tier|decision-log|ground-truth|all)' "$SKILL_FILE"
}

@test "E28-S107: SKILL.md references ADR-041 (native execution model)" {
  grep -q 'ADR-041' "$SKILL_FILE"
}

@test "E28-S107: SKILL.md references ADR-046 (hybrid memory loading)" {
  grep -q 'ADR-046' "$SKILL_FILE"
}

# ---------- AC5: Zero orphaned engine-specific XML tags ----------

@test "E28-S107: SKILL.md contains NO <action> tags" {
  ! grep -q '<action' "$SKILL_FILE"
}

@test "E28-S107: SKILL.md contains NO <template-output> tags" {
  ! grep -q '<template-output' "$SKILL_FILE"
}

@test "E28-S107: SKILL.md contains NO <check> tags" {
  ! grep -q '<check' "$SKILL_FILE"
}

@test "E28-S107: SKILL.md contains NO <ask> tags" {
  ! grep -q '<ask' "$SKILL_FILE"
}

@test "E28-S107: SKILL.md contains NO <step> tags" {
  ! grep -qE '<step[ >]' "$SKILL_FILE"
}

@test "E28-S107: SKILL.md contains NO <workflow> wrapper tags" {
  ! grep -qE '<workflow[ >]' "$SKILL_FILE"
}

# ---------- Edge case coverage (AC-EC1..AC-EC10) ----------

@test "E28-S107: SKILL.md handles AC-EC2 — empty sidecar directory" {
  grep -qiE 'empty sidecar|no content|zero sidecars' "$SKILL_FILE"
}

@test "E28-S107: SKILL.md handles AC-EC3 — legacy sidecar filenames flagged for migration" {
  grep -qiE 'legacy.*(filename|name)|migrat' "$SKILL_FILE"
}

@test "E28-S107: SKILL.md handles AC-EC4 — sprint-status.yaml missing fallback (42-day)" {
  grep -qiE '42[- ]?day|sprint-status.*missing|calendar fallback' "$SKILL_FILE"
}

@test "E28-S107: SKILL.md handles AC-EC5 — missing cross-reference matrix" {
  grep -qiE 'matrix missing|degrade.*structural|no cross[- ]?reference' "$SKILL_FILE"
}

@test "E28-S107: SKILL.md handles AC-EC6 — token budget discipline / JIT release" {
  grep -qiE 'JIT|release previous|per[- ]?sidecar' "$SKILL_FILE"
}

@test "E28-S107: SKILL.md handles AC-EC10 — no _memory/ directory graceful exit" {
  grep -qiE 'no.*_memory|no sidecars discovered|_memory.*not exist' "$SKILL_FILE"
}

# ---------- Layout constraints ----------

@test "E28-S107: gaia-memory-hygiene/ has no workflow.yaml (legacy engine artifact)" {
  [ ! -f "$SKILL_DIR/workflow.yaml" ]
}

@test "E28-S107: gaia-memory-hygiene/ has no instructions.xml (legacy engine artifact)" {
  [ ! -f "$SKILL_DIR/instructions.xml" ]
}

@test "E28-S107: gaia-memory-hygiene/ has no .resolved/ subdirectory" {
  [ ! -d "$SKILL_DIR/.resolved" ]
}

@test "E28-S107: gaia-memory-hygiene/scripts/ directory exists" {
  [ -d "$SKILL_DIR/scripts" ]
}

@test "E28-S107: gaia-memory-hygiene/scripts/setup.sh exists and is executable" {
  [ -f "$SKILL_DIR/scripts/setup.sh" ]
  [ -x "$SKILL_DIR/scripts/setup.sh" ]
}

@test "E28-S107: gaia-memory-hygiene/scripts/finalize.sh exists and is executable" {
  [ -f "$SKILL_DIR/scripts/finalize.sh" ]
  [ -x "$SKILL_DIR/scripts/finalize.sh" ]
}

# ---------- Foundation scripts present (ADR-042) ----------

@test "E28-S107: foundation script memory-loader.sh exists in scripts/" {
  [ -f "$SCRIPTS_DIR/memory-loader.sh" ]
}

@test "E28-S107: foundation script resolve-config.sh exists in scripts/" {
  [ -f "$SCRIPTS_DIR/resolve-config.sh" ]
}

@test "E28-S107: foundation script checkpoint.sh exists in scripts/" {
  [ -f "$SCRIPTS_DIR/checkpoint.sh" ]
}

# ---------- AC1: Frontmatter linter passes ----------

@test "E28-S107: lint-skill-frontmatter.sh passes on gaia-memory-hygiene SKILL.md" {
  cd "$REPO_ROOT"
  bash .github/scripts/lint-skill-frontmatter.sh
}

# ---------- Token budget — body stays within NFR-048 reasonable limits ----------

@test "E28-S107: SKILL.md body under 1500 lines (NFR-048 token budget guard)" {
  line_count=$(wc -l < "$SKILL_FILE")
  [ "$line_count" -lt 1500 ]
}
