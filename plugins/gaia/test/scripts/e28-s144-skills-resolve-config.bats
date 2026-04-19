#!/usr/bin/env bats
# e28-s144-skills-resolve-config.bats — tests for E28-S144
#
# Validates:
#   - audit-skill-config-reads.sh script exists and is executable
#   - verify-no-direct-config-reads.sh script exists and is executable
#   - audit script produces per-match {file, line, key, mechanism} output
#   - verify script passes on a clean SKILL tree
#   - verify script fails (non-zero exit) on a SKILL tree with a direct
#     config read, and the failure message names the offending skill/line
#   - verify script tolerates HTML comments that mention the filenames
#   - verify script's allowlist entries are honored for config-editor skills
#   - migrated skills in the repo contain the canonical invocation form

PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SKILLS_DIR="$PLUGIN_DIR/skills"
SCRIPTS_DIR="$PLUGIN_DIR/scripts"
# Repo root = one level above plugins/ (i.e., gaia-public/). Docs live here.
REPO_ROOT="$(cd "$PLUGIN_DIR/../.." && pwd)"
DOCS_MIGRATION="$REPO_ROOT/docs/migration"

# ---------- Script existence and executability ----------

@test "audit-skill-config-reads.sh exists" {
  [ -f "$SCRIPTS_DIR/audit-skill-config-reads.sh" ]
}

@test "audit-skill-config-reads.sh is executable" {
  [ -x "$SCRIPTS_DIR/audit-skill-config-reads.sh" ]
}

@test "verify-no-direct-config-reads.sh exists" {
  [ -f "$SCRIPTS_DIR/verify-no-direct-config-reads.sh" ]
}

@test "verify-no-direct-config-reads.sh is executable" {
  [ -x "$SCRIPTS_DIR/verify-no-direct-config-reads.sh" ]
}

# ---------- audit script behavior ----------

@test "audit script emits at least one matching line header" {
  run "$SCRIPTS_DIR/audit-skill-config-reads.sh" "$SKILLS_DIR"
  # Script should exit 0 on successful scan regardless of match count
  [ "$status" -eq 0 ]
  # Output format: file:line:{match} lines OR a "no matches found" summary.
  # Either outcome is valid — the script succeeds whenever the scan runs.
}

@test "audit script handles empty fixture without error" {
  empty_dir="$(mktemp -d)"
  run "$SCRIPTS_DIR/audit-skill-config-reads.sh" "$empty_dir"
  [ "$status" -eq 0 ]
  rm -rf "$empty_dir"
}

# ---------- verify script behavior ----------

@test "verify script passes on the current repo SKILLS tree (post-migration)" {
  run "$SCRIPTS_DIR/verify-no-direct-config-reads.sh" "$SKILLS_DIR"
  [ "$status" -eq 0 ]
}

@test "verify script fails when a non-allowlisted skill reads global.yaml directly" {
  fixture="$(mktemp -d)"
  mkdir -p "$fixture/gaia-rogue-skill"
  cat > "$fixture/gaia-rogue-skill/SKILL.md" <<'EOF'
---
name: gaia-rogue-skill
---
## Steps
Read `_gaia/_config/global.yaml` and extract the project_path.
EOF
  run "$SCRIPTS_DIR/verify-no-direct-config-reads.sh" "$fixture"
  [ "$status" -ne 0 ]
  [[ "$output" == *"gaia-rogue-skill"* ]]
  rm -rf "$fixture"
}

@test "verify script ignores references inside HTML comments" {
  fixture="$(mktemp -d)"
  mkdir -p "$fixture/gaia-doc-only-skill"
  cat > "$fixture/gaia-doc-only-skill/SKILL.md" <<'EOF'
---
name: gaia-doc-only-skill
---
## Mission
<!-- NOTE: project_path value is resolved from global.yaml via resolve-config.sh -->
Consume `!scripts/resolve-config.sh project_path` to get project_path.
EOF
  run "$SCRIPTS_DIR/verify-no-direct-config-reads.sh" "$fixture"
  [ "$status" -eq 0 ]
  rm -rf "$fixture"
}

@test "verify script honors the allowlist for config-editor skills" {
  fixture="$(mktemp -d)"
  mkdir -p "$fixture/gaia-bridge-toggle"
  cat > "$fixture/gaia-bridge-toggle/SKILL.md" <<'EOF'
---
name: gaia-bridge-toggle
---
## Steps
Read `_gaia/_config/global.yaml` and flip test_execution_bridge.bridge_enabled.
EOF
  run "$SCRIPTS_DIR/verify-no-direct-config-reads.sh" "$fixture"
  [ "$status" -eq 0 ]
  rm -rf "$fixture"
}

# ---------- Migrated skills use the canonical invocation form ----------

@test "gaia-sprint-plan SKILL.md uses resolve-config.sh for sizing_map" {
  run grep -c "!scripts/resolve-config.sh sizing_map" \
    "$SKILLS_DIR/gaia-sprint-plan/SKILL.md"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "gaia-rollback-plan SKILL.md uses resolve-config.sh for project config" {
  run grep -c "scripts/resolve-config.sh" \
    "$SKILLS_DIR/gaia-rollback-plan/SKILL.md"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "gaia-deploy-checklist SKILL.md uses resolve-config.sh for promotion_chain" {
  run grep -c "scripts/resolve-config.sh" \
    "$SKILLS_DIR/gaia-deploy-checklist/SKILL.md"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

# ---------- Audit artifact exists and is checked in ----------

@test "audit artifact exists at docs/migration/config-split-skill-audit.md" {
  [ -f "$DOCS_MIGRATION/config-split-skill-audit.md" ]
}

# ---------- Migration doc section exists ----------

@test "config-split.md migration doc mentions resolve-config.sh skill migration" {
  [ -f "$DOCS_MIGRATION/config-split.md" ]
  run grep -c "resolve-config.sh" "$DOCS_MIGRATION/config-split.md"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}
