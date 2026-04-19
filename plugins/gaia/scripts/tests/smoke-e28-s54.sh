#!/usr/bin/env bash
# smoke-e28-s54.sh — smoke tests for gaia-validate-story SKILL conversion (E28-S54)
#
# Validates:
#   - SKILL.md directory structure and frontmatter (AC1)
#   - Val subagent invocation block with context: fork (AC1, AC2)
#   - Shared setup.sh / finalize.sh / load-story.sh pattern (AC3)
#   - review-gate.sh integration references (AC4)
#   - Frontmatter linter passes (AC5)
#
# Usage: bash plugins/gaia/scripts/tests/smoke-e28-s54.sh
# Exit 0 when all assertions pass, 1 on first aggregated failure.

set -uo pipefail
LC_ALL=C

REPO_ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
SKILL_DIR="$REPO_ROOT/plugins/gaia/skills/gaia-validate-story"
SKILL_MD="$SKILL_DIR/SKILL.md"
SETUP_SH="$SKILL_DIR/scripts/setup.sh"
FINALIZE_SH="$SKILL_DIR/scripts/finalize.sh"
LINTER="$REPO_ROOT/.github/scripts/lint-skill-frontmatter.sh"

PASS=0
FAIL=0

ok()   { printf "  ok  %s\n" "$1"; PASS=$((PASS + 1)); }
fail() { printf "  FAIL %s\n     %s\n" "$1" "$2"; FAIL=$((FAIL + 1)); }

# -----------------------------------------------------------------------------
echo "== AC1: SKILL.md exists with frontmatter =="
if [ -f "$SKILL_MD" ]; then
  ok "SKILL.md exists"
else
  fail "SKILL.md exists" "missing: $SKILL_MD"
fi

# Extract frontmatter for key checks
if [ -f "$SKILL_MD" ]; then
  fm=$(awk '
    BEGIN { in_fm = 0; seen = 0 }
    /^---[[:space:]]*$/ {
      if (seen == 0) { in_fm = 1; seen = 1; next }
      else if (in_fm == 1) { in_fm = 0; exit }
    }
    in_fm == 1 { print }
  ' "$SKILL_MD")
  for field in name description argument-hint tools; do
    if grep -qE "^${field}:" <<<"$fm"; then
      ok "frontmatter has $field"
    else
      fail "frontmatter has $field" "missing key in frontmatter"
    fi
  done

  # AC1: name must be gaia-validate-story
  if grep -qE '^name:[[:space:]]*gaia-validate-story' <<<"$fm"; then
    ok "name equals gaia-validate-story"
  else
    fail "name equals gaia-validate-story" "name field mismatch"
  fi

  # AC1: argument-hint must be [story-key]
  if grep -qE 'argument-hint:.*\[story-key\]' <<<"$fm"; then
    ok "argument-hint is [story-key]"
  else
    fail "argument-hint is [story-key]" "argument-hint mismatch"
  fi
fi

# -----------------------------------------------------------------------------
echo ""
echo "== AC2: Val subagent invocation with context: fork =="
if [ -f "$SKILL_MD" ]; then
  body=$(awk '
    BEGIN { in_fm = 0; seen = 0; past_fm = 0 }
    /^---[[:space:]]*$/ {
      if (seen == 0) { seen = 1; next }
      else if (!past_fm) { past_fm = 1; next }
    }
    past_fm == 1 { print }
  ' "$SKILL_MD")

  if grep -qi 'val\|validator' <<<"$body"; then
    ok "SKILL.md body references Val/validator subagent"
  else
    fail "SKILL.md body references Val/validator" "no Val reference found in body"
  fi

  if grep -qi 'context.*fork\|fork.*context' <<<"$fm"; then
    ok "frontmatter declares context: fork"
  else
    fail "frontmatter declares context: fork" "no context: fork in frontmatter"
  fi

  if grep -qi 'source_workflow.*gaia-validate-story' <<<"$body"; then
    ok "body passes source_workflow: gaia-validate-story"
  else
    fail "body passes source_workflow" "source_workflow not found in body"
  fi

  if grep -qi 'artifact_path' <<<"$body"; then
    ok "body passes artifact_path to Val"
  else
    fail "body passes artifact_path to Val" "artifact_path not found in body"
  fi
fi

# -----------------------------------------------------------------------------
echo ""
echo "== AC3: Shared setup/finalize/load-story pattern =="
if [ -f "$SETUP_SH" ]; then
  ok "setup.sh exists"
  if grep -q 'resolve-config' "$SETUP_SH"; then
    ok "setup.sh sources resolve-config"
  else
    fail "setup.sh sources resolve-config" "resolve-config not referenced"
  fi
else
  fail "setup.sh exists" "missing: $SETUP_SH"
fi

if [ -f "$FINALIZE_SH" ]; then
  ok "finalize.sh exists"
  if grep -q 'checkpoint' "$FINALIZE_SH"; then
    ok "finalize.sh uses checkpoint"
  else
    fail "finalize.sh uses checkpoint" "checkpoint not referenced"
  fi
  if grep -q 'lifecycle-event' "$FINALIZE_SH"; then
    ok "finalize.sh emits lifecycle event"
  else
    fail "finalize.sh emits lifecycle event" "lifecycle-event not referenced"
  fi
else
  fail "finalize.sh exists" "missing: $FINALIZE_SH"
fi

# Body references setup.sh and finalize.sh
if [ -f "$SKILL_MD" ]; then
  if grep -q 'setup.sh' "$SKILL_MD"; then
    ok "SKILL.md sources setup.sh"
  else
    fail "SKILL.md sources setup.sh" "setup.sh not referenced in SKILL.md"
  fi

  if grep -q 'finalize.sh' "$SKILL_MD"; then
    ok "SKILL.md sources finalize.sh"
  else
    fail "SKILL.md sources finalize.sh" "finalize.sh not referenced in SKILL.md"
  fi

  if grep -qi 'load-story\|story_key\|story.key' "$SKILL_MD"; then
    ok "SKILL.md uses load-story or story_key resolution"
  else
    fail "SKILL.md uses load-story pattern" "no load-story reference found"
  fi
fi

# -----------------------------------------------------------------------------
echo ""
echo "== AC4: review-gate.sh integration =="
if [ -f "$SKILL_MD" ]; then
  if grep -q 'review-gate' "$SKILL_MD"; then
    ok "SKILL.md references review-gate.sh"
  else
    fail "SKILL.md references review-gate.sh" "review-gate not found in SKILL.md"
  fi

  # Check for canonical vocabulary references
  if grep -q 'PASSED\|FAILED\|UNVERIFIED' "$SKILL_MD"; then
    ok "SKILL.md uses canonical verdict vocabulary"
  else
    fail "SKILL.md uses canonical verdict vocabulary" "no PASSED/FAILED/UNVERIFIED found"
  fi
fi

# -----------------------------------------------------------------------------
echo ""
echo "== AC5: Frontmatter linter =="
if [ -x "$LINTER" ] || [ -f "$LINTER" ]; then
  pushd "$REPO_ROOT" >/dev/null
  if bash "$LINTER"; then
    ok "frontmatter linter passes"
  else
    fail "frontmatter linter passes" "linter reported errors"
  fi
  popd >/dev/null
else
  fail "frontmatter linter exists" "missing: $LINTER"
fi

# -----------------------------------------------------------------------------
echo ""
echo "== Summary =="
echo "  $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
