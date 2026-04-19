#!/usr/bin/env bash
# smoke-e28-s55.sh — smoke tests for gaia-fix-story SKILL conversion (E28-S55)
#
# Validates:
#   - SKILL.md directory structure and frontmatter (AC1)
#   - Findings-apply + re-validate loop instructions (AC2)
#   - Shared setup.sh / finalize.sh / load-story.sh pattern (AC3)
#   - Frontmatter linter passes (AC4)
#
# Usage: bash plugins/gaia/scripts/tests/smoke-e28-s55.sh
# Exit 0 when all assertions pass, 1 on first aggregated failure.

set -uo pipefail
LC_ALL=C

REPO_ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
SKILL_DIR="$REPO_ROOT/plugins/gaia/skills/gaia-fix-story"
SKILL_MD="$SKILL_DIR/SKILL.md"
SETUP_SH="$SKILL_DIR/scripts/setup.sh"
FINALIZE_SH="$SKILL_DIR/scripts/finalize.sh"
LOAD_STORY_SH="$SKILL_DIR/scripts/load-story.sh"
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

  # AC1: name must be gaia-fix-story
  if grep -qE '^name:[[:space:]]*gaia-fix-story' <<<"$fm"; then
    ok "name equals gaia-fix-story"
  else
    fail "name equals gaia-fix-story" "name field mismatch"
  fi

  # AC1: argument-hint must include story-key
  if grep -qE 'argument-hint:.*story-key' <<<"$fm"; then
    ok "argument-hint includes story-key"
  else
    fail "argument-hint includes story-key" "expected [story-key] in argument-hint"
  fi

  # AC1: tools includes required tools
  for tool in Read Write Edit Bash Grep; do
    if grep -qE "tools:.*$tool" <<<"$fm"; then
      ok "tools includes $tool"
    else
      fail "tools includes $tool" "$tool not in tools"
    fi
  done
else
  fail "frontmatter check" "SKILL.md does not exist — skipping frontmatter checks"
fi

# -----------------------------------------------------------------------------
echo ""
echo "== AC2: Findings-apply + re-validate loop =="
if [ -f "$SKILL_MD" ]; then
  body=$(cat "$SKILL_MD")
  # Must reference Val validation / gaia-val-validate
  if grep -qiE 'gaia-val-validate|re-validate|re-validation' <<<"$body"; then
    ok "skill body references re-validation"
  else
    fail "skill body references re-validation" "no mention of gaia-val-validate or re-validate"
  fi

  # Must reference findings apply
  if grep -qiE 'finding|findings' <<<"$body"; then
    ok "skill body references findings"
  else
    fail "skill body references findings" "no mention of findings"
  fi

  # Must reference validating status
  if grep -qE 'validating' <<<"$body"; then
    ok "skill body references validating status"
  else
    fail "skill body references validating status" "no mention of validating status"
  fi

  # Must reference ready-for-dev transition
  if grep -qE 'ready-for-dev' <<<"$body"; then
    ok "skill body references ready-for-dev transition"
  else
    fail "skill body references ready-for-dev transition" "no mention of ready-for-dev"
  fi
else
  fail "AC2 checks" "SKILL.md does not exist"
fi

# -----------------------------------------------------------------------------
echo ""
echo "== AC3: Cluster 7 shared scripts =="
if [ -f "$SETUP_SH" ]; then
  ok "setup.sh exists"
  if [ -x "$SETUP_SH" ]; then
    ok "setup.sh is executable"
  else
    fail "setup.sh is executable" "missing execute permission"
  fi
  # Must reference resolve-config.sh
  if grep -q "resolve-config.sh" "$SETUP_SH"; then
    ok "setup.sh references resolve-config.sh"
  else
    fail "setup.sh references resolve-config.sh" "no resolve-config.sh reference"
  fi
  # Must reference checkpoint.sh
  if grep -q "checkpoint.sh" "$SETUP_SH"; then
    ok "setup.sh references checkpoint.sh"
  else
    fail "setup.sh references checkpoint.sh" "no checkpoint.sh reference"
  fi
else
  fail "setup.sh exists" "missing: $SETUP_SH"
fi

if [ -f "$FINALIZE_SH" ]; then
  ok "finalize.sh exists"
  if [ -x "$FINALIZE_SH" ]; then
    ok "finalize.sh is executable"
  else
    fail "finalize.sh is executable" "missing execute permission"
  fi
  # Must reference checkpoint.sh
  if grep -q "checkpoint.sh" "$FINALIZE_SH"; then
    ok "finalize.sh references checkpoint.sh"
  else
    fail "finalize.sh references checkpoint.sh" "no checkpoint.sh reference"
  fi
  # Must reference lifecycle-event.sh
  if grep -q "lifecycle-event.sh" "$FINALIZE_SH"; then
    ok "finalize.sh references lifecycle-event.sh"
  else
    fail "finalize.sh references lifecycle-event.sh" "no lifecycle-event.sh reference"
  fi
else
  fail "finalize.sh exists" "missing: $FINALIZE_SH"
fi

if [ -f "$LOAD_STORY_SH" ]; then
  ok "load-story.sh exists"
  if [ -x "$LOAD_STORY_SH" ]; then
    ok "load-story.sh is executable"
  else
    fail "load-story.sh is executable" "missing execute permission"
  fi
  # Must reference sprint-state.sh
  if grep -q "sprint-state.sh" "$LOAD_STORY_SH"; then
    ok "load-story.sh references sprint-state.sh"
  else
    fail "load-story.sh references sprint-state.sh" "no sprint-state.sh reference"
  fi
else
  fail "load-story.sh exists" "missing: $LOAD_STORY_SH"
fi

# Workflow name consistency: setup/finalize must use same workflow name
if [ -f "$SETUP_SH" ] && [ -f "$FINALIZE_SH" ]; then
  setup_wf=$(grep -oE 'WORKFLOW_NAME="[^"]+"' "$SETUP_SH" | head -1)
  finalize_wf=$(grep -oE 'WORKFLOW_NAME="[^"]+"' "$FINALIZE_SH" | head -1)
  if [ -n "$setup_wf" ] && [ "$setup_wf" = "$finalize_wf" ]; then
    ok "setup.sh and finalize.sh use same WORKFLOW_NAME"
  else
    fail "WORKFLOW_NAME consistency" "setup=$setup_wf finalize=$finalize_wf"
  fi
fi

# -----------------------------------------------------------------------------
echo ""
echo "== AC4: Frontmatter linter (E28-S7) =="
if [ -x "$LINTER" ] && [ -f "$SKILL_MD" ]; then
  if "$LINTER" "$SKILL_MD" >/dev/null 2>&1; then
    ok "frontmatter linter passes"
  else
    fail "frontmatter linter passes" "linter exit code $?"
  fi
else
  if [ ! -x "$LINTER" ]; then
    ok "frontmatter linter not available — skipping (non-blocking)"
  else
    fail "frontmatter linter" "SKILL.md does not exist"
  fi
fi

# -----------------------------------------------------------------------------
echo ""
printf "== Results: %d passed, %d failed ==\n" "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
