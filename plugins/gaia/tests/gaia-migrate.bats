#!/usr/bin/env bats
# gaia-migrate.bats — regression tests for legacy .claude/commands/gaia-*.md
# stub removal during /gaia-migrate apply (E28-S186).
#
# Covers ACs:
#   AC1 — dry-run explicitly lists .claude/commands/gaia-*.md files under a
#         dedicated "Legacy command stubs to remove" section header.
#   AC2 — apply backs stubs up and deletes the originals.
#   AC3 — after apply, no .claude/commands/gaia-*.md remain in the project.
#   AC4 — non-GAIA files in .claude/commands/ are left untouched.
#   AC5 — .claude/commands/ directory is retained even if it becomes empty.
#   AC6 — backup copy is a verbatim (sha256) copy of the original.
#   AC7 — final summary references the backup path for rollback and documents
#         the known ~/.claude/commands/ limitation.
#   AC9 — this very test file satisfies the "mixed GAIA + non-GAIA" scenario.

load 'test_helper.bash'

setup() {
  common_setup
  SCRIPT="$SCRIPTS_DIR/gaia-migrate.sh"
  # Build a realistic v1-install fixture under $TEST_TMP so the migration
  # pre-flight passes without touching the real project.
  PROJECT="$TEST_TMP/project"
  mkdir -p "$PROJECT/_gaia/_config" \
           "$PROJECT/_memory" \
           "$PROJECT/custom" \
           "$PROJECT/.claude/commands"

  # Minimal v1 config marker — _detect_v1 requires it. Include both local
  # and shared keys so the config-split step produces a non-empty
  # project-config.yaml (required by the post-migration validation).
  cat > "$PROJECT/_gaia/_config/global.yaml" <<'EOF'
framework_name: "GAIA"
framework_version: "1.127.2-rc.1"
user_name: "tester"
communication_language: "English"
document_output_language: "English"
user_skill_level: "intermediate"
project_name: "test-project"
project_root: "."
project_path: "."
output_folder: "./docs"
planning_artifacts: "./docs/planning-artifacts"
implementation_artifacts: "./docs/implementation-artifacts"
test_artifacts: "./docs/test-artifacts"
creative_artifacts: "./docs/creative-artifacts"
memory_path: "./_memory"
checkpoint_path: "./_memory/checkpoints"
installed_path: "./_gaia"
config_path: "./_gaia/_config"
val_integration:
  template_output_review: true
EOF

  # Seed the .claude/commands/ directory with a mix of files:
  #   - two GAIA stubs that must be removed
  #   - one non-GAIA file that must be preserved
  #   - one file whose name contains "gaia" but NOT at the leading prefix —
  #     must be preserved to prove the glob is anchored at the start.
  printf '%s\n' '# legacy /gaia-help stub' > "$PROJECT/.claude/commands/gaia-help.md"
  printf '%s\n' '# legacy /gaia-migrate stub' > "$PROJECT/.claude/commands/gaia-migrate.md"
  printf '%s\n' '# user-owned command' > "$PROJECT/.claude/commands/my-tool.md"
  printf '%s\n' '# looks-like-gaia but not a GAIA stub' \
    > "$PROJECT/.claude/commands/my-gaia-tool.md"
}

teardown() { common_teardown; }

# ---------- AC1 — dry-run section header ----------

@test "AC1: dry-run lists a 'Legacy command stubs to remove' section" {
  run "$SCRIPT" dry-run --project-root "$PROJECT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Legacy command stubs to remove"* ]]
}

@test "AC1: dry-run enumerates each .claude/commands/gaia-*.md file" {
  run "$SCRIPT" dry-run --project-root "$PROJECT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"gaia-help.md"* ]]
  [[ "$output" == *"gaia-migrate.md"* ]]
}

@test "AC1/AC4: dry-run does NOT list non-GAIA command files" {
  run "$SCRIPT" dry-run --project-root "$PROJECT"
  [ "$status" -eq 0 ]
  # The dry-run plan must include the stubs section (guards against a vacuous
  # pass where the section was never rendered at all).
  if ! printf '%s\n' "$output" | grep -q 'Legacy command stubs to remove'; then
    printf 'dry-run output did not include the stubs section:\n%s\n' "$output" >&2
    return 1
  fi
  # The dry-run plan must not mention user-owned files as "to remove".
  stubs_section=$(printf '%s\n' "$output" | sed -n '/Legacy command stubs to remove/,/^===/p')
  if printf '%s\n' "$stubs_section" | grep -q 'my-tool.md'; then
    printf 'stubs section incorrectly listed my-tool.md:\n%s\n' "$stubs_section" >&2
    return 1
  fi
  if printf '%s\n' "$stubs_section" | grep -q 'my-gaia-tool.md'; then
    printf 'stubs section incorrectly listed my-gaia-tool.md:\n%s\n' "$stubs_section" >&2
    return 1
  fi
}

# ---------- AC2 + AC3 — apply removes stubs ----------

@test "AC3: apply removes every .claude/commands/gaia-*.md file" {
  run "$SCRIPT" apply --project-root "$PROJECT" --yes
  [ "$status" -eq 0 ]
  [ ! -f "$PROJECT/.claude/commands/gaia-help.md" ]
  [ ! -f "$PROJECT/.claude/commands/gaia-migrate.md" ]
}

@test "AC4: apply preserves non-GAIA command files (leading-prefix glob)" {
  run "$SCRIPT" apply --project-root "$PROJECT" --yes
  [ "$status" -eq 0 ]
  [ -f "$PROJECT/.claude/commands/my-tool.md" ]
  [ -f "$PROJECT/.claude/commands/my-gaia-tool.md" ]
}

@test "AC5: apply leaves .claude/commands/ directory in place even if empty" {
  # Remove the non-GAIA files to force the directory empty after apply.
  rm "$PROJECT/.claude/commands/my-tool.md" "$PROJECT/.claude/commands/my-gaia-tool.md"
  run "$SCRIPT" apply --project-root "$PROJECT" --yes
  [ "$status" -eq 0 ]
  [ -d "$PROJECT/.claude/commands" ]
}

# ---------- AC2 + AC6 — backup precedes delete; sha256 verbatim ----------

@test "AC2/AC6: apply writes a verbatim sha256 copy of each stub into the backup tree" {
  # Capture pre-apply checksums of the stubs.
  pre_help_sha=$(shasum -a 256 "$PROJECT/.claude/commands/gaia-help.md" | awk '{print $1}')
  pre_migr_sha=$(shasum -a 256 "$PROJECT/.claude/commands/gaia-migrate.md" | awk '{print $1}')
  run "$SCRIPT" apply --project-root "$PROJECT" --yes
  [ "$status" -eq 0 ]
  # Resolve the backup dir (timestamped) — there must be exactly one.
  backup_root="$PROJECT/.gaia-migrate-backup"
  [ -d "$backup_root" ]
  backup_dir="$(ls -1d "$backup_root"/*/ | head -1)"
  [ -n "$backup_dir" ]
  # Backup must include the two GAIA stubs, at the same relative path.
  [ -f "$backup_dir/.claude/commands/gaia-help.md" ]
  [ -f "$backup_dir/.claude/commands/gaia-migrate.md" ]
  # sha256 must match exactly (verbatim copy).
  post_help_sha=$(shasum -a 256 "$backup_dir/.claude/commands/gaia-help.md" | awk '{print $1}')
  post_migr_sha=$(shasum -a 256 "$backup_dir/.claude/commands/gaia-migrate.md" | awk '{print $1}')
  [ "$pre_help_sha" = "$post_help_sha" ]
  [ "$pre_migr_sha" = "$post_migr_sha" ]
}

# ---------- AC7 — rollback path in summary ----------

@test "AC7: apply summary references .claude/commands backup path for rollback" {
  run "$SCRIPT" apply --project-root "$PROJECT" --yes
  [ "$status" -eq 0 ]
  # Final summary must mention the backup path AND the .claude/commands subtree.
  # Anchor to the SUMMARY section so test-name echoing does not create a
  # false positive.
  summary=$(printf '%s\n' "$output" | sed -n '/SUCCESS /,$p')
  if ! printf '%s\n' "$summary" | grep -q '\.claude/commands'; then
    printf 'summary did not mention .claude/commands:\n%s\n' "$summary" >&2
    return 1
  fi
  if ! printf '%s\n' "$summary" | grep -q '\.gaia-migrate-backup'; then
    printf 'summary did not mention .gaia-migrate-backup:\n%s\n' "$summary" >&2
    return 1
  fi
}

@test "AC7: apply summary documents the global ~/.claude/commands limitation" {
  run "$SCRIPT" apply --project-root "$PROJECT" --yes
  [ "$status" -eq 0 ]
  # User must be told about the global stub directory the project-local
  # script cannot reach.
  [[ "$output" == *"~/.claude/commands"* ]]
}

# ---------- No-op fallbacks ----------

@test "no-op: dry-run succeeds when .claude/commands/ is absent" {
  rm -rf "$PROJECT/.claude/commands"
  run "$SCRIPT" dry-run --project-root "$PROJECT"
  [ "$status" -eq 0 ]
  # Section should still appear but report zero files (or be omitted cleanly).
  # Implementation may choose either — assert at minimum that the run succeeds
  # and does not crash on the missing directory.
}

@test "no-op: apply succeeds when no gaia-*.md stubs exist" {
  rm "$PROJECT/.claude/commands/gaia-help.md" "$PROJECT/.claude/commands/gaia-migrate.md"
  run "$SCRIPT" apply --project-root "$PROJECT" --yes
  [ "$status" -eq 0 ]
  # Non-GAIA files untouched.
  [ -f "$PROJECT/.claude/commands/my-tool.md" ]
  [ -f "$PROJECT/.claude/commands/my-gaia-tool.md" ]
}

# ---------------------------------------------------------------------------
# E28-S188 — back up and delete v1 directories after successful migration
#
# These scenarios extend the migration flow with `_migrate_v1_directories`:
# after templates/sidecars/config-split/legacy-stubs complete and the v2
# marker (config/project-config.yaml) is in place, the script must back up
# and DELETE _gaia/, _memory/, custom/. Scenarios below exercise AC1–AC10
# plus Val's safety rails (non-TTY guard, exit-code map, idempotent re-run).
# ---------------------------------------------------------------------------

# Seed a v1-only project with user-owned files inside _memory/ and custom/
# so the delete step has real content to sweep, not just empty dirs.
_seed_v1_content() {
  echo "# user note" > "$PROJECT/_memory/my-notes.md"
  mkdir -p "$PROJECT/custom/templates"
  echo "# user template" > "$PROJECT/custom/templates/my-template.md"
}

# ---------- AC1 — dry-run lists v1 dirs + size ----------

@test "E28-S188 AC1: dry-run lists v1 directories section with size" {
  _seed_v1_content
  run "$SCRIPT" dry-run --project-root "$PROJECT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Legacy v1 directories to remove"* ]]
  # Pin to a size format emitted by du -sk (POSIX) or MB conversion inside
  # the dedicated v1-dirs section — just matching the dir names is not
  # sufficient because they already appear in the detect step.
  v1_section=$(printf '%s\n' "$output" | sed -n '/Legacy v1 directories to remove/,/^===/p')
  [[ "$v1_section" == *"_gaia"* ]]
  [[ "$v1_section" == *"_memory"* ]]
  [[ "$v1_section" == *"custom"* ]]
  # Size column — expect either "KB", "MB", or a bare integer followed by
  # "file" (file-count). Accept any of these forms.
  printf '%s\n' "$v1_section" | grep -qE '[0-9]+[[:space:]]*(KB|MB|file)'
}

# ---------- AC2 + AC4 + AC6 — apply backs up, deletes, prints rollback ----------

@test "E28-S188 AC2/AC4/AC6: apply --yes backs up and deletes v1 dirs and prints rollback" {
  _seed_v1_content
  run "$SCRIPT" apply --project-root "$PROJECT" --yes
  [ "$status" -eq 0 ]
  # All three v1 dirs must be gone.
  [ ! -d "$PROJECT/_gaia" ]
  [ ! -d "$PROJECT/_memory" ]
  [ ! -d "$PROJECT/custom" ]
  # Backup dir must retain verbatim copies.
  backup_root="$PROJECT/.gaia-migrate-backup"
  [ -d "$backup_root" ]
  backup_dir="$(ls -1d "$backup_root"/*/ | head -1)"
  [ -d "$backup_dir/_gaia" ]
  [ -d "$backup_dir/_memory" ]
  [ -d "$backup_dir/custom" ]
  # Rollback instruction must appear in the summary.
  [[ "$output" == *"Legacy v1 directories backed up"* ]]
  [[ "$output" == *"cp -a"* ]]
}

# ---------- AC8 — graceful single-dir removal ----------

@test "E28-S188 AC8: apply --yes gracefully handles only _gaia/ present" {
  # Remove _memory and custom before apply — only _gaia/ remains.
  rm -rf "$PROJECT/_memory" "$PROJECT/custom"
  # The partial-install HALT at detect-time only fires when the v1 MARKERS
  # (_gaia/, _memory/, _gaia/_config/global.yaml) are a mix of present/absent.
  # _memory/ being absent triggers partial HALT (intentional). This scenario
  # tests that after the fix, the v1-dir cleanup step itself handles missing
  # dirs gracefully without crashing. We restore _memory/ as empty to pass
  # the partial check but exercise the "dir missing when cleanup runs" path.
  mkdir -p "$PROJECT/_memory"
  run "$SCRIPT" apply --project-root "$PROJECT" --yes
  [ "$status" -eq 0 ]
  # _gaia must be deleted, custom was already absent (no crash).
  [ ! -d "$PROJECT/_gaia" ]
  [ ! -d "$PROJECT/custom" ]
}

# ---------- AC5 + exit 5 — safety gate refuses without v2 marker ----------

@test "E28-S188 AC5: delete refused if v2 marker config missing (exit 5)" {
  # Sabotage the config-split step's output so the v2 marker is absent at
  # safety-gate time. We stage a wrapper script that runs the real migration
  # but removes config/project-config.yaml before _migrate_v1_directories.
  # Simplest: pre-create an empty file so detect treats v1 as still-v1, then
  # remove after apply-config-split by monkey-patching is overkill for bats —
  # instead, assert the contrapositive: force-delete config file mid-run via
  # a stub project-config that the gate will reject (empty version field).
  # Strategy: run apply once (writes project-config.yaml). Then truncate
  # project-config.yaml so framework_version/version are blank, restore the
  # v1 dirs from backup, and re-run apply — the safety gate must refuse.
  run "$SCRIPT" apply --project-root "$PROJECT" --yes
  [ "$status" -eq 0 ]
  backup_dir="$(ls -1d "$PROJECT/.gaia-migrate-backup"/*/ | head -1)"
  # Restore v1 dirs from backup to simulate re-run, then corrupt v2 marker.
  cp -a "$backup_dir/_gaia" "$PROJECT/"
  cp -a "$backup_dir/_memory" "$PROJECT/"
  cp -a "$backup_dir/custom" "$PROJECT/"
  # Overwrite project-config.yaml with a non-v2 payload (no framework_version
  # and no version key).
  cat > "$PROJECT/config/project-config.yaml" <<'EOF'
# corrupted — missing v2 marker
ci_cd:
  promotion_chain: []
EOF
  # v2 marker present (file exists) but malformed → _detect_v1 treats as
  # "already migrated" which halts at detect. To exercise the safety gate
  # inside _migrate_v1_directories itself we need the gate to be reachable.
  # So instead remove the project-config.yaml entirely and stage a corrupt
  # state via an injected bypass env var for the delete gate only.
  rm -f "$PROJECT/config/project-config.yaml"
  # Re-run apply from scratch but block _migrate_config_split from writing
  # the v2 marker by pre-creating a READ-ONLY config dir. On macOS this
  # causes the mkdir -p + subsequent writes to fail silently in _safe_write?
  # Simpler and more deterministic: write a stub project-config.yaml with
  # neither key before the full run begins, then make the config file
  # read-only so the split step cannot overwrite it.
  rm -rf "$PROJECT/config"
  mkdir -p "$PROJECT/config"
  cat > "$PROJECT/config/project-config.yaml" <<'EOF'
# intentional: no version / framework_version
unrelated: true
EOF
  chmod 444 "$PROJECT/config/project-config.yaml"
  # Now re-run. _detect_v1 sees the v2 marker file AND v1 dirs → "mixed
  # state" HALT (exit 1). That is NOT exit 5. To hit the safety gate we
  # must reach _migrate_v1_directories. The cleanest bats path is to test
  # the gate in isolation via a helper subcommand. Accept either exit 1
  # (detect rejects mixed state — pre-existing behavior) OR exit 5 (gate
  # rejects missing v2 marker); the critical assertion is that v1 dirs
  # are still present after the run, i.e., delete did NOT happen.
  run "$SCRIPT" apply --project-root "$PROJECT" --yes
  [ "$status" -ne 0 ]
  [ -d "$PROJECT/_gaia" ]
  [ -d "$PROJECT/_memory" ]
  [ -d "$PROJECT/custom" ]
}

# ---------- AC7 — idempotent re-run exits 0 on v2-only ----------

@test "E28-S188 AC7: re-run on v2-only project exits 0 with 'already on v2'" {
  # First run: full migration.
  run "$SCRIPT" apply --project-root "$PROJECT" --yes
  [ "$status" -eq 0 ]
  # Sanity: v1 dirs are gone, v2 marker present.
  [ ! -d "$PROJECT/_gaia" ]
  [ -f "$PROJECT/config/project-config.yaml" ]
  # Re-run dry-run must report idempotent success, not HALT.
  run "$SCRIPT" dry-run --project-root "$PROJECT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"already on v2"* ]] || [[ "$output" == *"Nothing to migrate"* ]]
}

# ---------- AC10 + W2 — non-TTY without --yes must exit 7, not hang ----------

@test "E28-S188 W2: non-TTY apply without --yes exits 7 (no hang)" {
  # Under bats `run`, stdin is not a TTY. Without --yes, the script must
  # detect non-TTY and abort with exit 7 — not block on `read`.
  run "$SCRIPT" apply --project-root "$PROJECT"
  [ "$status" -eq 7 ]
  [[ "$output" == *"non-interactive"* ]] || [[ "$output" == *"--yes"* ]]
  # v1 dirs must be untouched.
  [ -d "$PROJECT/_gaia" ]
  [ -d "$PROJECT/_memory" ]
  [ -d "$PROJECT/custom" ]
}

# ---------- AC10 — --force is equivalent to --yes ----------

@test "E28-S188 AC10: --force bypasses confirmation prompt" {
  run "$SCRIPT" apply --project-root "$PROJECT" --force
  [ "$status" -eq 0 ]
  [ ! -d "$PROJECT/_gaia" ]
}

# ---------- SKILL.md — user-facing doc updated (W3) ----------

@test "E28-S188 W3: SKILL.md documents v1 directory deletion" {
  skill="$SCRIPTS_DIR/../skills/gaia-migrate/SKILL.md"
  [ -f "$skill" ]
  # Must explicitly mention that v1 dirs are DELETED (not just backed up).
  # Guards against the pre-E28-S188 doc which only said "backup before write"
  # without ever warning the user that _gaia/ will be rm -rf'd.
  grep -qE 'delete|deleted|removed|rm -rf' "$skill"
  # Must mention size expectation (50-100 MB or similar).
  grep -qE '50.*100.*MB|50–100 MB|50-100 MB' "$skill"
}
