#!/usr/bin/env bats
# commit-msg.bats — coverage for skills/gaia-dev-story/scripts/commit-msg.sh
#
# Story: E57-S7 — pr-body.sh (P1-2) + commit-msg.sh (P1-3)
# Traces: TC-DSS-07 (commit-msg type mapping), TC-DSS-08 (shell-metachar safety)
# ACs: AC2, AC3, AC4, AC5

load 'test_helper.bash'

setup() {
  common_setup
  COMMIT_MSG="$(cd "$BATS_TEST_DIRNAME/../skills/gaia-dev-story/scripts" && pwd)/commit-msg.sh"
  cd "$TEST_TMP"
  mkdir -p docs/implementation-artifacts
  export PROJECT_PATH="$TEST_TMP"
}

teardown() { common_teardown; }

_write_story() {
  local key="$1"
  local type_field="$2"   # may be empty
  local title="${3:-Test Story}"
  local type_line=""
  if [ -n "$type_field" ]; then
    type_line="type: \"$type_field\""
  fi
  cat > "docs/implementation-artifacts/${key}-test.md" <<EOF
---
template: 'story'
key: "$key"
title: "$title"
$type_line
epic: "E57"
status: in-progress
risk: "low"
depends_on: []
---

# Story

## Acceptance Criteria

- [ ] AC1

## Tasks / Subtasks

- [x] Task 1
EOF
  echo "docs/implementation-artifacts/${key}-test.md"
}

# ---------------------------------------------------------------------------
# AC2 / TC-DSS-07 — Type mapping
# ---------------------------------------------------------------------------

@test "commit-msg: type=feature -> feat(<key>): <title>" {
  path="$(_write_story "E57-S7" "feature" "Add login flow")"
  run "$COMMIT_MSG" "$path"
  [ "$status" -eq 0 ]
  subject=$(echo "$output" | head -1)
  [ "$subject" = "feat(E57-S7): Add login flow" ]
}

@test "commit-msg: type=bug -> fix(<key>): <title>" {
  path="$(_write_story "E1-S1" "bug" "Fix crash on save")"
  run "$COMMIT_MSG" "$path"
  [ "$status" -eq 0 ]
  subject=$(echo "$output" | head -1)
  [ "$subject" = "fix(E1-S1): Fix crash on save" ]
}

@test "commit-msg: type=refactor -> refactor(<key>): <title>" {
  path="$(_write_story "E1-S2" "refactor" "Extract helper")"
  run "$COMMIT_MSG" "$path"
  [ "$status" -eq 0 ]
  subject=$(echo "$output" | head -1)
  [ "$subject" = "refactor(E1-S2): Extract helper" ]
}

@test "commit-msg: type=chore -> chore(<key>): <title>" {
  path="$(_write_story "E1-S3" "chore" "Update deps")"
  run "$COMMIT_MSG" "$path"
  [ "$status" -eq 0 ]
  subject=$(echo "$output" | head -1)
  [ "$subject" = "chore(E1-S3): Update deps" ]
}

@test "commit-msg: type unrecognized -> default feat(...)" {
  path="$(_write_story "E1-S4" "weird" "Something")"
  run "$COMMIT_MSG" "$path"
  [ "$status" -eq 0 ]
  subject=$(echo "$output" | head -1)
  [ "$subject" = "feat(E1-S4): Something" ]
}

@test "commit-msg: type missing -> default feat(...)" {
  path="$(_write_story "E1-S5" "" "No type field")"
  run "$COMMIT_MSG" "$path"
  [ "$status" -eq 0 ]
  subject=$(echo "$output" | head -1)
  [ "$subject" = "feat(E1-S5): No type field" ]
}

# ---------------------------------------------------------------------------
# AC2 — subject regex + 72-char cap
# ---------------------------------------------------------------------------

@test "commit-msg: subject matches Conventional Commit regex" {
  path="$(_write_story "E57-S7" "feature" "Add login")"
  run "$COMMIT_MSG" "$path"
  [ "$status" -eq 0 ]
  subject=$(echo "$output" | head -1)
  echo "$subject" | grep -qE '^(feat|fix|refactor|chore)\([A-Z][0-9]+-S[0-9]+\): .+$'
}

@test "commit-msg: 90-char title is truncated to 72-char subject" {
  long_title="This is a really long title that exceeds seventy-two chars and must be truncated cleanly here"
  path="$(_write_story "E57-S7" "feature" "$long_title")"
  run "$COMMIT_MSG" "$path"
  [ "$status" -eq 0 ]
  subject=$(echo "$output" | head -1)
  [ "${#subject}" -le 72 ]
}

# ---------------------------------------------------------------------------
# AC5 — No Claude/Co-Authored-By in output
# ---------------------------------------------------------------------------

@test "commit-msg: output contains no Claude / Co-Authored-By strings" {
  path="$(_write_story "E57-S7" "feature" "Test")"
  run "$COMMIT_MSG" "$path"
  [ "$status" -eq 0 ]
  ! echo "$output" | grep -qE "Claude|Co-Authored-By"
}

# ---------------------------------------------------------------------------
# AC3 / TC-DSS-08 — Adversarial title shell-metachar safety
# ---------------------------------------------------------------------------

@test "commit-msg: adversarial title with command-substitution does not execute" {
  cat > "docs/implementation-artifacts/E57-S7-adv.md" <<'EOF'
---
template: 'story'
key: "E57-S7"
title: 'Add support for $(touch /tmp/commit_msg_pwn); `whoami`; "x"; ''y'''
type: "feature"
epic: "E57"
status: in-progress
risk: "low"
depends_on: []
---

# Adversarial

## Acceptance Criteria

- [ ] AC1
EOF
  rm -f /tmp/commit_msg_pwn
  run "$COMMIT_MSG" "docs/implementation-artifacts/E57-S7-adv.md"
  [ "$status" -eq 0 ]
  # Ensure the dangerous command did not execute.
  [ ! -e /tmp/commit_msg_pwn ]
}

@test "commit-msg: adversarial title feeds cleanly into git commit -F -" {
  cat > "docs/implementation-artifacts/E57-S7-adv2.md" <<'EOF'
---
template: 'story'
key: "E57-S7"
title: 'Adv $(rm -rf /); `whoami`; "x"'
type: "feature"
epic: "E57"
status: in-progress
risk: "low"
depends_on: []
---

# Adversarial

## Acceptance Criteria

- [ ] AC1
EOF
  # Set up a throwaway git repo
  git init -q .
  git config user.email "test@example.com"
  git config user.name "Test"
  echo "x" > seed.txt
  git add seed.txt
  echo "y" > another.txt
  git add another.txt
  # Run commit-msg.sh and pipe to git commit -F -
  msg="$("$COMMIT_MSG" "docs/implementation-artifacts/E57-S7-adv2.md")"
  echo "$msg" | git commit -q -F -
}

# ---------------------------------------------------------------------------
# AC4 / TC-DSS-08 — No `eval` in commit-msg.sh source
# ---------------------------------------------------------------------------

@test "commit-msg: source contains no bare 'eval'" {
  ! grep -nE "\beval\b" "$COMMIT_MSG"
}
