#!/usr/bin/env bash
# test_refresh_ground_truth.sh — tests for gaia-refresh-ground-truth SKILL.md (E28-S79)
#
# Pure-bash test harness (following test_val_validate.sh pattern) exercising the
# refresh-ground-truth skill's filesystem rescan capabilities.
#
# Tests verify:
#   AC1  — SKILL.md triggers filesystem rescan using Glob/Read tools
#   AC2  — Ground-truth output matches memory-loader.sh format (ADR-046)
#   AC3  — Diff report generated showing changes since last scan
#   AC4  — Shared setup.sh/finalize.sh scripts are applied
#   AC5  — Test fixtures produce valid ground-truth after rescan
#   AC-EC1 — First scan (no prior ground-truth) creates file from scratch
#   AC-EC2 — Empty project produces minimal ground-truth
#   AC-EC3 — Write failure reports clear error message
#   AC-EC4 — No-changes scenario explicitly states no changes
#   AC-EC5 — Legacy format overwritten with current schema
#   AC-EC6 — Large project scan applies depth limits
#   AC-EC7 — Missing validator-sidecar directory created
#   AC-EC8 — Missing shared scripts handled gracefully
#
# Usage: ./test_refresh_ground_truth.sh
# Exit:  0 on all-pass, 1 on any failure.

set -uo pipefail
LC_ALL=C
export LC_ALL

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PLUGIN_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
SKILL_MD="$PLUGIN_DIR/skills/gaia-refresh-ground-truth/SKILL.md"
SETUP_SH="$PLUGIN_DIR/skills/gaia-refresh-ground-truth/scripts/setup.sh"
FINALIZE_SH="$PLUGIN_DIR/skills/gaia-refresh-ground-truth/scripts/finalize.sh"
FIXTURES_DIR="$SCRIPT_DIR/fixtures/refresh-ground-truth"

FAILED=0
PASSED=0

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    PASSED=$((PASSED + 1))
    printf '  PASS: %s\n' "$label"
  else
    FAILED=$((FAILED + 1))
    printf '  FAIL: %s\n    expected: %q\n    actual:   %q\n' "$label" "$expected" "$actual"
  fi
}

assert_contains() {
  local label="$1" needle="$2" haystack="$3"
  case "$haystack" in
    *"$needle"*)
      PASSED=$((PASSED + 1))
      printf '  PASS: %s\n' "$label" ;;
    *)
      FAILED=$((FAILED + 1))
      printf '  FAIL: %s\n    missing: %q\n    in:\n%s\n' "$label" "$needle" "$haystack" ;;
  esac
}

assert_not_contains() {
  local label="$1" needle="$2" haystack="$3"
  case "$haystack" in
    *"$needle"*)
      FAILED=$((FAILED + 1))
      printf '  FAIL: %s\n    should NOT contain: %q\n' "$label" "$needle" ;;
    *)
      PASSED=$((PASSED + 1))
      printf '  PASS: %s\n' "$label" ;;
  esac
}

assert_file_exists() {
  local label="$1" path="$2"
  if [ -f "$path" ]; then
    PASSED=$((PASSED + 1))
    printf '  PASS: %s\n' "$label"
  else
    FAILED=$((FAILED + 1))
    printf '  FAIL: %s (missing file %s)\n' "$label" "$path"
  fi
}

assert_file_executable() {
  local label="$1" path="$2"
  if [ -x "$path" ]; then
    PASSED=$((PASSED + 1))
    printf '  PASS: %s\n' "$label"
  else
    FAILED=$((FAILED + 1))
    printf '  FAIL: %s (not executable %s)\n' "$label" "$path"
  fi
}

# -------- AC1 — SKILL.md triggers filesystem rescan using Glob/Read --------
test_ac1_filesystem_rescan() {
  printf 'AC1 — SKILL.md triggers filesystem rescan using Glob/Read\n'

  assert_file_exists "SKILL.md exists" "$SKILL_MD"

  if [ ! -f "$SKILL_MD" ]; then
    printf '  SKIP: SKILL.md does not exist yet (RED phase expected)\n'
    return
  fi

  local content
  content=$(cat "$SKILL_MD")

  # Verify the skill instructs filesystem scanning via Glob/Read
  assert_contains "mentions Glob for scanning" "Glob" "$content"
  assert_contains "mentions Read for metadata" "Read" "$content"
  assert_contains "mentions filesystem rescan" "rescan" "$content"
  assert_contains "mentions project structure discovery" "structure" "$content"
}

# -------- AC2 — Ground-truth format matches memory-loader.sh expectations --------
test_ac2_ground_truth_format() {
  printf 'AC2 — Ground-truth output format matches memory-loader.sh\n'

  if [ ! -f "$SKILL_MD" ]; then
    printf '  SKIP: SKILL.md does not exist yet\n'
    return
  fi

  local content
  content=$(cat "$SKILL_MD")

  # Verify format references
  assert_contains "mentions ground-truth.md" "ground-truth.md" "$content"
  assert_contains "mentions memory-loader.sh format" "memory-loader" "$content"
  assert_contains "mentions validator-sidecar" "validator-sidecar" "$content"
  assert_contains "mentions last-refresh timestamp" "last-refresh" "$content"
  assert_contains "mentions entry-count" "entry-count" "$content"
}

# -------- AC3 — Diff report showing changes --------
test_ac3_diff_report() {
  printf 'AC3 — SKILL.md generates diff report\n'

  if [ ! -f "$SKILL_MD" ]; then
    printf '  SKIP: SKILL.md does not exist yet\n'
    return
  fi

  local content
  content=$(cat "$SKILL_MD")

  assert_contains "mentions diff comparison" "diff" "$content"
  assert_contains "mentions additions" "added" "$content"
  assert_contains "mentions removals" "removed" "$content"
  assert_contains "mentions changes" "change" "$content"
}

# -------- AC4 — Shared setup.sh/finalize.sh pattern --------
test_ac4_shared_scripts() {
  printf 'AC4 — SKILL.md uses shared setup.sh/finalize.sh\n'

  if [ ! -f "$SKILL_MD" ]; then
    printf '  SKIP: SKILL.md does not exist yet\n'
    return
  fi

  local content
  content=$(cat "$SKILL_MD")

  assert_contains "has Setup section" "## Setup" "$content"
  assert_contains "setup calls inline script" '!${CLAUDE_PLUGIN_ROOT}' "$content"
  assert_contains "has Finalize section" "## Finalize" "$content"
  assert_contains "setup path correct" "skills/gaia-refresh-ground-truth/scripts/setup.sh" "$content"
  assert_contains "finalize path correct" "skills/gaia-refresh-ground-truth/scripts/finalize.sh" "$content"
}

# -------- AC5 — Test fixtures exist --------
test_ac5_fixtures() {
  printf 'AC5 — Test fixtures for ground-truth rescan exist\n'

  assert_file_exists "existing ground-truth fixture" "$FIXTURES_DIR/existing-ground-truth.md"
  assert_file_exists "empty project fixture dir" "$FIXTURES_DIR/empty-project/.gitkeep"

  # Verify fixture contains expected format
  if [ -f "$FIXTURES_DIR/existing-ground-truth.md" ]; then
    local content
    content=$(cat "$FIXTURES_DIR/existing-ground-truth.md")
    assert_contains "fixture has last-refresh" "last-refresh" "$content"
    assert_contains "fixture has entry-count" "entry-count" "$content"
    assert_contains "fixture has file-inventory section" "[file-inventory]" "$content"
  fi
}

# -------- AC-EC1 — First scan creates ground-truth from scratch --------
test_ec1_first_scan() {
  printf 'AC-EC1 — SKILL.md handles first scan (no prior ground-truth)\n'

  if [ ! -f "$SKILL_MD" ]; then
    printf '  SKIP: SKILL.md does not exist yet\n'
    return
  fi

  local content
  content=$(cat "$SKILL_MD")

  assert_contains "handles first scan" "initial scan" "$content"
  assert_contains "handles no prior ground-truth" "no prior" "$content"
}

# -------- AC-EC2 — Empty project minimal ground-truth --------
test_ec2_empty_project() {
  printf 'AC-EC2 — SKILL.md handles empty project\n'

  if [ ! -f "$SKILL_MD" ]; then
    printf '  SKIP: SKILL.md does not exist yet\n'
    return
  fi

  local content
  content=$(cat "$SKILL_MD")

  assert_contains "handles empty project" "empty" "$content"
}

# -------- AC-EC3 — Write failure reports clear error --------
test_ec3_write_failure() {
  printf 'AC-EC3 — SKILL.md reports write failures\n'

  if [ ! -f "$SKILL_MD" ]; then
    printf '  SKIP: SKILL.md does not exist yet\n'
    return
  fi

  local content
  content=$(cat "$SKILL_MD")

  assert_contains "handles write failure" "write" "$content"
  assert_contains "reports error clearly" "error" "$content"
}

# -------- AC-EC4 — No changes detected scenario --------
test_ec4_no_changes() {
  printf 'AC-EC4 — SKILL.md handles no-changes scenario\n'

  if [ ! -f "$SKILL_MD" ]; then
    printf '  SKIP: SKILL.md does not exist yet\n'
    return
  fi

  local content
  content=$(cat "$SKILL_MD")

  assert_contains "handles no changes" "No changes" "$content"
}

# -------- AC-EC5 — Legacy format overwritten --------
test_ec5_legacy_format() {
  printf 'AC-EC5 — SKILL.md overwrites legacy format\n'

  if [ ! -f "$SKILL_MD" ]; then
    printf '  SKIP: SKILL.md does not exist yet\n'
    return
  fi

  local content
  content=$(cat "$SKILL_MD")

  assert_contains "handles legacy format" "format" "$content"
  assert_contains "overwrites with current schema" "overwrite" "$content"
}

# -------- AC-EC6 — Large project scan depth limits --------
test_ec6_depth_limits() {
  printf 'AC-EC6 — SKILL.md applies scan depth limits\n'

  if [ ! -f "$SKILL_MD" ]; then
    printf '  SKIP: SKILL.md does not exist yet\n'
    return
  fi

  local content
  content=$(cat "$SKILL_MD")

  assert_contains "mentions depth or scan limits" "limit" "$content"
}

# -------- AC-EC7 — Missing validator-sidecar directory created --------
test_ec7_missing_sidecar_dir() {
  printf 'AC-EC7 — SKILL.md creates missing sidecar directory\n'

  if [ ! -f "$SKILL_MD" ]; then
    printf '  SKIP: SKILL.md does not exist yet\n'
    return
  fi

  local content
  content=$(cat "$SKILL_MD")

  assert_contains "creates missing sidecar directory" "Create" "$content"
  assert_contains "handles missing directory" "not exist" "$content"
}

# -------- AC-EC8 — Missing shared scripts handled gracefully --------
test_ec8_missing_scripts() {
  printf 'AC-EC8 — SKILL.md handles missing shared scripts\n'

  if [ ! -f "$SKILL_MD" ]; then
    printf '  SKIP: SKILL.md does not exist yet\n'
    return
  fi

  local content
  content=$(cat "$SKILL_MD")

  assert_contains "handles missing setup.sh" "setup" "$content"
  assert_contains "handles missing scripts gracefully" "fail" "$content"
}

# -------- Setup/Finalize scripts --------
test_setup_finalize_scripts() {
  printf 'Scripts — setup.sh and finalize.sh exist and are executable\n'

  assert_file_exists "setup.sh exists" "$SETUP_SH"
  assert_file_exists "finalize.sh exists" "$FINALIZE_SH"

  if [ -f "$SETUP_SH" ]; then
    assert_file_executable "setup.sh is executable" "$SETUP_SH"
    local content
    content=$(cat "$SETUP_SH")
    assert_contains "setup uses resolve-config" "resolve-config" "$content"
    assert_contains "setup uses validate-gate" "validate-gate" "$content"
    assert_contains "setup uses checkpoint" "checkpoint" "$content"
  fi

  if [ -f "$FINALIZE_SH" ]; then
    assert_file_executable "finalize.sh is executable" "$FINALIZE_SH"
    local content
    content=$(cat "$FINALIZE_SH")
    assert_contains "finalize uses checkpoint" "checkpoint" "$content"
    assert_contains "finalize uses lifecycle-event" "lifecycle-event" "$content"
  fi
}

# -------- E28-S17 frontmatter conventions --------
test_frontmatter_conventions() {
  printf 'E28-S17 — Frontmatter follows SKILL.md conventions\n'

  if [ ! -f "$SKILL_MD" ]; then
    printf '  SKIP: SKILL.md does not exist yet\n'
    return
  fi

  local content
  content=$(cat "$SKILL_MD")

  # Check for required frontmatter delimiters
  local frontmatter_count
  frontmatter_count=$(grep -c '^---$' "$SKILL_MD" 2>/dev/null || echo "0")
  if [ "$frontmatter_count" -ge 2 ]; then
    PASSED=$((PASSED + 1))
    printf '  PASS: frontmatter delimiters present\n'
  else
    FAILED=$((FAILED + 1))
    printf '  FAIL: frontmatter needs at least 2 --- delimiters (found %s)\n' "$frontmatter_count"
  fi

  # Check for required frontmatter fields
  assert_contains "has name field" "name: gaia-refresh-ground-truth" "$content"
  assert_contains "has description field" "description:" "$content"
  assert_contains "has tools" "tools:" "$content"
  assert_contains "allows Read tool" "Read" "$content"
  assert_contains "allows Grep tool" "Grep" "$content"
  assert_contains "allows Glob tool" "Glob" "$content"
  assert_contains "allows Bash tool" "Bash" "$content"

  # Check for Setup section with inline script
  assert_contains "has Setup section" "## Setup" "$content"
  assert_contains "setup calls inline script" '!${CLAUDE_PLUGIN_ROOT}' "$content"

  # Check for Memory section
  assert_contains "has Memory section" "## Memory" "$content"

  # Check for Finalize section
  assert_contains "has Finalize section" "## Finalize" "$content"
}

# -------- E28-S19 inline script pattern --------
test_inline_script_pattern() {
  printf 'E28-S19 — Inline script invocation follows convention\n'

  if [ ! -f "$SKILL_MD" ]; then
    printf '  SKIP: SKILL.md does not exist yet\n'
    return
  fi

  local content
  content=$(cat "$SKILL_MD")

  # Inline scripts use !${CLAUDE_PLUGIN_ROOT}/... pattern
  assert_contains "setup inline uses CLAUDE_PLUGIN_ROOT" 'skills/gaia-refresh-ground-truth/scripts/setup.sh' "$content"
  assert_contains "finalize inline uses CLAUDE_PLUGIN_ROOT" 'skills/gaia-refresh-ground-truth/scripts/finalize.sh' "$content"
  assert_contains "memory-loader inline uses CLAUDE_PLUGIN_ROOT" 'scripts/memory-loader.sh' "$content"
}

# -------- main --------
printf '=== gaia-refresh-ground-truth SKILL.md tests (E28-S79) ===\n'

test_ac1_filesystem_rescan
test_ac2_ground_truth_format
test_ac3_diff_report
test_ac4_shared_scripts
test_ac5_fixtures
test_ec1_first_scan
test_ec2_empty_project
test_ec3_write_failure
test_ec4_no_changes
test_ec5_legacy_format
test_ec6_depth_limits
test_ec7_missing_sidecar_dir
test_ec8_missing_scripts
test_setup_finalize_scripts
test_frontmatter_conventions
test_inline_script_pattern

printf '\n=== %d passed, %d failed ===\n' "$PASSED" "$FAILED"
[ "$FAILED" -eq 0 ]
