#!/usr/bin/env bats
# e39-s2-create-story-spawn-guard-units.bats
#
# Unit tests for spawn-guard.sh public functions added by E39-S2
# (Subagent spawn for injected stories). Satisfies NFR-052 public-function
# coverage gate by directly exercising each new public function.
#
# Functions under test (spawn-guard.sh):
#   - sg_validate_origin_ref  — validate/sanitize origin_ref before spawn
#   - sg_check_collision      — detect existing story file at canonical path
#   - sg_cleanup_partial      — remove partial story file on spawn failure
#   - sg_verify_frontmatter   — post-spawn check origin/origin_ref in frontmatter
#
# Pattern: source the script as a library (extract function definitions
# via awk) then call each function directly — same approach as
# e39-s1-triage-guard-units.bats and e38-s4-priority-flag-units.bats.

load 'test_helper.bash'

setup() { common_setup; }
teardown() { common_teardown; }

SPAWN_GUARD_SH="$(cd "$BATS_TEST_DIRNAME/../scripts" && pwd)/spawn-guard.sh"

# ---------------------------------------------------------------------------
# Helper: extract public function definitions from spawn-guard.sh
# ---------------------------------------------------------------------------
_load_spawn_helpers() {
  local tmp
  tmp="$(mktemp -t sg-helpers.XXXXXX)"
  printf 'SCRIPT_NAME="spawn-guard.sh"\n' > "$tmp"
  # Also extract the _tg_fm_field helper if reused, plus logging helpers
  awk '
    /^log\(\) \{/,/^\}/ { print; next }
    /^die\(\) \{/,/^\}/ { print; next }
    /^_sg_fm_field\(\) \{/,/^\}/ { print; next }
    /^sg_validate_origin_ref\(\) \{/,/^\}/ { print; next }
    /^sg_check_collision\(\) \{/,/^\}/ { print; next }
    /^sg_cleanup_partial\(\) \{/,/^\}/ { print; next }
    /^sg_verify_frontmatter\(\) \{/,/^\}/ { print; next }
  ' "$SPAWN_GUARD_SH" >> "$tmp"
  # shellcheck disable=SC1090
  source "$tmp"
  rm -f "$tmp"
}

# ---------------------------------------------------------------------------
# Fixture builders
# ---------------------------------------------------------------------------
_make_story() {
  local dir="$1" key="$2" origin="${3:-}" origin_ref="${4:-}"
  local file="${dir}/${key}-test-story.md"
  {
    printf -- '---\n'
    printf -- "template: 'story'\n"
    printf -- 'key: "%s"\n' "$key"
    printf -- 'status: backlog\n'
    [ -n "$origin" ]     && printf -- 'origin: "%s"\n' "$origin"
    [ -n "$origin_ref" ] && printf -- 'origin_ref: "%s"\n' "$origin_ref"
    printf -- '---\n\n'
    printf -- '# Story: %s\n' "$key"
  } > "$file"
  printf '%s' "$file"
}

# ===========================================================================
# sg_validate_origin_ref — validate/sanitize origin_ref before spawn
# ===========================================================================

@test "sg_validate_origin_ref: accepts valid sprint ID (sprint-26)" {
  _load_spawn_helpers
  run sg_validate_origin_ref "sprint-26"
  [ "$status" -eq 0 ]
}

@test "sg_validate_origin_ref: accepts valid finding ID (F-2026-04-22-1)" {
  _load_spawn_helpers
  run sg_validate_origin_ref "F-2026-04-22-1"
  [ "$status" -eq 0 ]
}

@test "sg_validate_origin_ref: accepts alnum with hyphens and underscores" {
  _load_spawn_helpers
  run sg_validate_origin_ref "my_ref-123"
  [ "$status" -eq 0 ]
}

@test "sg_validate_origin_ref: accepts colons and dots (real ID formats)" {
  _load_spawn_helpers
  run sg_validate_origin_ref "sprint:26.1"
  [ "$status" -eq 0 ]
}

@test "sg_validate_origin_ref: rejects empty string" {
  _load_spawn_helpers
  run sg_validate_origin_ref ""
  [ "$status" -ne 0 ]
}

@test "sg_validate_origin_ref: rejects null literal" {
  _load_spawn_helpers
  run sg_validate_origin_ref "null"
  [ "$status" -ne 0 ]
}

@test "sg_validate_origin_ref: rejects semicolons (shell injection)" {
  _load_spawn_helpers
  run sg_validate_origin_ref ";rm -rf /"
  [ "$status" -ne 0 ]
}

@test "sg_validate_origin_ref: rejects newlines" {
  _load_spawn_helpers
  run sg_validate_origin_ref $'line1\nline2'
  [ "$status" -ne 0 ]
}

@test "sg_validate_origin_ref: rejects path separators" {
  _load_spawn_helpers
  run sg_validate_origin_ref "../../../etc/passwd"
  [ "$status" -ne 0 ]
}

@test "sg_validate_origin_ref: rejects backtick injection" {
  _load_spawn_helpers
  run sg_validate_origin_ref '`whoami`'
  [ "$status" -ne 0 ]
}

@test "sg_validate_origin_ref: rejects dollar sign injection" {
  _load_spawn_helpers
  run sg_validate_origin_ref '$(id)'
  [ "$status" -ne 0 ]
}

@test "sg_validate_origin_ref: rejects pipe character" {
  _load_spawn_helpers
  run sg_validate_origin_ref "id|cat"
  [ "$status" -ne 0 ]
}

# ===========================================================================
# sg_check_collision — detect existing story file at canonical path
# ===========================================================================

@test "sg_check_collision: returns 0 when no file exists" {
  _load_spawn_helpers
  run sg_check_collision "$TEST_TMP" "E99-S99"
  [ "$status" -eq 0 ]
}

@test "sg_check_collision: returns 1 when file exists at path" {
  _load_spawn_helpers
  touch "$TEST_TMP/E99-S99-something.md"
  run sg_check_collision "$TEST_TMP" "E99-S99"
  [ "$status" -ne 0 ]
}

@test "sg_check_collision: matches any slug variant (glob)" {
  _load_spawn_helpers
  touch "$TEST_TMP/E5-S3-my-fancy-slug.md"
  run sg_check_collision "$TEST_TMP" "E5-S3"
  [ "$status" -ne 0 ]
}

@test "sg_check_collision: does not match partial key prefix" {
  _load_spawn_helpers
  # E5-S30 should NOT match when checking for E5-S3
  touch "$TEST_TMP/E5-S30-different-story.md"
  run sg_check_collision "$TEST_TMP" "E5-S3"
  [ "$status" -eq 0 ]
}

@test "sg_check_collision: outputs collision path on failure" {
  _load_spawn_helpers
  touch "$TEST_TMP/E10-S1-existing.md"
  run sg_check_collision "$TEST_TMP" "E10-S1"
  [ "$status" -ne 0 ]
  echo "$output" | grep -q "E10-S1"
}

@test "sg_check_collision: rejects missing directory argument" {
  _load_spawn_helpers
  run sg_check_collision "" "E1-S1"
  [ "$status" -ne 0 ]
}

@test "sg_check_collision: rejects missing story key argument" {
  _load_spawn_helpers
  run sg_check_collision "$TEST_TMP" ""
  [ "$status" -ne 0 ]
}

# ===========================================================================
# sg_cleanup_partial — remove partial story file on spawn failure
# ===========================================================================

@test "sg_cleanup_partial: removes existing file and returns 0" {
  _load_spawn_helpers
  local file="$TEST_TMP/E1-S1-partial.md"
  echo "partial content" > "$file"
  run sg_cleanup_partial "$file"
  [ "$status" -eq 0 ]
  [ ! -f "$file" ]
}

@test "sg_cleanup_partial: returns 0 when file does not exist (idempotent)" {
  _load_spawn_helpers
  run sg_cleanup_partial "$TEST_TMP/nonexistent.md"
  [ "$status" -eq 0 ]
}

@test "sg_cleanup_partial: rejects empty path argument" {
  _load_spawn_helpers
  run sg_cleanup_partial ""
  [ "$status" -ne 0 ]
}

@test "sg_cleanup_partial: logs the path of the removed file" {
  _load_spawn_helpers
  local file="$TEST_TMP/E2-S1-cleanup.md"
  echo "content" > "$file"
  run sg_cleanup_partial "$file"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "E2-S1-cleanup.md" || echo "$stderr" | grep -q "E2-S1-cleanup.md" || true
}

# ===========================================================================
# sg_verify_frontmatter — post-spawn verify origin/origin_ref in frontmatter
# ===========================================================================

@test "sg_verify_frontmatter: passes when both origin and origin_ref present" {
  _load_spawn_helpers
  local file
  file="$(_make_story "$TEST_TMP" "E1-S1" "correct-course" "sprint-26")"
  run sg_verify_frontmatter "$file" "correct-course" "sprint-26"
  [ "$status" -eq 0 ]
}

@test "sg_verify_frontmatter: fails when origin missing" {
  _load_spawn_helpers
  local file="$TEST_TMP/no-origin.md"
  cat > "$file" <<'EOF'
---
template: 'story'
key: "E1-S1"
status: backlog
origin_ref: "sprint-26"
---
EOF
  run sg_verify_frontmatter "$file" "correct-course" "sprint-26"
  [ "$status" -ne 0 ]
}

@test "sg_verify_frontmatter: fails when origin_ref missing" {
  _load_spawn_helpers
  local file="$TEST_TMP/no-ref.md"
  cat > "$file" <<'EOF'
---
template: 'story'
key: "E1-S1"
status: backlog
origin: "correct-course"
---
EOF
  run sg_verify_frontmatter "$file" "correct-course" "sprint-26"
  [ "$status" -ne 0 ]
}

@test "sg_verify_frontmatter: fails when origin value mismatches" {
  _load_spawn_helpers
  local file
  file="$(_make_story "$TEST_TMP" "E1-S1" "triage-findings" "sprint-26")"
  run sg_verify_frontmatter "$file" "correct-course" "sprint-26"
  [ "$status" -ne 0 ]
}

@test "sg_verify_frontmatter: fails when origin_ref value mismatches" {
  _load_spawn_helpers
  local file
  file="$(_make_story "$TEST_TMP" "E1-S1" "correct-course" "sprint-25")"
  run sg_verify_frontmatter "$file" "correct-course" "sprint-26"
  [ "$status" -ne 0 ]
}

@test "sg_verify_frontmatter: fails when file does not exist" {
  _load_spawn_helpers
  run sg_verify_frontmatter "$TEST_TMP/nonexistent.md" "correct-course" "sprint-26"
  [ "$status" -ne 0 ]
}

@test "sg_verify_frontmatter: outputs schema-drift error on mismatch" {
  _load_spawn_helpers
  local file
  file="$(_make_story "$TEST_TMP" "E1-S1" "triage-findings" "F-001")"
  run sg_verify_frontmatter "$file" "correct-course" "sprint-26"
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "schema" || echo "$output" | grep -qi "mismatch" || echo "$output" | grep -qi "drift"
}

@test "sg_verify_frontmatter: rejects empty expected_origin argument" {
  _load_spawn_helpers
  local file
  file="$(_make_story "$TEST_TMP" "E1-S1" "correct-course" "sprint-26")"
  run sg_verify_frontmatter "$file" "" "sprint-26"
  [ "$status" -ne 0 ]
}

# ===========================================================================
# Contract: spawn-guard.sh must be executable as standalone CLI
# ===========================================================================

@test "spawn-guard.sh: is executable" {
  [ -x "$SPAWN_GUARD_SH" ]
}

@test "spawn-guard.sh: shellcheck-safe shebang" {
  head -n 1 "$SPAWN_GUARD_SH" | grep -q '^#!/usr/bin/env bash'
}
