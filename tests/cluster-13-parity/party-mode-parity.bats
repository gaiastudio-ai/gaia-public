#!/usr/bin/env bats
# party-mode-parity.bats — E28-S101 parity + structure tests
#
# Validates the conversion of _gaia/core/workflows/party-mode/ to a native
# SKILL.md file at plugins/gaia/skills/gaia-party/SKILL.md.
#
#   AC1: SKILL.md frontmatter conforms to canonical skill pattern
#        (name: gaia-party, description with "party mode" trigger, argument-hint,
#        context: fork, allowed-tools)
#   AC2: Five invitation modes preserved (Option A: All agents, Option B: By
#        module, Option C: Specific agents, Option D: Stakeholders only,
#        Option E: By tag) with identical selection semantics to
#        step-01-agent-loading.md
#   AC3: Sequential fork-subagent orchestration — moderator rounds invoke
#        participants one at a time, never parallel, never reordered
#   AC4: Linter compliance (enforced by separate lint-skill-frontmatter.sh run)
#   AC5: Graceful exit writes transcript to docs/creative-artifacts/party-mode-{date}.md
#   AC-EC1..AC-EC10: Edge case coverage documented in body
#
# Refs: E28-S101, FR-323, FR-330, NFR-048, NFR-053, ADR-041, ADR-045
#
# Usage:
#   bats tests/cluster-13-parity/party-mode-parity.bats
#
# Dependencies: bats-core 1.10+

# ---------- Helpers ----------

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SKILLS_DIR="$REPO_ROOT/plugins/gaia/skills"

  SKILL="gaia-party"
  SKILL_DIR="$SKILLS_DIR/$SKILL"
  SKILL_FILE="$SKILL_DIR/SKILL.md"
}

# ---------- AC1: Frontmatter conformance ----------

@test "E28-S101: SKILL.md exists at plugins/gaia/skills/gaia-party/" {
  [ -f "$SKILL_FILE" ]
}

@test "E28-S101: SKILL.md has YAML frontmatter delimiters" {
  head -1 "$SKILL_FILE" | grep -q "^---$"
  awk 'NR>1 && /^---$/{found=1; exit} END{exit !found}' "$SKILL_FILE"
}

@test "E28-S101: SKILL.md frontmatter has name: gaia-party" {
  head -20 "$SKILL_FILE" | grep -q '^name: gaia-party'
}

@test "E28-S101: SKILL.md frontmatter description includes 'party mode' trigger" {
  head -20 "$SKILL_FILE" | grep -qi '^description:.*party mode'
}

@test "E28-S101: SKILL.md frontmatter has argument-hint" {
  head -20 "$SKILL_FILE" | grep -q '^argument-hint:'
}

@test "E28-S101: SKILL.md frontmatter has context: fork" {
  head -20 "$SKILL_FILE" | grep -q '^context: fork'
}

@test "E28-S101: SKILL.md frontmatter has allowed-tools with Read" {
  head -20 "$SKILL_FILE" | grep -q 'allowed-tools:.*Read'
}

@test "E28-S101: SKILL.md frontmatter allowed-tools contains Grep" {
  head -20 "$SKILL_FILE" | grep -q 'allowed-tools:.*Grep'
}

@test "E28-S101: SKILL.md frontmatter allowed-tools contains Glob" {
  head -20 "$SKILL_FILE" | grep -q 'allowed-tools:.*Glob'
}

@test "E28-S101: SKILL.md frontmatter allowed-tools contains Bash" {
  head -20 "$SKILL_FILE" | grep -q 'allowed-tools:.*Bash'
}

# ---------- AC2: Five invitation modes preserved ----------

@test "E28-S101: SKILL.md references Option A — All agents" {
  grep -qE 'Option A|All agents|All GAIA agents' "$SKILL_FILE"
}

@test "E28-S101: SKILL.md references Option B — By module" {
  grep -qE 'Option B|By module' "$SKILL_FILE"
}

@test "E28-S101: SKILL.md references Option C — Specific agents" {
  grep -qE 'Option C|Specific agents' "$SKILL_FILE"
}

@test "E28-S101: SKILL.md references Option D — Stakeholders only" {
  grep -qE 'Option D|Stakeholders only' "$SKILL_FILE"
}

@test "E28-S101: SKILL.md references Option E — By tag" {
  grep -qE 'Option E|By tag' "$SKILL_FILE"
}

@test "E28-S101: SKILL.md lists the four GAIA modules for Option B" {
  grep -q 'lifecycle' "$SKILL_FILE"
  grep -q 'creative' "$SKILL_FILE"
  grep -q 'testing' "$SKILL_FILE"
  # dev module referenced
  grep -qE '\bdev\b' "$SKILL_FILE"
}

@test "E28-S101: SKILL.md references agent-manifest.csv for GAIA discovery" {
  grep -q 'agent-manifest.csv' "$SKILL_FILE"
}

@test "E28-S101: SKILL.md references custom/stakeholders for stakeholder discovery" {
  grep -q 'custom/stakeholders' "$SKILL_FILE"
}

@test "E28-S101: SKILL.md references alternative syntax 'invite all {tag}'" {
  grep -qE 'invite all' "$SKILL_FILE"
}

@test "E28-S101: SKILL.md enforces name disambiguation via [Stakeholder] prefix (FR-159)" {
  grep -q '\[Stakeholder\]' "$SKILL_FILE"
}

# ---------- AC3: Sequential fork-subagent orchestration (ADR-045) ----------

@test "E28-S101: SKILL.md declares sequential-only contract (no parallel)" {
  grep -qiE 'sequential|never parallel|deterministic turn' "$SKILL_FILE"
}

@test "E28-S101: SKILL.md references ADR-045 (sequential fork subagents)" {
  grep -q 'ADR-045' "$SKILL_FILE"
}

@test "E28-S101: SKILL.md references ADR-041 (native execution model)" {
  grep -q 'ADR-041' "$SKILL_FILE"
}

@test "E28-S101: SKILL.md specifies 2-3 participants per round" {
  grep -qE '2[-–]3|2 to 3|two to three' "$SKILL_FILE"
}

@test "E28-S101: SKILL.md specifies 2-3 paragraph per response cap" {
  grep -qE '2[-–]3 paragraph|2 to 3 paragraph|two to three paragraph' "$SKILL_FILE"
}

@test "E28-S101: SKILL.md specifies 3-4 round check-in cadence" {
  grep -qE '3[-–]4 round|3 to 4 round|three to four round' "$SKILL_FILE"
}

# ---------- AC-EC: Edge case coverage ----------

@test "E28-S101: SKILL.md handles AC-EC1 — custom/stakeholders missing (silent zero)" {
  # Prose mentions silent/zero-stakeholders behavior when directory missing
  grep -qiE 'silent|directory.*not.*exist|zero stakeholders' "$SKILL_FILE"
}

@test "E28-S101: SKILL.md handles AC-EC2 — malformed YAML frontmatter skip with warning" {
  grep -qiE 'malformed|invalid YAML frontmatter|Skipping.*invalid' "$SKILL_FILE"
}

@test "E28-S101: SKILL.md handles AC-EC3 — 50-file stakeholder cap" {
  grep -qE '50[- ]file|first 50|50 stakeholder' "$SKILL_FILE"
}

@test "E28-S101: SKILL.md handles AC-EC4 — zero participants halt message" {
  grep -q 'no agents or stakeholders selected' "$SKILL_FILE"
}

@test "E28-S101: SKILL.md handles AC-EC7 — 100-line stakeholder file warning" {
  grep -qE '100[- ]line|100 lines' "$SKILL_FILE"
}

@test "E28-S101: SKILL.md handles AC-EC8 — subagent failure log-and-continue" {
  grep -qiE 'log.*continue|skip.*participant|failure.*continue' "$SKILL_FILE"
}

@test "E28-S101: SKILL.md handles AC-EC9 — 5K token discovery budget (NFR-029)" {
  grep -qE '5K token|5000 token|NFR-029' "$SKILL_FILE"
}

@test "E28-S101: SKILL.md handles AC-EC10 — refuses parallel mode" {
  grep -qiE 'parallel.*reject|reject.*parallel|refuse.*parallel|no.*--parallel' "$SKILL_FILE"
}

# ---------- AC5: Output path preserved ----------

@test "E28-S101: SKILL.md references output path docs/creative-artifacts/party-mode-" {
  grep -q 'docs/creative-artifacts/party-mode-' "$SKILL_FILE"
}

@test "E28-S101: SKILL.md mentions graceful exit options (save | activate | workflow)" {
  grep -qiE 'save transcript' "$SKILL_FILE"
  grep -qiE 'activate.*agent|follow.*up' "$SKILL_FILE"
  grep -qiE 'start.*workflow' "$SKILL_FILE"
}

# ---------- Layout constraints (flat: no steps/, no workflow.yaml, no .resolved/) ----------

@test "E28-S101: gaia-party/ has no steps/ subdirectory" {
  [ ! -d "$SKILL_DIR/steps" ]
}

@test "E28-S101: gaia-party/ has no workflow.yaml" {
  [ ! -f "$SKILL_DIR/workflow.yaml" ]
}

@test "E28-S101: gaia-party/ has no .resolved/ subdirectory" {
  [ ! -d "$SKILL_DIR/.resolved" ]
}

# ---------- Linter compliance (AC4) ----------

@test "E28-S101: lint-skill-frontmatter.sh passes on gaia-party SKILL.md" {
  cd "$REPO_ROOT"
  bash .github/scripts/lint-skill-frontmatter.sh
}
