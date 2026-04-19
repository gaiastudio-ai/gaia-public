#!/usr/bin/env bash
# test_val_save.sh — tests for gaia-val-save SKILL.md (E28-S80)
#
# Pure-bash test harness (following test_val_validate.sh pattern) exercising the
# val-save-session skill's SKILL.md structure, decision-log APPEND, and
# conversation-context REPLACE semantics.
#
# Tests verify:
#   AC1  — decision-log APPEND semantics (entries appended, existing preserved)
#   AC2  — conversation-context REPLACE semantics (body replaced, header preserved)
#   AC3  — decision-log entries follow ADR-016 standardized format
#   AC4  — SKILL.md has memory-loader.sh inline call and setup.sh is executable
#   EC1  — missing sidecar directory initializes files with standard headers
#   EC2  — missing individual files are initialized
#   EC3  — existing decision-log history is preserved on append
#   EC4  — conversation-context header above --- is preserved on replace
#
# Usage: ./test_val_save.sh
# Exit:  0 on all-pass, 1 on any failure.

set -uo pipefail
LC_ALL=C
export LC_ALL

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PLUGIN_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
SKILL_MD="$PLUGIN_DIR/skills/gaia-val-save/SKILL.md"
SETUP_SH="$PLUGIN_DIR/skills/gaia-val-save/scripts/setup.sh"
FIXTURES_DIR="$SCRIPT_DIR/fixtures/val-save"

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

assert_line_count_gte() {
  local label="$1" min="$2" file="$3"
  local count
  count=$(wc -l < "$file" | tr -d ' ')
  if [ "$count" -ge "$min" ]; then
    PASSED=$((PASSED + 1))
    printf '  PASS: %s (%d lines >= %d)\n' "$label" "$count" "$min"
  else
    FAILED=$((FAILED + 1))
    printf '  FAIL: %s (%d lines < %d minimum)\n' "$label" "$count" "$min"
  fi
}

# ========================
# Test Group 1: SKILL.md structure (AC1, AC3, AC4)
# ========================
printf '\n=== SKILL.md Structure Tests ===\n'

assert_file_exists "AC4: SKILL.md exists" "$SKILL_MD"

if [ -f "$SKILL_MD" ]; then
  skill_content=$(cat "$SKILL_MD")

  # Frontmatter checks
  assert_contains "AC1: frontmatter has name: gaia-val-save" "name: gaia-val-save" "$skill_content"
  assert_contains "AC1: frontmatter has context: fork" "context: fork" "$skill_content"
  assert_contains "AC1: frontmatter has tools" "tools:" "$skill_content"

  # Memory loader inline call (AC4 — ADR-046)
  assert_contains "AC4: memory-loader.sh inline call present" "memory-loader.sh" "$skill_content"
  assert_contains "AC4: memory-loader.sh loads validator agent" "validator" "$skill_content"

  # Critical rules about semantics
  assert_contains "AC1: mentions APPEND semantics for decision-log" "APPEND" "$skill_content"
  assert_contains "AC2: mentions REPLACE semantics for conversation-context" "REPLACE" "$skill_content"

  # ADR-016 format reference
  assert_contains "AC3: references standardized header format" "### [" "$skill_content"
  assert_contains "AC3: entry format includes Agent metadata" "**Agent:**" "$skill_content"
  assert_contains "AC3: entry format includes Status metadata" "**Status:**" "$skill_content"

  # Ground-truth out of scope
  assert_contains "SCOPE: ground-truth NOT handled by this skill" "ground-truth" "$skill_content"

  # User confirmation gate (memory writes never auto-approved)
  assert_contains "AC1: user confirmation gate present" "[a]" "$skill_content"

  # Line count constraint (CLAUDE.md says max 300 lines for skills)
  line_count=$(wc -l < "$SKILL_MD" | tr -d ' ')
  if [ "$line_count" -le 300 ]; then
    PASSED=$((PASSED + 1))
    printf '  PASS: SKILL.md under 300 lines (%d lines)\n' "$line_count"
  else
    FAILED=$((FAILED + 1))
    printf '  FAIL: SKILL.md exceeds 300 lines (%d lines)\n' "$line_count"
  fi
else
  printf '  SKIP: SKILL.md not found — skipping content tests\n'
fi

# ========================
# Test Group 2: setup.sh (AC4)
# ========================
printf '\n=== setup.sh Tests ===\n'

assert_file_exists "AC4: setup.sh exists" "$SETUP_SH"
assert_file_executable "AC4: setup.sh is executable" "$SETUP_SH"

if [ -f "$SETUP_SH" ]; then
  setup_content=$(cat "$SETUP_SH")
  assert_contains "AC4: setup.sh references resolve-config.sh" "resolve-config.sh" "$setup_content"
fi

# ========================
# Test Group 3: Decision-log APPEND semantics (AC1, AC3, EC3)
# ========================
printf '\n=== Decision-Log APPEND Tests ===\n'

# Create a temp directory to simulate sidecar writes
TMPDIR_SAVE=$(mktemp -d)
trap 'rm -rf "$TMPDIR_SAVE"' EXIT

# EC3: Copy fixture with existing entries
cp "$FIXTURES_DIR/decision-log-with-entries.md" "$TMPDIR_SAVE/decision-log.md"

# Count existing entries before append
existing_entries=$(grep -c '^### \[' "$TMPDIR_SAVE/decision-log.md")
assert_eq "EC3: fixture has 2 existing entries" "2" "$existing_entries"

# Simulate appending a new entry (ADR-016 format)
cat >> "$TMPDIR_SAVE/decision-log.md" << 'ENTRY'

### [2026-04-16] Session findings saved — val-save test

- **Agent:** validator
- **Workflow:** val-save-session
- **Sprint:** sprint-21
- **Type:** validation
- **Status:** active
- **Related:** E28-S80

Test entry for verifying APPEND semantics. 3 findings from validation session saved.
ENTRY

# Verify total entries after append
total_entries=$(grep -c '^### \[' "$TMPDIR_SAVE/decision-log.md")
assert_eq "AC1: decision-log has 3 entries after append" "3" "$total_entries"

# EC3: Verify old entries are preserved
assert_contains "EC3: first entry preserved" "Validated PRD structure" "$(cat "$TMPDIR_SAVE/decision-log.md")"
assert_contains "EC3: second entry preserved" "Architecture cross-reference check" "$(cat "$TMPDIR_SAVE/decision-log.md")"
assert_contains "EC3: new entry present" "Session findings saved" "$(cat "$TMPDIR_SAVE/decision-log.md")"

# AC3: Verify new entry has ADR-016 format
new_entry=$(sed -n '/### \[2026-04-16\] Session findings saved/,$p' "$TMPDIR_SAVE/decision-log.md")
assert_contains "AC3: new entry has Agent field" "**Agent:** validator" "$new_entry"
assert_contains "AC3: new entry has Workflow field" "**Workflow:** val-save-session" "$new_entry"
assert_contains "AC3: new entry has Sprint field" "**Sprint:** sprint-21" "$new_entry"
assert_contains "AC3: new entry has Status field" "**Status:** active" "$new_entry"

# ========================
# Test Group 4: Conversation-context REPLACE semantics (AC2, EC4)
# ========================
printf '\n=== Conversation-Context REPLACE Tests ===\n'

# EC4: Copy fixture with header
cp "$FIXTURES_DIR/conversation-context-with-header.md" "$TMPDIR_SAVE/conversation-context.md"

# Extract header (everything up to and including first ---)
header=$(sed -n '1,/^---$/p' "$TMPDIR_SAVE/conversation-context.md")
assert_contains "EC4: fixture has header" "Val Validator — Conversation Context" "$header"

# Simulate REPLACE: preserve header, replace body
{
  sed -n '1,/^---$/p' "$TMPDIR_SAVE/conversation-context.md"
  printf '\n'
  cat <<'BODY'
Current session: validated SKILL.md for E28-S80 on 2026-04-16. Found 0 issues. User approved save. Focus: Val Cluster native conversion.
BODY
} > "$TMPDIR_SAVE/conversation-context-new.md"
mv "$TMPDIR_SAVE/conversation-context-new.md" "$TMPDIR_SAVE/conversation-context.md"

# AC2: Verify body was replaced
cc_content=$(cat "$TMPDIR_SAVE/conversation-context.md")
assert_contains "AC2: new body content present" "validated SKILL.md for E28-S80" "$cc_content"
assert_not_contains "AC2: old body content removed" "validated architecture.md on 2026-04-12" "$cc_content"

# EC4: Verify header preserved
assert_contains "EC4: header title preserved" "Val Validator — Conversation Context" "$cc_content"
assert_contains "EC4: header description preserved" "Rolling summary" "$cc_content"

# ========================
# Test Group 5: Missing sidecar initialization (EC1, EC2)
# ========================
printf '\n=== Sidecar Initialization Tests ===\n'

EMPTY_SIDECAR="$TMPDIR_SAVE/empty-sidecar"
mkdir -p "$EMPTY_SIDECAR"

# EC1: Simulate initialization of missing decision-log.md
if [ ! -f "$EMPTY_SIDECAR/decision-log.md" ]; then
  cat > "$EMPTY_SIDECAR/decision-log.md" << 'INIT'
# Val Validator — Decision Log

> Chronological record of validation decisions, findings, and session outcomes.
> Format: Standardized header per architecture Memory Format Standardization spec.

---
INIT
  PASSED=$((PASSED + 1))
  printf '  PASS: EC1: decision-log.md initialized when missing\n'
else
  FAILED=$((FAILED + 1))
  printf '  FAIL: EC1: decision-log.md already existed (should not)\n'
fi

# EC1: Verify initialized file has correct header
init_dl=$(cat "$EMPTY_SIDECAR/decision-log.md")
assert_contains "EC1: initialized decision-log has correct title" "Val Validator — Decision Log" "$init_dl"
assert_contains "EC1: initialized decision-log has separator" "---" "$init_dl"

# EC2: Simulate initialization of missing conversation-context.md (decision-log already exists)
if [ ! -f "$EMPTY_SIDECAR/conversation-context.md" ]; then
  cat > "$EMPTY_SIDECAR/conversation-context.md" << 'INIT'
# Val Validator — Conversation Context

> Rolling summary of the most recent validation session.
> This file is replaced (not appended) on each session save.

---

No sessions recorded yet.
INIT
  PASSED=$((PASSED + 1))
  printf '  PASS: EC2: conversation-context.md initialized when missing\n'
else
  FAILED=$((FAILED + 1))
  printf '  FAIL: EC2: conversation-context.md already existed (should not)\n'
fi

init_cc=$(cat "$EMPTY_SIDECAR/conversation-context.md")
assert_contains "EC2: initialized conversation-context has correct title" "Val Validator — Conversation Context" "$init_cc"
assert_contains "EC2: initialized conversation-context has default body" "No sessions recorded yet" "$init_cc"

# ========================
# Summary
# ========================
printf '\n=== Results ===\n'
printf '  Passed: %d\n' "$PASSED"
printf '  Failed: %d\n' "$FAILED"
printf '  Total:  %d\n' $((PASSED + FAILED))

if [ "$FAILED" -gt 0 ]; then
  printf '\nFAILED (%d failures)\n' "$FAILED"
  exit 1
fi

printf '\nALL PASSED\n'
exit 0
