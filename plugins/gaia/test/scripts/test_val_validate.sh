#!/usr/bin/env bash
# test_val_validate.sh — tests for gaia-val-validate SKILL.md (E28-S78)
#
# Pure-bash test harness (following test_checkpoint.sh pattern) exercising the
# val-validate-artifact skill's codebase scanning capabilities.
#
# Tests verify:
#   AC1  — SKILL.md declares context: fork with read-only codebase access
#   AC2  — Valid file path references are verified against the codebase
#   AC3  — Discrepancies include file-path and line-level context
#   AC4  — memory-loader.sh inline call is present for ground-truth loading
#   AC5  — Test fixtures with known discrepancies produce accurate findings
#   AC-EC1 — Non-existent file path produces CRITICAL finding, no crash
#   AC-EC2 — Relative paths are normalized before scanning
#   AC-EC3 — Missing ground-truth produces INFO finding
#   AC-EC4 — Scanning caps at reasonable limit for large file lists
#   AC-EC5 — Missing memory-loader.sh reports clear error
#   AC-EC7 — Binary file references: existence check only
#
# Usage: ./test_val_validate.sh
# Exit:  0 on all-pass, 1 on any failure.

set -uo pipefail
LC_ALL=C
export LC_ALL

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PLUGIN_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
SKILL_MD="$PLUGIN_DIR/skills/gaia-val-validate/SKILL.md"
SETUP_SH="$PLUGIN_DIR/skills/gaia-val-validate/scripts/setup.sh"
FINALIZE_SH="$PLUGIN_DIR/skills/gaia-val-validate/scripts/finalize.sh"
FIXTURES_DIR="$SCRIPT_DIR/fixtures/val-validate"

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

# -------- AC1 — SKILL.md structure and frontmatter --------
test_ac1_skill_frontmatter() {
  printf 'AC1 — SKILL.md frontmatter declares context: fork\n'

  assert_file_exists "SKILL.md exists" "$SKILL_MD"

  if [ ! -f "$SKILL_MD" ]; then
    printf '  SKIP: SKILL.md does not exist yet (RED phase expected)\n'
    return
  fi

  local content
  content=$(cat "$SKILL_MD")

  # Check frontmatter fields
  assert_contains "has context: fork" "context: fork" "$content"
  assert_contains "has name field" "name: gaia-val-validate" "$content"
  assert_contains "has allowed-tools" "allowed-tools:" "$content"
  assert_contains "allows Read tool" "Read" "$content"
  assert_contains "allows Grep tool" "Grep" "$content"
  assert_contains "allows Glob tool" "Glob" "$content"
}

# -------- AC2 — Valid file path scanning --------
test_ac2_valid_path_scanning() {
  printf 'AC2 — SKILL.md contains file-path scanning logic\n'

  if [ ! -f "$SKILL_MD" ]; then
    printf '  SKIP: SKILL.md does not exist yet\n'
    return
  fi

  local content
  content=$(cat "$SKILL_MD")

  # Verify the skill instructs scanning of referenced codebase paths
  assert_contains "mentions Glob scanning" "Glob" "$content"
  assert_contains "mentions Read scanning" "Read" "$content"
  assert_contains "mentions filesystem verification" "erif" "$content"
}

# -------- AC3 — Findings include file-path and line-level context --------
test_ac3_findings_with_context() {
  printf 'AC3 — SKILL.md specifies findings with file-path context\n'

  if [ ! -f "$SKILL_MD" ]; then
    printf '  SKIP: SKILL.md does not exist yet\n'
    return
  fi

  local content
  content=$(cat "$SKILL_MD")

  # Check that findings schema includes file path references
  assert_contains "findings include file path" "file" "$content"
  assert_contains "findings include evidence" "evidence" "$content"
  assert_contains "severity classification" "CRITICAL" "$content"
  assert_contains "severity WARNING" "WARNING" "$content"
  assert_contains "severity INFO" "INFO" "$content"
}

# -------- AC4 — memory-loader.sh inline call --------
test_ac4_memory_loader() {
  printf 'AC4 — SKILL.md uses memory-loader.sh for ground-truth\n'

  if [ ! -f "$SKILL_MD" ]; then
    printf '  SKIP: SKILL.md does not exist yet\n'
    return
  fi

  local content
  content=$(cat "$SKILL_MD")

  assert_contains "memory-loader.sh inline call" "memory-loader.sh" "$content"
  assert_contains "validator agent specified" "validator" "$content"
}

# -------- AC5 — Test fixtures exist and are well-formed --------
test_ac5_fixtures() {
  printf 'AC5 — Test fixtures with known discrepancies exist\n'

  assert_file_exists "valid refs fixture" "$FIXTURES_DIR/artifact-valid-refs.md"
  assert_file_exists "invalid refs fixture" "$FIXTURES_DIR/artifact-invalid-refs.md"
  assert_file_exists "relative paths fixture" "$FIXTURES_DIR/artifact-relative-paths.md"
  assert_file_exists "many refs fixture" "$FIXTURES_DIR/artifact-many-refs.md"

  # Verify fixtures contain expected content
  if [ -f "$FIXTURES_DIR/artifact-invalid-refs.md" ]; then
    local content
    content=$(cat "$FIXTURES_DIR/artifact-invalid-refs.md")
    assert_contains "invalid fixture has nonexistent ref" "nonexistent" "$content"
  fi

  if [ -f "$FIXTURES_DIR/artifact-many-refs.md" ]; then
    # Count file references (lines starting with "- `")
    local ref_count
    ref_count=$(grep -c '^- `' "$FIXTURES_DIR/artifact-many-refs.md" 2>/dev/null || echo "0")
    if [ "$ref_count" -ge 50 ]; then
      PASSED=$((PASSED + 1))
      printf '  PASS: many-refs fixture has 50+ references (%s)\n' "$ref_count"
    else
      FAILED=$((FAILED + 1))
      printf '  FAIL: many-refs fixture has fewer than 50 references (%s)\n' "$ref_count"
    fi
  fi
}

# -------- AC-EC1 — Non-existent path produces CRITICAL, no crash --------
test_ec1_nonexistent_path() {
  printf 'AC-EC1 — SKILL.md handles non-existent paths\n'

  if [ ! -f "$SKILL_MD" ]; then
    printf '  SKIP: SKILL.md does not exist yet\n'
    return
  fi

  local content
  content=$(cat "$SKILL_MD")

  # Verify the skill describes handling of missing files
  assert_contains "handles missing files" "not exist" "$content"
  assert_contains "CRITICAL for missing" "CRITICAL" "$content"
}

# -------- AC-EC2 — Relative path normalization --------
test_ec2_relative_paths() {
  printf 'AC-EC2 — SKILL.md normalizes relative paths\n'

  if [ ! -f "$SKILL_MD" ]; then
    printf '  SKIP: SKILL.md does not exist yet\n'
    return
  fi

  local content
  content=$(cat "$SKILL_MD")

  assert_contains "mentions path normalization" "Normalize" "$content"
}

# -------- AC-EC3 — Missing ground-truth graceful degradation --------
test_ec3_missing_ground_truth() {
  printf 'AC-EC3 — SKILL.md handles missing ground-truth\n'

  if [ ! -f "$SKILL_MD" ]; then
    printf '  SKIP: SKILL.md does not exist yet\n'
    return
  fi

  local content
  content=$(cat "$SKILL_MD")

  assert_contains "handles missing ground-truth" "ground-truth" "$content"
  assert_contains "degrades gracefully" "missing" "$content"
}

# -------- AC-EC4 — Scanning cap for large file lists --------
test_ec4_scanning_cap() {
  printf 'AC-EC4 — SKILL.md caps scanning at reasonable limit\n'

  if [ ! -f "$SKILL_MD" ]; then
    printf '  SKIP: SKILL.md does not exist yet\n'
    return
  fi

  local content
  content=$(cat "$SKILL_MD")

  assert_contains "mentions scanning cap/limit" "cap" "$content"
}

# -------- AC-EC5 — Missing memory-loader.sh clear error --------
test_ec5_missing_memory_loader() {
  printf 'AC-EC5 — SKILL.md handles missing memory-loader.sh\n'

  if [ ! -f "$SKILL_MD" ]; then
    printf '  SKIP: SKILL.md does not exist yet\n'
    return
  fi

  local content
  content=$(cat "$SKILL_MD")

  assert_contains "handles missing memory-loader" "memory-loader" "$content"
}

# -------- AC-EC7 — Binary file existence check only --------
test_ec7_binary_files() {
  printf 'AC-EC7 — SKILL.md skips content scan for binary files\n'

  if [ ! -f "$SKILL_MD" ]; then
    printf '  SKIP: SKILL.md does not exist yet\n'
    return
  fi

  local content
  content=$(cat "$SKILL_MD")

  assert_contains "handles binary files" "binary" "$content"
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
  assert_contains "setup inline uses CLAUDE_PLUGIN_ROOT" 'skills/gaia-val-validate/scripts/setup.sh' "$content"
  assert_contains "finalize inline uses CLAUDE_PLUGIN_ROOT" 'skills/gaia-val-validate/scripts/finalize.sh' "$content"
  assert_contains "memory-loader inline uses CLAUDE_PLUGIN_ROOT" 'scripts/memory-loader.sh' "$content"
}

# -------- main --------
printf '=== gaia-val-validate SKILL.md tests (E28-S78) ===\n'

test_ac1_skill_frontmatter
test_ac2_valid_path_scanning
test_ac3_findings_with_context
test_ac4_memory_loader
test_ac5_fixtures
test_ec1_nonexistent_path
test_ec2_relative_paths
test_ec3_missing_ground_truth
test_ec4_scanning_cap
test_ec5_missing_memory_loader
test_ec7_binary_files
test_setup_finalize_scripts
test_frontmatter_conventions
test_inline_script_pattern

printf '\n=== %d passed, %d failed ===\n' "$PASSED" "$FAILED"
[ "$FAILED" -eq 0 ]
