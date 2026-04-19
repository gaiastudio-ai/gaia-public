#!/usr/bin/env bats
# brownfield-onboarding-parity.bats — E28-S105 parity + structure tests
#
# Validates the conversion of _gaia/lifecycle/workflows/anytime/brownfield-onboarding/
# to a native SKILL.md at plugins/gaia/skills/gaia-brownfield/SKILL.md.
#
#   AC1: SKILL.md exists at the native-conversion target path with valid
#        frontmatter (name, description, tools, model) per E28-S74 schema
#        and passes the frontmatter linter with zero errors.
#   AC2: All five multi-scan branches preserved as prose sections —
#        doc-code, hardcoded, integration-seam, runtime-behavior, security.
#   AC3: Template-driven output generation preserved — skill references each
#        of the legacy output artifacts (project-documentation.md,
#        api-documentation.md, ux-design.md, event-catalog.md, dependency-map.md,
#        nfr-assessment.md, performance-test-plan-{date}.md, prd.md,
#        architecture.md, epics-and-stories.md, brownfield-scan-test-execution.md,
#        brownfield-onboarding.md).
#   AC4: Post-complete gates preserved — nfr-assessment.md,
#        performance-test-plan-{date}.md, conditional test-environment.yaml gate.
#   AC5: Zero orphaned engine-specific XML tags (<action>, <template-output>,
#        <invoke-workflow>, <check>, <ask>, <step>, <workflow>).
#   AC6: Functional parity confirmed via this harness.
#
# Refs: E28-S105, FR-323, FR-325, NFR-048, NFR-053, ADR-041, ADR-042
#
# Usage:
#   bats tests/cluster-14-parity/brownfield-onboarding-parity.bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SKILLS_DIR="$REPO_ROOT/plugins/gaia/skills"
  SCRIPTS_DIR="$REPO_ROOT/plugins/gaia/scripts"

  SKILL="gaia-brownfield"
  SKILL_DIR="$SKILLS_DIR/$SKILL"
  SKILL_FILE="$SKILL_DIR/SKILL.md"
}

# ---------- AC1: SKILL.md exists and has valid frontmatter ----------

@test "E28-S105: SKILL.md exists at plugins/gaia/skills/gaia-brownfield/" {
  [ -f "$SKILL_FILE" ]
}

@test "E28-S105: SKILL.md has YAML frontmatter delimiters" {
  head -1 "$SKILL_FILE" | grep -q "^---$"
  awk 'NR>1 && /^---$/{found=1; exit} END{exit !found}' "$SKILL_FILE"
}

@test "E28-S105: SKILL.md frontmatter has name: gaia-brownfield" {
  awk '/^---$/{n++; next} n==1{print}' "$SKILL_FILE" | grep -q '^name: gaia-brownfield'
}

@test "E28-S105: SKILL.md frontmatter description includes 'brownfield' trigger" {
  awk '/^---$/{n++; next} n==1{print}' "$SKILL_FILE" | grep -qi '^description:.*brownfield'
}

@test "E28-S105: SKILL.md frontmatter has tools field" {
  awk '/^---$/{n++; next} n==1{print}' "$SKILL_FILE" | grep -q '^tools:'
}

@test "E28-S105: SKILL.md frontmatter tools contains Agent (subagent delegation)" {
  awk '/^---$/{n++; next} n==1{print}' "$SKILL_FILE" | grep -q 'tools:.*Agent'
}

@test "E28-S105: SKILL.md frontmatter tools contains Read, Write, Bash, Grep, Glob" {
  fm=$(awk '/^---$/{n++; next} n==1{print}' "$SKILL_FILE")
  echo "$fm" | grep -q 'tools:.*Read'
  echo "$fm" | grep -q 'tools:.*Write'
  echo "$fm" | grep -q 'tools:.*Bash'
  echo "$fm" | grep -q 'tools:.*Grep'
  echo "$fm" | grep -q 'tools:.*Glob'
}

@test "E28-S105: SKILL.md frontmatter has model field per E28-S74 schema" {
  awk '/^---$/{n++; next} n==1{print}' "$SKILL_FILE" | grep -q '^model:'
}

# ---------- AC2: Five multi-scan prose sections preserved ----------

@test "E28-S105: SKILL.md body contains Doc-Code Scan prose section" {
  grep -qiE '^##.*(doc[- ]?code|documentation[- ]code).*scan' "$SKILL_FILE"
}

@test "E28-S105: SKILL.md body contains Hardcoded Values Scan prose section" {
  grep -qiE '^##.*hard[- ]?coded.*(scan|values)' "$SKILL_FILE"
}

@test "E28-S105: SKILL.md body contains Integration Seam Scan prose section" {
  grep -qiE '^##.*integration[- ]?seam.*scan' "$SKILL_FILE"
}

@test "E28-S105: SKILL.md body contains Runtime Behavior Scan prose section" {
  grep -qiE '^##.*runtime[- ]?behavior.*scan' "$SKILL_FILE"
}

@test "E28-S105: SKILL.md body contains Security Scan prose section" {
  grep -qiE '^##.*security.*scan' "$SKILL_FILE"
}

# ---------- AC3: Template-driven output artifacts referenced ----------

@test "E28-S105: SKILL.md references brownfield-onboarding.md primary output" {
  grep -q 'brownfield-onboarding.md' "$SKILL_FILE"
}

@test "E28-S105: SKILL.md references project-documentation.md output" {
  grep -q 'project-documentation.md' "$SKILL_FILE"
}

@test "E28-S105: SKILL.md references api-documentation.md output" {
  grep -q 'api-documentation.md' "$SKILL_FILE"
}

@test "E28-S105: SKILL.md references ux-design.md output" {
  grep -q 'ux-design.md' "$SKILL_FILE"
}

@test "E28-S105: SKILL.md references event-catalog.md output" {
  grep -q 'event-catalog.md' "$SKILL_FILE"
}

@test "E28-S105: SKILL.md references dependency-map.md output" {
  grep -q 'dependency-map.md' "$SKILL_FILE"
}

@test "E28-S105: SKILL.md references nfr-assessment.md output (gate file)" {
  grep -q 'nfr-assessment.md' "$SKILL_FILE"
}

@test "E28-S105: SKILL.md references performance-test-plan with date substitution" {
  grep -qE 'performance-test-plan-\{date\}\.md|performance-test-plan' "$SKILL_FILE"
}

@test "E28-S105: SKILL.md references prd.md output" {
  grep -q 'prd.md' "$SKILL_FILE"
}

@test "E28-S105: SKILL.md references architecture.md output" {
  grep -q 'architecture.md' "$SKILL_FILE"
}

@test "E28-S105: SKILL.md references epics-and-stories.md output" {
  grep -q 'epics-and-stories.md' "$SKILL_FILE"
}

@test "E28-S105: SKILL.md references brownfield-scan-test-execution.md output" {
  grep -q 'brownfield-scan-test-execution.md' "$SKILL_FILE"
}

# ---------- AC4: Post-complete gates preserved ----------

@test "E28-S105: SKILL.md references nfr_assessment_exists gate or equivalent" {
  grep -qiE 'nfr[_ -]?assessment[_ -]?exists|nfr[_ -]?assessment.*gate' "$SKILL_FILE"
}

@test "E28-S105: SKILL.md references performance_test_plan_exists gate or equivalent" {
  grep -qiE 'performance[_ -]?test[_ -]?plan[_ -]?exists|performance.*plan.*gate' "$SKILL_FILE"
}

@test "E28-S105: SKILL.md references conditional test-environment.yaml gate" {
  grep -qE 'test[- ]?environment\.yaml' "$SKILL_FILE"
}

@test "E28-S105: SKILL.md documents conditional gate semantics (infra-detected)" {
  grep -qiE 'conditional|infra[- ]?detect|infrastructure.*detect|test infrastructure' "$SKILL_FILE"
}

# ---------- AC5: Zero orphaned engine-specific XML tags ----------

@test "E28-S105: SKILL.md contains NO <action> tags" {
  ! grep -q '<action' "$SKILL_FILE"
}

@test "E28-S105: SKILL.md contains NO <template-output> tags" {
  ! grep -q '<template-output' "$SKILL_FILE"
}

@test "E28-S105: SKILL.md contains NO <invoke-workflow> tags" {
  ! grep -q '<invoke-workflow' "$SKILL_FILE"
}

@test "E28-S105: SKILL.md contains NO <check> tags" {
  ! grep -q '<check' "$SKILL_FILE"
}

@test "E28-S105: SKILL.md contains NO <ask> tags" {
  ! grep -q '<ask' "$SKILL_FILE"
}

@test "E28-S105: SKILL.md contains NO <step> tags" {
  ! grep -qE '<step[ >]' "$SKILL_FILE"
}

@test "E28-S105: SKILL.md contains NO <workflow> wrapper tags" {
  ! grep -qE '<workflow[ >]' "$SKILL_FILE"
}

# ---------- Foundation script wiring (ADR-042 / FR-325) ----------

@test "E28-S105: SKILL.md wires resolve-config.sh inline" {
  grep -qE 'resolve-config\.sh|setup\.sh' "$SKILL_FILE"
}

@test "E28-S105: SKILL.md wires checkpoint.sh inline" {
  grep -qE 'checkpoint\.sh|finalize\.sh' "$SKILL_FILE"
}

@test "E28-S105: SKILL.md wires validate-gate.sh inline (or file-gate equivalent)" {
  grep -qE 'validate-gate\.sh|file-gate\.sh' "$SKILL_FILE"
}

@test "E28-S105: SKILL.md references ADR-041 (native execution model)" {
  grep -q 'ADR-041' "$SKILL_FILE"
}

@test "E28-S105: SKILL.md references ADR-042 (scripts-over-LLM)" {
  grep -q 'ADR-042' "$SKILL_FILE"
}

# ---------- NFR assessment integration (AC: 4, EC5, EC9) ----------

@test "E28-S105: SKILL.md invokes test-architect subagent for NFR assessment" {
  grep -qiE 'test[- ]?architect|Sable' "$SKILL_FILE"
}

@test "E28-S105: SKILL.md handles AC-EC5 — test-architect unavailable fallback" {
  grep -qiE 'unavailable|not installed|missing.*(subagent|agent)|fallback|stub' "$SKILL_FILE"
}

@test "E28-S105: SKILL.md handles AC-EC9 — both NFR outputs required" {
  grep -qiE 'both.*(required|emitted)|halt.*(missing|either)|require.*both' "$SKILL_FILE"
}

# ---------- Foundation scripts present ----------

@test "E28-S105: foundation script resolve-config.sh exists in scripts/" {
  [ -f "$SCRIPTS_DIR/resolve-config.sh" ]
}

@test "E28-S105: foundation script checkpoint.sh exists in scripts/" {
  [ -f "$SCRIPTS_DIR/checkpoint.sh" ]
}

@test "E28-S105: foundation script validate-gate.sh exists in scripts/" {
  [ -f "$SCRIPTS_DIR/validate-gate.sh" ]
}

@test "E28-S105: foundation script template-header.sh exists in scripts/" {
  [ -f "$SCRIPTS_DIR/template-header.sh" ]
}

@test "E28-S105: foundation script memory-loader.sh exists in scripts/" {
  [ -f "$SCRIPTS_DIR/memory-loader.sh" ]
}

# ---------- Edge case coverage (9 AC-EC items) ----------

@test "E28-S105: SKILL.md handles AC-EC1 — token budget constraints" {
  grep -qiE 'token budget|NFR-048|activation budget' "$SKILL_FILE"
}

@test "E28-S105: SKILL.md handles AC-EC2 — missing foundation script fail-fast" {
  grep -qiE 'missing.*script|not executable|fail.*fast|non-executable' "$SKILL_FILE"
}

@test "E28-S105: SKILL.md handles AC-EC3 — no-test-infra greenfield path" {
  grep -qiE 'no test infrastructure|zero test|greenfield|not triggered|no.*infra.*detect' "$SKILL_FILE"
}

@test "E28-S105: SKILL.md handles AC-EC6 — large codebase streaming/truncation" {
  grep -qiE 'truncat|stream|chunk|large codebase|100k' "$SKILL_FILE"
}

@test "E28-S105: SKILL.md handles AC-EC7 — parallel invocation isolation" {
  grep -qiE 'parallel invocation|isolat|independent.*config|different project roots' "$SKILL_FILE"
}

@test "E28-S105: SKILL.md handles AC-EC8 — scanner crash mid-run" {
  grep -qiE 'scan.*fail|scanner.*crash|remaining scanners continue|partial-result' "$SKILL_FILE"
}

# ---------- Layout constraints ----------

@test "E28-S105: gaia-brownfield/ has no workflow.yaml (legacy engine artifact)" {
  [ ! -f "$SKILL_DIR/workflow.yaml" ]
}

@test "E28-S105: gaia-brownfield/ has no instructions.xml (legacy engine artifact)" {
  [ ! -f "$SKILL_DIR/instructions.xml" ]
}

@test "E28-S105: gaia-brownfield/ has no .resolved/ subdirectory" {
  [ ! -d "$SKILL_DIR/.resolved" ]
}

@test "E28-S105: gaia-brownfield/scripts/ directory exists" {
  [ -d "$SKILL_DIR/scripts" ]
}

@test "E28-S105: gaia-brownfield/scripts/setup.sh exists and is executable" {
  [ -f "$SKILL_DIR/scripts/setup.sh" ]
  [ -x "$SKILL_DIR/scripts/setup.sh" ]
}

@test "E28-S105: gaia-brownfield/scripts/finalize.sh exists and is executable" {
  [ -f "$SKILL_DIR/scripts/finalize.sh" ]
  [ -x "$SKILL_DIR/scripts/finalize.sh" ]
}

# ---------- AC1: Frontmatter linter passes ----------

@test "E28-S105: lint-skill-frontmatter.sh passes on gaia-brownfield SKILL.md" {
  cd "$REPO_ROOT"
  bash .github/scripts/lint-skill-frontmatter.sh
}

# ---------- Token budget — body stays within NFR-048 reasonable limits ----------

@test "E28-S105: SKILL.md body under 1500 lines (NFR-048 token budget guard)" {
  line_count=$(wc -l < "$SKILL_FILE")
  [ "$line_count" -lt 1500 ]
}
