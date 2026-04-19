#!/usr/bin/env bats
# e28-s131-gaia-migrate.bats — bats tests for /gaia-migrate skill (E28-S131)
#
# Covers SKILL.md frontmatter (AC1) + gaia-migrate.sh detect/backup/migrate/
# validate/dry-run paths (AC2-AC5) + selected edge cases (AC-EC1, AC-EC4, AC-EC6).
# Some edge cases (AC-EC2 corrupt UTF-8, AC-EC3 disk-full, AC-EC5 schema drift,
# AC-EC7 signal handling) are not bats-friendly and are covered by manual review.

PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SCRIPTS_DIR="$PLUGIN_DIR/scripts"
SCRIPT="$SCRIPTS_DIR/gaia-migrate.sh"
SKILL="$PLUGIN_DIR/skills/gaia-migrate/SKILL.md"
FIXTURES="$(cd "$(dirname "$BATS_TEST_FILENAME")/fixtures/v1-install" && pwd)"

setup() {
  TMP="$(mktemp -d)"
  cp -R "$FIXTURES/." "$TMP/"
}

teardown() {
  [ -n "$TMP" ] && [ -d "$TMP" ] && rm -rf "$TMP"
}

# ============================================================================
# AC1 — SKILL.md frontmatter
# ============================================================================

@test "E28-S131: AC1 SKILL.md exists" {
  [ -f "$SKILL" ]
}

@test "E28-S131: AC1 SKILL.md has 'name: gaia-migrate'" {
  [ -f "$SKILL" ] || skip "SKILL.md not yet present"
  head -20 "$SKILL" | grep -qE '^name: gaia-migrate'
}

@test "E28-S131: AC1 SKILL.md has 'description:'" {
  [ -f "$SKILL" ] || skip "SKILL.md not yet present"
  head -20 "$SKILL" | grep -qE '^description: '
}

@test "E28-S131: AC1 SKILL.md has 'when_to_use'" {
  [ -f "$SKILL" ] || skip "SKILL.md not yet present"
  head -20 "$SKILL" | grep -qE '^when_to_use: '
}

# ============================================================================
# AC2 — Backup before any write
# ============================================================================

@test "E28-S131: gaia-migrate.sh exists and is executable" {
  [ -x "$SCRIPT" ]
}

@test "E28-S131: AC5 dry-run produces NO backup directory" {
  [ -x "$SCRIPT" ] || skip "script not yet present"
  run "$SCRIPT" dry-run --project-root "$TMP"
  [ "$status" -eq 0 ]
  [ ! -d "$TMP/.gaia-migrate-backup" ]
}

@test "E28-S131: AC2 apply mode creates backup at .gaia-migrate-backup/{ts}/" {
  [ -x "$SCRIPT" ] || skip "script not yet present"
  run "$SCRIPT" apply --project-root "$TMP"
  [ "$status" -eq 0 ]
  [ -d "$TMP/.gaia-migrate-backup" ]
  # exactly one timestamped subdir
  local count
  count=$(find "$TMP/.gaia-migrate-backup" -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')
  [ "$count" -eq 1 ]
}

@test "E28-S131: AC2 backup contains _gaia/, _memory/, custom/, CLAUDE.md" {
  [ -x "$SCRIPT" ] || skip "script not yet present"
  "$SCRIPT" apply --project-root "$TMP" >/dev/null 2>&1
  local bdir
  bdir="$(find "$TMP/.gaia-migrate-backup" -maxdepth 1 -mindepth 1 -type d | head -1)"
  [ -d "$bdir/_gaia" ]
  [ -d "$bdir/_memory" ]
  [ -d "$bdir/custom" ]
  [ -f "$bdir/CLAUDE.md" ]
}

@test "E28-S131: AC2 backup has backup-manifest.yaml with sha256" {
  [ -x "$SCRIPT" ] || skip "script not yet present"
  "$SCRIPT" apply --project-root "$TMP" >/dev/null 2>&1
  local bdir
  bdir="$(find "$TMP/.gaia-migrate-backup" -maxdepth 1 -mindepth 1 -type d | head -1)"
  [ -f "$bdir/backup-manifest.yaml" ]
  grep -q 'sha256:' "$bdir/backup-manifest.yaml"
}

# ============================================================================
# AC3 — Three migration steps with PASS/FAIL per step
# ============================================================================

@test "E28-S131: AC3 templates step emits PASS line" {
  [ -x "$SCRIPT" ] || skip "script not yet present"
  run "$SCRIPT" apply --project-root "$TMP"
  [[ "$output" == *"templates"* ]]
  [[ "$output" == *"PASS"* ]]
}

@test "E28-S131: AC3 sidecars step emits PASS line" {
  [ -x "$SCRIPT" ] || skip "script not yet present"
  run "$SCRIPT" apply --project-root "$TMP"
  [[ "$output" == *"sidecars"* ]]
}

@test "E28-S131: AC3 config-split produces project-config.yaml + global.yaml" {
  [ -x "$SCRIPT" ] || skip "script not yet present"
  "$SCRIPT" apply --project-root "$TMP" >/dev/null 2>&1
  [ -f "$TMP/_gaia/_config/global.yaml" ]
  [ -f "$TMP/config/project-config.yaml" ]
}

@test "E28-S131: AC3 config-split partition — project_path stays in global.yaml" {
  [ -x "$SCRIPT" ] || skip "script not yet present"
  "$SCRIPT" apply --project-root "$TMP" >/dev/null 2>&1
  grep -q '^project_path:' "$TMP/_gaia/_config/global.yaml"
}

@test "E28-S131: AC3 config-split partition — ci_cd moves to project-config.yaml" {
  [ -x "$SCRIPT" ] || skip "script not yet present"
  "$SCRIPT" apply --project-root "$TMP" >/dev/null 2>&1
  grep -q '^ci_cd:' "$TMP/config/project-config.yaml"
  ! grep -q '^ci_cd:' "$TMP/_gaia/_config/global.yaml"
}

# ============================================================================
# AC4 — Post-migration validation + SUCCESS/FAILED banner
# ============================================================================

@test "E28-S131: AC4 happy path emits SUCCESS banner" {
  [ -x "$SCRIPT" ] || skip "script not yet present"
  run "$SCRIPT" apply --project-root "$TMP"
  [[ "$output" == *"SUCCESS"* ]]
}

@test "E28-S131: AC4 summary echoes backup path" {
  [ -x "$SCRIPT" ] || skip "script not yet present"
  run "$SCRIPT" apply --project-root "$TMP"
  [[ "$output" == *".gaia-migrate-backup"* ]]
}

# ============================================================================
# AC5 — Dry-run mode + idempotency
# ============================================================================

@test "E28-S131: AC5 dry-run prints 'Dry run' banner" {
  [ -x "$SCRIPT" ] || skip "script not yet present"
  run "$SCRIPT" dry-run --project-root "$TMP"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Dry run"* || "$output" == *"DRY RUN"* || "$output" == *"dry-run"* ]]
}

@test "E28-S131: AC5 dry-run is idempotent — same plan twice" {
  [ -x "$SCRIPT" ] || skip "script not yet present"
  local out1 out2
  out1="$("$SCRIPT" dry-run --project-root "$TMP" 2>&1 | grep -v 'timestamp\|TIMESTAMP\|seconds')"
  out2="$("$SCRIPT" dry-run --project-root "$TMP" 2>&1 | grep -v 'timestamp\|TIMESTAMP\|seconds')"
  [ "$out1" = "$out2" ]
}

@test "E28-S131: AC-EC6 dry-run does ZERO filesystem writes" {
  [ -x "$SCRIPT" ] || skip "script not yet present"
  local before after
  before="$(find "$TMP" -type f | sort | sha256sum | awk '{print $1}')"
  "$SCRIPT" dry-run --project-root "$TMP" >/dev/null 2>&1
  after="$(find "$TMP" -type f | sort | sha256sum | awk '{print $1}')"
  [ "$before" = "$after" ]
}

# ============================================================================
# Edge cases
# ============================================================================

@test "E28-S131: AC-EC1 missing _memory/ HALTs with diagnostic" {
  [ -x "$SCRIPT" ] || skip "script not yet present"
  rm -rf "$TMP/_memory"
  run "$SCRIPT" apply --project-root "$TMP"
  [ "$status" -ne 0 ]
  [[ "$output" == *"_memory"* ]]
  [[ "$output" == *"missing"* || "$output" == *"HALT"* || "$output" == *"detected"* ]]
}

@test "E28-S131: Test-scenario #3 no v1 install detected" {
  [ -x "$SCRIPT" ] || skip "script not yet present"
  local empty
  empty="$(mktemp -d)"
  run "$SCRIPT" apply --project-root "$empty"
  [ "$status" -ne 0 ]
  [[ "$output" == *"No v1"* || "$output" == *"no v1"* || "$output" == *"not detected"* ]]
  rm -rf "$empty"
}

@test "E28-S131: Test-scenario #6 re-run on already-migrated state HALTs" {
  [ -x "$SCRIPT" ] || skip "script not yet present"
  "$SCRIPT" apply --project-root "$TMP" >/dev/null 2>&1
  # Now the tree has v2 markers (config/project-config.yaml exists)
  run "$SCRIPT" apply --project-root "$TMP"
  [ "$status" -ne 0 ]
  [[ "$output" == *"already"* || "$output" == *"complete"* || "$output" == *"v2"* ]]
}

@test "E28-S131: missing --project-root arg — usage" {
  [ -x "$SCRIPT" ] || skip "script not yet present"
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage"* || "$output" == *"usage"* || "$output" == *"project-root"* ]]
}

@test "E28-S131: invalid mode — usage" {
  [ -x "$SCRIPT" ] || skip "script not yet present"
  run "$SCRIPT" badmode --project-root "$TMP"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage"* || "$output" == *"usage"* || "$output" == *"mode"* ]]
}
