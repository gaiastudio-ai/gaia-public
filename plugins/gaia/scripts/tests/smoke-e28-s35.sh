#!/usr/bin/env bash
# smoke-e28-s35.sh — smoke tests for gaia-brainstorm SKILL conversion (E28-S35)
#
# Drives the RED → GREEN cycle for E28-S35 / brief P4-S1:
#   - Cluster 4 SKILL.md directory structure
#   - Cluster 4 frontmatter (name, description, argument-hint, context: fork, allowed-tools)
#   - Shared setup.sh / finalize.sh pattern
#   - Legacy instructions preserved verbatim (output path, step ordering)
#   - E28-S7 frontmatter linter passes
#
# Usage: bash plugins/gaia/scripts/tests/smoke-e28-s35.sh
# Exit 0 when all assertions pass, 1 on first aggregated failure.

set -uo pipefail
LC_ALL=C

REPO_ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
SKILL_DIR="$REPO_ROOT/plugins/gaia/skills/gaia-brainstorm"
SKILL_MD="$SKILL_DIR/SKILL.md"
SETUP_SH="$SKILL_DIR/scripts/setup.sh"
FINALIZE_SH="$SKILL_DIR/scripts/finalize.sh"
LINTER="$REPO_ROOT/.github/scripts/lint-skill-frontmatter.sh"

PASS=0
FAIL=0

ok()   { printf "  ok  %s\n" "$1"; PASS=$((PASS + 1)); }
fail() { printf "  FAIL %s\n     %s\n" "$1" "$2"; FAIL=$((FAIL + 1)); }

# -----------------------------------------------------------------------------
echo "== AC1: SKILL.md exists with Cluster 4 frontmatter =="
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
  for field in name description argument-hint context allowed-tools; do
    if grep -qE "^${field}:" <<<"$fm"; then
      ok "frontmatter has $field"
    else
      fail "frontmatter has $field" "missing key in frontmatter"
    fi
  done
  if grep -qE "^context:[[:space:]]*fork[[:space:]]*$" <<<"$fm"; then
    ok "context equals fork"
  else
    fail "context equals fork" "context is not 'fork'"
  fi
fi

# -----------------------------------------------------------------------------
echo "== AC2: setup.sh and finalize.sh exist and are executable =="
for f in "$SETUP_SH" "$FINALIZE_SH"; do
  if [ -f "$f" ]; then
    ok "$(basename "$f") exists"
    if [ -x "$f" ]; then
      ok "$(basename "$f") is executable"
    else
      fail "$(basename "$f") is executable" "not +x"
    fi
    if bash -n "$f" 2>/dev/null; then
      ok "$(basename "$f") syntax ok"
    else
      fail "$(basename "$f") syntax ok" "bash -n failed"
    fi
  else
    fail "$(basename "$f") exists" "missing: $f"
  fi
done

# setup.sh must reference the shared foundation scripts
if [ -f "$SETUP_SH" ]; then
  if grep -q "resolve-config.sh" "$SETUP_SH"; then
    ok "setup.sh calls resolve-config.sh"
  else
    fail "setup.sh calls resolve-config.sh" "no reference to resolve-config.sh"
  fi
  if grep -q "validate-gate.sh" "$SETUP_SH"; then
    ok "setup.sh calls validate-gate.sh"
  else
    fail "setup.sh calls validate-gate.sh" "no reference to validate-gate.sh"
  fi
  if grep -q "checkpoint.sh" "$SETUP_SH"; then
    ok "setup.sh loads checkpoint"
  else
    fail "setup.sh loads checkpoint" "no reference to checkpoint.sh"
  fi
fi

# finalize.sh must write a checkpoint and emit a lifecycle event
if [ -f "$FINALIZE_SH" ]; then
  if grep -q "checkpoint.sh" "$FINALIZE_SH"; then
    ok "finalize.sh writes checkpoint"
  else
    fail "finalize.sh writes checkpoint" "no reference to checkpoint.sh"
  fi
  if grep -q "lifecycle-event.sh" "$FINALIZE_SH"; then
    ok "finalize.sh emits lifecycle event"
  else
    fail "finalize.sh emits lifecycle event" "no reference to lifecycle-event.sh"
  fi
fi

# -----------------------------------------------------------------------------
echo "== AC3: body preserves legacy output path and step ordering =="
if [ -f "$SKILL_MD" ]; then
  if grep -q "creative-artifacts/brainstorm-" "$SKILL_MD"; then
    ok "legacy output path preserved"
  else
    fail "legacy output path preserved" "creative-artifacts/brainstorm-*.md not referenced"
  fi
  # Legacy 5-step order: Discover Context → Elicit Project Vision → Competitive Landscape → Opportunity Synthesis → Generate Output
  prev=0
  for step in "Discover Context" "Elicit Project Vision" "Competitive Landscape" "Opportunity Synthesis" "Generate Output"; do
    line=$(grep -n "$step" "$SKILL_MD" | head -1 | cut -d: -f1)
    if [ -z "$line" ]; then
      fail "step '$step' present" "not found in SKILL.md body"
      prev=999999
      continue
    fi
    if [ "$line" -gt "$prev" ]; then
      ok "step '$step' in order"
    else
      fail "step '$step' in order" "appears before previous step"
    fi
    prev="$line"
  done
fi

# -----------------------------------------------------------------------------
echo "== AC4: E28-S7 frontmatter linter passes =="
if [ -x "$LINTER" ]; then
  if (cd "$REPO_ROOT" && bash "$LINTER" >/dev/null 2>&1); then
    ok "lint-skill-frontmatter.sh exit 0"
  else
    fail "lint-skill-frontmatter.sh exit 0" "linter reported errors"
  fi
else
  fail "linter available" "missing or not executable: $LINTER"
fi

# -----------------------------------------------------------------------------
echo
echo "== summary: $PASS passed, $FAIL failed =="
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
