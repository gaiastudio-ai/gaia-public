#!/usr/bin/env bats
# e28-s116-quick-spec-conversion.bats — E28-S116 acceptance tests
#
# Validates the conversion of the legacy quick-spec workflow
# (_gaia/lifecycle/workflows/quick-flow/quick-spec/) to a native Claude Code
# SKILL.md under plugins/gaia/skills/gaia-quick-spec/.
#
# Cluster 16 — Quick Flow (first delivery). Pairs with E28-S117 (quick-dev).
#
# Traces to FR-323, NFR-048, NFR-053, ADR-041.
#
# Dependencies: bats-core 1.10+

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SKILL_DIR="$REPO_ROOT/plugins/gaia/skills"
  LINTER="$REPO_ROOT/.github/scripts/lint-skill-frontmatter.sh"
  QS_SKILL="$SKILL_DIR/gaia-quick-spec/SKILL.md"
}

# ---------- AC1: File exists with required frontmatter ----------

@test "AC1: gaia-quick-spec/SKILL.md exists" {
  [ -f "$QS_SKILL" ]
}

@test "AC1: frontmatter name == gaia-quick-spec" {
  grep -qE '^name:[[:space:]]*gaia-quick-spec[[:space:]]*$' "$QS_SKILL"
}

@test "AC1: frontmatter description is present and non-empty" {
  grep -qE '^description:[[:space:]]*[^[:space:]]+' "$QS_SKILL"
}

@test "AC1: frontmatter argument-hint is present" {
  grep -qE '^argument-hint:' "$QS_SKILL"
}

@test "AC1: frontmatter tools contains Read Write Edit Bash" {
  grep -qE '^tools:' "$QS_SKILL"
  local line
  line=$(grep -E '^tools:' "$QS_SKILL")
  [[ "$line" == *"Read"* ]]
  [[ "$line" == *"Write"* ]]
  [[ "$line" == *"Edit"* ]]
  [[ "$line" == *"Bash"* ]]
}

# ---------- AC2: Five-step flow preserved verbatim ----------

@test "AC2: SKILL.md contains Step 1 Scope heading" {
  grep -qE '^#+ (Step 1|### Step 1).*Scope' "$QS_SKILL"
}

@test "AC2: SKILL.md contains Step 2 Quick Analysis heading" {
  grep -qE '^#+ (Step 2|### Step 2).*Quick Analysis' "$QS_SKILL"
}

@test "AC2: SKILL.md contains Step 3 Escape Hatch heading" {
  grep -qE '^#+ (Step 3|### Step 3).*Escape Hatch' "$QS_SKILL"
}

@test "AC2: SKILL.md contains Step 4 Generate Quick Spec heading" {
  grep -qE '^#+ (Step 4|### Step 4).*Generate Quick Spec' "$QS_SKILL"
}

@test "AC2: SKILL.md contains Step 5 Generate Output heading" {
  grep -qE '^#+ (Step 5|### Step 5).*Generate Output' "$QS_SKILL"
}

@test "AC2: preserves first Scope prompt verbatim" {
  grep -qF 'What small change or feature do you want to spec?' "$QS_SKILL"
}

@test "AC2: preserves second Scope prompt verbatim" {
  grep -qF 'Which files are likely affected?' "$QS_SKILL"
}

@test "AC2: preserves scope-threshold heuristic (>5 files OR >1 day)" {
  # Expect both "5 files" and "1 day" mentioned in the escape hatch guardrail.
  grep -qE '5[[:space:]]*files' "$QS_SKILL"
  grep -qE '1[[:space:]]*day' "$QS_SKILL"
}

@test "AC2: suggests /gaia-create-prd on escalation" {
  grep -qF '/gaia-create-prd' "$QS_SKILL"
}

@test "AC2: preserves canonical output path template quick-spec-{spec_name}.md" {
  grep -qF 'docs/implementation-artifacts/quick-spec-{spec_name}.md' "$QS_SKILL"
}

@test "AC2: output section lists all 5 required sections (summary, files, steps, AC, risks)" {
  grep -qiE 'summary' "$QS_SKILL"
  grep -qiE 'files to change' "$QS_SKILL"
  grep -qiE 'implementation steps' "$QS_SKILL"
  grep -qiE 'acceptance criteria' "$QS_SKILL"
  grep -qiE 'risks' "$QS_SKILL"
}

# ---------- AC3: Frontmatter linter passes ----------

@test "AC3: frontmatter linter returns exit 0 for the plugins/gaia/skills tree" {
  cd "$REPO_ROOT"
  run bash "$LINTER"
  [ "$status" -eq 0 ]
  [[ "$output" != *ERROR* ]]
}

@test "AC3: linter reports no errors mentioning gaia-quick-spec" {
  cd "$REPO_ROOT"
  run bash "$LINTER"
  [[ "$output" != *"gaia-quick-spec"*"ERROR"* ]]
  [[ "$output" != *"ERROR"*"gaia-quick-spec"* ]]
}

# ---------- AC4: Parity with legacy workflow (NFR-053) ----------

@test "AC4: legacy workflow source exists (for parity reference)" {
  [ -f "$REPO_ROOT/../_gaia/lifecycle/workflows/quick-flow/quick-spec/instructions.xml" ]
}

@test "AC4: every legacy step title is present in the native SKILL.md" {
  local legacy="$REPO_ROOT/../_gaia/lifecycle/workflows/quick-flow/quick-spec/instructions.xml"
  [ -f "$legacy" ] || skip "legacy source not present in working tree"
  for title in "Scope" "Quick Analysis" "Escape Hatch Check" "Generate Quick Spec" "Generate Output"; do
    grep -qF "$title" "$QS_SKILL" || { echo "missing legacy step title: $title"; return 1; }
  done
}

@test "AC4: native SKILL.md preserves both legacy Scope prompts byte-for-byte" {
  local legacy="$REPO_ROOT/../_gaia/lifecycle/workflows/quick-flow/quick-spec/instructions.xml"
  [ -f "$legacy" ] || skip "legacy source not present in working tree"
  grep -qF 'What small change or feature do you want to spec?' "$legacy"
  grep -qF 'What small change or feature do you want to spec?' "$QS_SKILL"
  grep -qF 'Which files are likely affected?' "$legacy"
  grep -qF 'Which files are likely affected?' "$QS_SKILL"
}

# ---------- Canonical shape (per gaia-create-story reference) ----------

@test "Canonical shape: SKILL.md has ## Mission section" {
  grep -qE '^## Mission' "$QS_SKILL"
}

@test "Canonical shape: SKILL.md has ## Critical Rules section" {
  grep -qE '^## Critical Rules' "$QS_SKILL"
}

# ---------- ADR-041 traceability ----------

@test "ADR-041 traceability: SKILL.md cites ADR-041" {
  grep -qE 'ADR-041' "$QS_SKILL"
}

@test "ADR-041 traceability: SKILL.md cites legacy source path" {
  grep -qE '_gaia/lifecycle/workflows/quick-flow/quick-spec' "$QS_SKILL"
}
