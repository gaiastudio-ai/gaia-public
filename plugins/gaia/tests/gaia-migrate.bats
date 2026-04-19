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
  run "$SCRIPT" apply --project-root "$PROJECT"
  [ "$status" -eq 0 ]
  [ ! -f "$PROJECT/.claude/commands/gaia-help.md" ]
  [ ! -f "$PROJECT/.claude/commands/gaia-migrate.md" ]
}

@test "AC4: apply preserves non-GAIA command files (leading-prefix glob)" {
  run "$SCRIPT" apply --project-root "$PROJECT"
  [ "$status" -eq 0 ]
  [ -f "$PROJECT/.claude/commands/my-tool.md" ]
  [ -f "$PROJECT/.claude/commands/my-gaia-tool.md" ]
}

@test "AC5: apply leaves .claude/commands/ directory in place even if empty" {
  # Remove the non-GAIA files to force the directory empty after apply.
  rm "$PROJECT/.claude/commands/my-tool.md" "$PROJECT/.claude/commands/my-gaia-tool.md"
  run "$SCRIPT" apply --project-root "$PROJECT"
  [ "$status" -eq 0 ]
  [ -d "$PROJECT/.claude/commands" ]
}

# ---------- AC2 + AC6 — backup precedes delete; sha256 verbatim ----------

@test "AC2/AC6: apply writes a verbatim sha256 copy of each stub into the backup tree" {
  # Capture pre-apply checksums of the stubs.
  pre_help_sha=$(shasum -a 256 "$PROJECT/.claude/commands/gaia-help.md" | awk '{print $1}')
  pre_migr_sha=$(shasum -a 256 "$PROJECT/.claude/commands/gaia-migrate.md" | awk '{print $1}')
  run "$SCRIPT" apply --project-root "$PROJECT"
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
  run "$SCRIPT" apply --project-root "$PROJECT"
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
  run "$SCRIPT" apply --project-root "$PROJECT"
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
  run "$SCRIPT" apply --project-root "$PROJECT"
  [ "$status" -eq 0 ]
  # Non-GAIA files untouched.
  [ -f "$PROJECT/.claude/commands/my-tool.md" ]
  [ -f "$PROJECT/.claude/commands/my-gaia-tool.md" ]
}
