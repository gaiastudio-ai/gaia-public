#!/usr/bin/env bash
# smoke-e28-s36.sh — smoke tests for gaia-product-brief SKILL conversion (E28-S36)
#
# Drives the RED → GREEN cycle for E28-S36 / brief P4-S2:
#   - Cluster 4 SKILL.md directory structure
#   - Cluster 4 frontmatter (name, description, argument-hint, context: fork, allowed-tools)
#   - Shared setup.sh / finalize.sh pattern (byte-identical to E28-S35 reference
#     modulo skill-name substitution)
#   - Legacy instructions preserved (output path, 8-step ordering)
#   - E28-S7 frontmatter linter passes
#
# This script is the Cluster 4 test-manifest hook for E28-S39 — the end-to-end
# gate references each per-story smoke script via naming convention.
#
# Usage: bash plugins/gaia/scripts/tests/smoke-e28-s36.sh
# Exit 0 when all assertions pass, 1 on first aggregated failure.

set -uo pipefail
LC_ALL=C

REPO_ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
SKILL_DIR="$REPO_ROOT/plugins/gaia/skills/gaia-product-brief"
SKILL_MD="$SKILL_DIR/SKILL.md"
SETUP_SH="$SKILL_DIR/scripts/setup.sh"
FINALIZE_SH="$SKILL_DIR/scripts/finalize.sh"
REF_SETUP="$REPO_ROOT/plugins/gaia/skills/gaia-brainstorm/scripts/setup.sh"
REF_FINALIZE="$REPO_ROOT/plugins/gaia/skills/gaia-brainstorm/scripts/finalize.sh"
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
  if grep -qE '^name:[[:space:]]*gaia-product-brief[[:space:]]*$' <<<"$fm"; then
    ok "name equals gaia-product-brief"
  else
    fail "name equals gaia-product-brief" "name field mismatch"
  fi
fi

# -----------------------------------------------------------------------------
echo "== AC2: setup.sh and finalize.sh exist, executable, and follow Cluster 4 reference =="
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
  for ref in resolve-config.sh validate-gate.sh checkpoint.sh; do
    if grep -q "$ref" "$SETUP_SH"; then
      ok "setup.sh references $ref"
    else
      fail "setup.sh references $ref" "no reference to $ref"
    fi
  done
  if grep -q 'WORKFLOW_NAME="create-product-brief"' "$SETUP_SH"; then
    ok "setup.sh WORKFLOW_NAME=create-product-brief"
  else
    fail "setup.sh WORKFLOW_NAME=create-product-brief" "workflow name mismatch"
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
  if grep -q 'WORKFLOW_NAME="create-product-brief"' "$FINALIZE_SH"; then
    ok "finalize.sh WORKFLOW_NAME=create-product-brief"
  else
    fail "finalize.sh WORKFLOW_NAME=create-product-brief" "workflow name mismatch"
  fi
fi

# Structural diff against the E28-S35 reference: after normalizing the
# skill-name substitutions, the scripts must be byte-identical.
normalize() {
  sed \
    -e 's|gaia-product-brief|__SKILL__|g' \
    -e 's|gaia-brainstorm|__SKILL__|g' \
    -e 's|create-product-brief|__WORKFLOW__|g' \
    -e 's|brainstorm-project|__WORKFLOW__|g' \
    "$1"
}

if [ -f "$SETUP_SH" ] && [ -f "$REF_SETUP" ]; then
  # The reference and ported scripts have different header comments (E28-S35
  # vs E28-S36) and different gate-section commentary. Compare only the
  # executable body from `set -euo pipefail` onward, then strip comment lines.
  extract_body() {
    awk '/^set -euo pipefail/{found=1} found' "$1" | grep -v '^[[:space:]]*#'
  }
  if diff <(extract_body "$SETUP_SH" | normalize /dev/stdin) \
          <(extract_body "$REF_SETUP" | normalize /dev/stdin) >/dev/null 2>&1; then
    ok "setup.sh body matches Cluster 4 reference (modulo skill name)"
  else
    fail "setup.sh body matches Cluster 4 reference (modulo skill name)" \
         "executable body diverges from gaia-brainstorm reference"
  fi
fi

if [ -f "$FINALIZE_SH" ] && [ -f "$REF_FINALIZE" ]; then
  extract_body() {
    awk '/^set -euo pipefail/{found=1} found' "$1" | grep -v '^[[:space:]]*#'
  }
  # finalize.sh step number differs (brainstorm=5 steps, product-brief=8).
  # Normalize the --step argument as well.
  normalize_finalize() {
    normalize /dev/stdin | sed -e 's|--step [0-9][0-9]*|--step N|g'
  }
  if diff <(extract_body "$FINALIZE_SH" | normalize_finalize) \
          <(extract_body "$REF_FINALIZE" | normalize_finalize) >/dev/null 2>&1; then
    ok "finalize.sh body matches Cluster 4 reference (modulo skill name and step count)"
  else
    fail "finalize.sh body matches Cluster 4 reference (modulo skill name and step count)" \
         "executable body diverges from gaia-brainstorm reference"
  fi
fi

# -----------------------------------------------------------------------------
echo "== AC3: body preserves legacy output path and 8-step ordering =="
if [ -f "$SKILL_MD" ]; then
  if grep -q "creative-artifacts/product-brief-" "$SKILL_MD"; then
    ok "legacy output path preserved (docs/creative-artifacts/product-brief-*.md)"
  else
    fail "legacy output path preserved" "creative-artifacts/product-brief-*.md not referenced"
  fi

  # Legacy 8-step order from instructions.xml:
  #   Discover Inputs → Vision Statement → Target Users → Problem Statement →
  #   Proposed Solution → Scope, Risks and Competitive Landscape →
  #   Success Metrics → Generate Output
  prev=0
  for step in \
    "Discover Inputs" \
    "Vision Statement" \
    "Target Users" \
    "Problem Statement" \
    "Proposed Solution" \
    "Scope, Risks and Competitive Landscape" \
    "Success Metrics" \
    "Generate Output"; do
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

  # Vision question from legacy <ask> must be preserved verbatim.
  if grep -q "What is the core vision for this product" "$SKILL_MD"; then
    ok "legacy vision elicitation question preserved"
  else
    fail "legacy vision elicitation question preserved" \
         "missing legacy ask prompt"
  fi
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
