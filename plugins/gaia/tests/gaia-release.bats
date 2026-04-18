#!/usr/bin/env bats
# gaia-release.bats — E28-S167 tests for the /gaia-release native skill.
#
# Validates:
#   AC1: SKILL.md documents the full release procedure (version bump, commit,
#        tag, push, GitHub Release).
#   AC2: SKILL.md references scripts/version-bump.js.
#   AC3: /gaia-release is registered in gaia-help.csv and workflow-manifest.csv
#        so it surfaces from /gaia-help.
#   Val INFO 1: CURRENT version-bump behavior (2 global files per ADR-025
#               Model B) — no stale "6 files" claim.
#   Val INFO 2: Full CLI surface — --modules, --prerelease rc,
#               --strip-prerelease, --dry-run.

load 'test_helper.bash'

SKILL_DIR="$BATS_TEST_DIRNAME/../skills/gaia-release"
CONFIG_DIR_CANDIDATES=(
  "$BATS_TEST_DIRNAME/../../../../Gaia-framework/_gaia/_config"
  "$BATS_TEST_DIRNAME/../../../../_gaia/_config"
)

# Resolve the first existing CSV registry dir (Gaia-framework source of
# truth, or the project-root running framework). Either is acceptable — both
# copies must surface /gaia-release for AC3 to pass.
resolve_config_dir() {
  for d in "${CONFIG_DIR_CANDIDATES[@]}"; do
    if [ -d "$d" ]; then
      printf '%s' "$d"
      return 0
    fi
  done
  return 1
}

setup() { common_setup; }
teardown() { common_teardown; }

# ---------- AC1: SKILL.md structure ----------

@test "AC1: SKILL.md exists in gaia-release skill directory" {
  [ -f "$SKILL_DIR/SKILL.md" ]
}

@test "AC1: frontmatter contains name: gaia-release" {
  run head -20 "$SKILL_DIR/SKILL.md"
  [[ "$output" == *"name: gaia-release"* ]]
}

@test "AC1: frontmatter contains description field" {
  run head -20 "$SKILL_DIR/SKILL.md"
  [[ "$output" == *"description:"* ]]
}

@test "AC1: frontmatter contains allowed-tools" {
  run head -30 "$SKILL_DIR/SKILL.md"
  [[ "$output" == *"allowed-tools:"* ]]
}

@test "AC1: frontmatter opens and closes with ---" {
  local first_line
  first_line=$(head -1 "$SKILL_DIR/SKILL.md")
  [ "$first_line" = "---" ]

  local closing_line
  closing_line=$(awk '/^---$/{n++; if(n==2){print NR; exit}}' "$SKILL_DIR/SKILL.md")
  [ -n "$closing_line" ]
}

@test "AC1: SKILL.md documents the version-bump step" {
  run cat "$SKILL_DIR/SKILL.md"
  [[ "$output" == *"version"* ]]
  [[ "$output" == *"bump"* ]] || [[ "$output" == *"Bump"* ]]
}

@test "AC1: SKILL.md documents the commit step" {
  run cat "$SKILL_DIR/SKILL.md"
  [[ "$output" == *"commit"* ]] || [[ "$output" == *"Commit"* ]]
}

@test "AC1: SKILL.md documents the tag step" {
  run cat "$SKILL_DIR/SKILL.md"
  [[ "$output" == *"tag"* ]] || [[ "$output" == *"Tag"* ]]
}

@test "AC1: SKILL.md documents the push step" {
  run cat "$SKILL_DIR/SKILL.md"
  [[ "$output" == *"push"* ]] || [[ "$output" == *"Push"* ]]
}

@test "AC1: SKILL.md documents the GitHub Release step" {
  run cat "$SKILL_DIR/SKILL.md"
  [[ "$output" == *"GitHub Release"* ]] || [[ "$output" == *"gh release"* ]]
}

# ---------- AC2: version-bump.js reference ----------

@test "AC2: SKILL.md references scripts/version-bump.js" {
  run cat "$SKILL_DIR/SKILL.md"
  [[ "$output" == *"scripts/version-bump.js"* ]]
}

@test "AC2: SKILL.md shows npm run version:bump or the node invocation" {
  run cat "$SKILL_DIR/SKILL.md"
  [[ "$output" == *"npm run version:bump"* ]] \
    || [[ "$output" == *"node scripts/version-bump.js"* ]]
}

# ---------- AC3: /gaia-help discoverability ----------

@test "AC3: gaia-help.csv contains a release entry for /gaia-release" {
  local dir
  dir=$(resolve_config_dir) || skip "no config dir found"
  run grep -E '^"[^"]+","[^"]+","release"?' "$dir/gaia-help.csv"
  [ "$status" -eq 0 ]
  [[ "$output" == *"gaia-release"* ]]
  # Must not be just the pre-existing "release-plan" row
  [[ "$output" == *'"release",'* ]] || [[ "$output" == *',"release",'* ]]
}

@test "AC3: workflow-manifest.csv contains a release entry for /gaia-release" {
  local dir
  dir=$(resolve_config_dir) || skip "no config dir found"
  run grep -E '^"release",' "$dir/workflow-manifest.csv"
  [ "$status" -eq 0 ]
  [[ "$output" == *"gaia-release"* ]]
}

# ---------- Val INFO 1: ADR-025 Model B (2 global files) ----------

@test "VAL-INFO-1: SKILL.md documents ADR-025 Model B (2 global files)" {
  run cat "$SKILL_DIR/SKILL.md"
  [[ "$output" == *"ADR-025"* ]]
  [[ "$output" == *"package.json"* ]]
  [[ "$output" == *"global.yaml"* ]]
}

@test "VAL-INFO-1: SKILL.md does NOT claim the script updates 6 files" {
  run cat "$SKILL_DIR/SKILL.md"
  # The stale "6 files" narrative came from a pre-ADR-025 version. The
  # current script touches exactly 2 global files.
  [[ "$output" != *"6 files"* ]]
  [[ "$output" != *"six files"* ]]
}

# ---------- Val INFO 2: full CLI surface ----------

@test "VAL-INFO-2: SKILL.md documents --modules flag" {
  run cat "$SKILL_DIR/SKILL.md"
  [[ "$output" == *"--modules"* ]]
}

@test "VAL-INFO-2: SKILL.md documents --prerelease rc flag" {
  run cat "$SKILL_DIR/SKILL.md"
  [[ "$output" == *"--prerelease"* ]]
  [[ "$output" == *"rc"* ]]
}

@test "VAL-INFO-2: SKILL.md documents --strip-prerelease flag" {
  run cat "$SKILL_DIR/SKILL.md"
  [[ "$output" == *"--strip-prerelease"* ]]
}

@test "VAL-INFO-2: SKILL.md documents --dry-run flag" {
  run cat "$SKILL_DIR/SKILL.md"
  [[ "$output" == *"--dry-run"* ]]
}

# ---------- Story traceability ----------

@test "TRACE: SKILL.md references story E28-S167 or ADR-025" {
  run cat "$SKILL_DIR/SKILL.md"
  [[ "$output" == *"E28-S167"* ]] || [[ "$output" == *"ADR-025"* ]]
}
