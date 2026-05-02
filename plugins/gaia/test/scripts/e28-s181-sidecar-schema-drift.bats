#!/usr/bin/env bats
# e28-s181-sidecar-schema-drift.bats — sidecar schema-drift detection in
# gaia-migrate.sh _migrate_sidecars (E28-S181).
#
# Closes the AC-EC5 enhancement-gap recorded in
# docs/test-artifacts/E28-S170-gaia-migrate-edge-cases-test-plan.md §5: the
# previous _migrate_sidecars implementation was verify-only and never
# inspected sidecar frontmatter. These tests assert that drifted sidecars
# now emit a per-file `manual follow-up: verify sidecar keys` line on stdout
# while clean sidecars stay silent.
#
# Acceptance criteria coverage:
#   AC1 — _migrate_sidecars diffs v1 frontmatter keys against the v2
#         canonical key set.
#   AC2 — One `manual follow-up: verify sidecar keys` line is emitted per
#         drifted file (extra key OR novel v1-only file).
#   AC3 — AC-EC5 fixture from E28-S170 §5 now passes automatically.
#   AC4 — Happy path (no drift) emits no spurious follow-up lines.

PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SCRIPTS_DIR="$PLUGIN_DIR/scripts"
SCRIPT="$SCRIPTS_DIR/gaia-migrate.sh"
FIXTURES="$(cd "$(dirname "$BATS_TEST_FILENAME")/fixtures/v1-install" && pwd)"

setup() {
  TMP="$(mktemp -d)"
  cp -R "$FIXTURES/." "$TMP/"
  # The shared v1-install fixture predates the post-E28-S131 config-split
  # required-field expansion (date / *_artifacts), so apply mode aborts at
  # subtask 4.3 against the unmodified fixture. Append the missing fields so
  # the migration runs to completion and the post-migration `SUCCESS` banner
  # is reachable. Tracked as a Finding (broken upstream fixture) — fix-out
  # of scope for E28-S181.
  cat >> "$TMP/_gaia/_config/global.yaml" <<'EOF'
date: "2026-04-18"
test_artifacts: "docs/test-artifacts"
planning_artifacts: "docs/planning-artifacts"
implementation_artifacts: "docs/implementation-artifacts"
EOF
}

teardown() {
  [ -n "$TMP" ] && [ -d "$TMP" ] && rm -rf "$TMP"
}

# ---------------------------------------------------------------------------
# AC4 — Happy path: clean fixture (no frontmatter on any sidecar file)
# emits NO `manual follow-up:` lines and the existing `sidecars PASS`
# line is preserved (regression with e28-s131 AC3 sidecars test).
# ---------------------------------------------------------------------------
@test "E28-S181: AC4 happy path emits no manual follow-up line" {
  [ -x "$SCRIPT" ] || skip "script not yet present"
  run "$SCRIPT" apply --project-root "$TMP" --yes
  [ "$status" -eq 0 ]
  ! [[ "$output" == *"manual follow-up: verify sidecar keys"* ]]
}

@test "E28-S181: AC4 happy path preserves sidecars PASS line" {
  [ -x "$SCRIPT" ] || skip "script not yet present"
  run "$SCRIPT" apply --project-root "$TMP" --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"sidecars PASS"* ]]
}

# ---------------------------------------------------------------------------
# AC1 + AC2 — Drifted sidecar with v1-only frontmatter keys produces
# exactly one `manual follow-up:` line for that file.
# ---------------------------------------------------------------------------
@test "E28-S181: AC2 drifted decision-log emits one follow-up line" {
  [ -x "$SCRIPT" ] || skip "script not yet present"
  cat > "$TMP/_memory/validator-sidecar/decision-log.md" <<'EOF'
---
schema_version: 0.9.0-v1
deprecated_field: ignore-me
---
# Decision Log (v1 schema)
EOF
  run "$SCRIPT" apply --project-root "$TMP" --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"manual follow-up: verify sidecar keys"* ]]
  [[ "$output" == *"decision-log.md"* ]]
  # Exactly one follow-up line for the single drifted file
  local count
  count=$(printf '%s\n' "$output" | grep -c 'manual follow-up: verify sidecar keys' || true)
  [ "$count" -eq 1 ]
}

# ---------------------------------------------------------------------------
# AC2 — Novel v1-only sidecar file (introduces a top-level key not in the
# v2 canonical set) emits one follow-up line.
# ---------------------------------------------------------------------------
@test "E28-S181: AC2 novel v1-only sidecar emits follow-up line" {
  [ -x "$SCRIPT" ] || skip "script not yet present"
  cat > "$TMP/_memory/validator-sidecar/drift-only-v1.md" <<'EOF'
---
top_level_key_v1_only: true
notes:
  - v1-only file
---
# v1-only schema file
EOF
  run "$SCRIPT" apply --project-root "$TMP" --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"drift-only-v1.md"* ]]
  [[ "$output" == *"manual follow-up: verify sidecar keys"* ]]
}

# ---------------------------------------------------------------------------
# AC2 + AC4 — Mixed: some sidecars drift, others are clean. Only the
# drifted files produce follow-up lines; clean files stay silent.
# ---------------------------------------------------------------------------
@test "E28-S181: AC2 mixed drift — only drifted files emit follow-up" {
  [ -x "$SCRIPT" ] || skip "script not yet present"
  # Drift the validator decision-log
  cat > "$TMP/_memory/validator-sidecar/decision-log.md" <<'EOF'
---
schema_version: 0.9.0-v1
---
# Drifted
EOF
  # Leave devops-sidecar clean (no frontmatter)
  run "$SCRIPT" apply --project-root "$TMP" --yes
  [ "$status" -eq 0 ]
  # Exactly one follow-up — for the validator decision-log only
  local count
  count=$(printf '%s\n' "$output" | grep -c 'manual follow-up: verify sidecar keys' || true)
  [ "$count" -eq 1 ]
  [[ "$output" == *"validator-sidecar/decision-log.md"* ]]
}

# ---------------------------------------------------------------------------
# AC3 — AC-EC5 fixture from E28-S170 §5 (drifted decision-log + drift-only
# v1 file) now flags both files automatically — the previously-manual
# verification step is redundant.
# ---------------------------------------------------------------------------
@test "E28-S181: AC3 AC-EC5 fixture flags both drifted files" {
  [ -x "$SCRIPT" ] || skip "script not yet present"
  # Reproduce the §5.1 fixture from the E28-S170 manual test plan
  cat > "$TMP/_memory/validator-sidecar/decision-log.md" <<'EOF'
---
schema_version: 0.9.0-v1
deprecated_field: ignore-me
---
# Decision Log (v1 schema)
EOF
  cat > "$TMP/_memory/validator-sidecar/drift-only-v1.md" <<'EOF'
---
top_level_key_v1_only: true
notes:
  - v1-only file
---
# v1-only schema file
EOF
  run "$SCRIPT" apply --project-root "$TMP" --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"sidecars PASS"* ]]
  # Both drifted files should appear in follow-up output
  [[ "$output" == *"decision-log.md"* ]]
  [[ "$output" == *"drift-only-v1.md"* ]]
  local count
  count=$(printf '%s\n' "$output" | grep -c 'manual follow-up: verify sidecar keys' || true)
  [ "$count" -eq 2 ]
}
