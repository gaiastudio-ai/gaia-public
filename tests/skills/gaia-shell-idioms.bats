#!/usr/bin/env bats
# gaia-shell-idioms.bats — shell-idioms skill structural + content tests (E28-S168)
#
# Validates:
#   AC1: SKILL.md exists with valid YAML frontmatter and documents the awk
#        range-bug pattern and the state-machine fix.
#   AC2: Documentation includes both the broken idiom and the state-machine fix
#        as runnable examples (fenced code blocks).
#   AC3: Spot-checked bats files in tests/cluster-13-parity/ that use the
#        state-machine pattern cross-reference the shell-idioms skill.
#
# Usage:
#   bats tests/skills/gaia-shell-idioms.bats
#
# Dependencies: bats-core 1.10+

# ---------- Helpers ----------

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SKILLS_DIR="$REPO_ROOT/plugins/gaia/skills"
  SKILL_DIR="$SKILLS_DIR/gaia-shell-idioms"
  SKILL_FILE="$SKILL_DIR/SKILL.md"
}

# Extract YAML frontmatter (between first two `---` delimiters).
_frontmatter() {
  local file="$1"
  awk '
    BEGIN { in_fm = 0; seen = 0 }
    /^---[[:space:]]*$/ {
      if (seen == 0) { in_fm = 1; seen = 1; next }
      else if (in_fm == 1) { in_fm = 0; exit }
    }
    in_fm == 1 { print }
  ' "$file"
}

# Extract the body after the frontmatter (everything after the second `---`).
_body() {
  local file="$1"
  awk '
    BEGIN { seen = 0; in_body = 0 }
    /^---[[:space:]]*$/ {
      seen++
      if (seen == 2) { in_body = 1; next }
      next
    }
    in_body == 1 { print }
  ' "$file"
}

# ---------- AC1: SKILL.md exists with valid frontmatter ----------

@test "AC1: SKILL.md exists at gaia-shell-idioms skill directory" {
  [ -f "$SKILL_FILE" ]
}

@test "AC1: SKILL.md has YAML frontmatter delimiters" {
  head -1 "$SKILL_FILE" | grep -q "^---$"
  awk 'NR>1 && /^---$/{found=1; exit} END{exit !found}' "$SKILL_FILE"
}

@test "AC1: SKILL.md frontmatter contains name: gaia-shell-idioms" {
  _frontmatter "$SKILL_FILE" | grep -q "^name: gaia-shell-idioms$"
}

@test "AC1: SKILL.md frontmatter contains description field" {
  _frontmatter "$SKILL_FILE" | grep -q "^description:"
}

@test "AC1: SKILL.md frontmatter contains allowed-tools field" {
  _frontmatter "$SKILL_FILE" | grep -q "^allowed-tools:"
}

@test "AC1: SKILL.md documents the awk range-bug pattern" {
  # References the broken /start/,/end/ range idiom
  grep -qE "/start/,/end/|awk.*range.*bug|range.*bug.*awk" "$SKILL_FILE"
}

@test "AC1: SKILL.md documents the state-machine fix" {
  # References the flag-based state-machine replacement
  grep -qi "state.machine" "$SKILL_FILE"
}

@test "AC1: SKILL.md references the recurring bug history" {
  # Must acknowledge the 3-time recurrence (E28-S126, E28-S128 or E28-S130)
  grep -qE "E28-S126|E28-S130|recurred|recurrence|3 times|three times" "$SKILL_FILE"
}

@test "AC1: SKILL.md frontmatter does NOT invoke non-existent scripts" {
  # This is a reference-only skill (prose). No setup.sh/finalize.sh expected.
  ! grep -qE '!\$\{CLAUDE_PLUGIN_ROOT\}' "$SKILL_FILE"
}

# ---------- AC2: Runnable examples (broken + fixed) ----------

@test "AC2: SKILL.md contains at least two fenced code blocks" {
  # Broken idiom + state-machine fix = minimum 2 code blocks
  local count
  count=$(grep -c '^```' "$SKILL_FILE" || true)
  # Each block opens and closes with ```, so total ``` lines >= 4
  [ "$count" -ge 4 ]
}

@test "AC2: SKILL.md contains the broken awk range idiom as a runnable example" {
  # The buggy form: awk '/.../,/.../ { ... }' or similar range expression
  grep -qE "awk[[:space:]]+'/[^/]+/,/[^/]+/" "$SKILL_FILE"
}

@test "AC2: SKILL.md contains the state-machine fix as a runnable example" {
  # The fix uses flag=1; next; flag && .../...{flag=0}; flag
  grep -qE "flag[[:space:]]*=[[:space:]]*1" "$SKILL_FILE"
  grep -qE "flag[[:space:]]*=[[:space:]]*0|!flag|flag[[:space:]]*\\\$" "$SKILL_FILE" || \
    grep -qE "flag && " "$SKILL_FILE"
}

@test "AC2: SKILL.md body contains both 'Broken' and 'Fix' (or equivalent) section labels" {
  local body
  body="$(_body "$SKILL_FILE")"
  # Accept Broken/Buggy/Wrong for the broken label
  echo "$body" | grep -qiE "broken|buggy|wrong|anti.pattern" || { echo "missing broken-idiom label"; return 1; }
  # Accept Fix/Fixed/Correct/State Machine for the fix label
  echo "$body" | grep -qiE "\bfix\b|fixed|correct|state.machine" || { echo "missing fix label"; return 1; }
}

@test "AC2: SKILL.md explains why the range bug occurs" {
  # Must explain that the bug happens when both patterns can match the same line
  grep -qiE "same line|both patterns|same pattern|terminates at the start" "$SKILL_FILE"
}

# ---------- AC3: Cross-references from affected bats files ----------

@test "AC3: storytelling-parity.bats cross-references gaia-shell-idioms" {
  local f="$REPO_ROOT/tests/cluster-13-parity/storytelling-parity.bats"
  [ -f "$f" ]
  grep -q "gaia-shell-idioms" "$f"
}

@test "AC3: pitch-deck-parity.bats cross-references gaia-shell-idioms" {
  local f="$REPO_ROOT/tests/cluster-13-parity/pitch-deck-parity.bats"
  [ -f "$f" ]
  grep -q "gaia-shell-idioms" "$f"
}

@test "AC3: problem-solving-parity.bats cross-references gaia-shell-idioms" {
  local f="$REPO_ROOT/tests/cluster-13-parity/problem-solving-parity.bats"
  [ -f "$f" ]
  grep -q "gaia-shell-idioms" "$f"
}

@test "AC3: slide-deck-parity.bats cross-references gaia-shell-idioms" {
  local f="$REPO_ROOT/tests/cluster-13-parity/slide-deck-parity.bats"
  [ -f "$f" ]
  grep -q "gaia-shell-idioms" "$f"
}
