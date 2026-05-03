#!/usr/bin/env bats
# shell-idioms.bats — coverage for plugins/gaia/scripts/lib/shell-idioms.sh
#
# Story: E20-S20 — Extract safe_grep_log() shell helper for set -euo pipefail
#                  + grep-in-pipeline pattern.
# Refs:  AC1, AC3.
#
# Covers:
#   - matching   — pattern present in git log -> exit 0, prints matching lines
#   - non-match  — pattern absent  -> exit 1, no output
#   - empty-log  — empty repo      -> exit 1 cleanly (no SIGPIPE, no abort)
#   - strict     — `set -euo pipefail` enabled does not trip when grep early-exits

load 'test_helper.bash'

bats_require_minimum_version 1.5.0

setup() {
  common_setup
  LIB="$(cd "$BATS_TEST_DIRNAME/../scripts/lib" && pwd)/shell-idioms.sh"
  cd "$TEST_TMP"
  # Build a tiny disposable repo for git-log fixtures.
  git init -q -b main .
  git config user.email "test@gaia.local"
  git config user.name  "Gaia Test"
  git commit -q --allow-empty -m "feat(E20-S20): seed commit"
  git commit -q --allow-empty -m "fix(E20-S20): refine helper"
  git commit -q --allow-empty -m "docs(E99-S1): unrelated commit"
}

teardown() { common_teardown; }

# AC1 — helper file exists and is sourceable
@test "shell-idioms.sh: file exists at canonical path" {
  [ -f "$LIB" ]
}

@test "shell-idioms.sh: is sourceable without error" {
  run bash -c "set -euo pipefail; source '$LIB'"
  [ "$status" -eq 0 ]
}

@test "safe_grep_log: defined as a shell function after sourcing" {
  run bash -c "set -euo pipefail; source '$LIB'; declare -F safe_grep_log"
  [ "$status" -eq 0 ]
  [[ "$output" == *"safe_grep_log"* ]]
}

# AC3 case 1 — matching
@test "safe_grep_log: matching pattern returns 0 and prints matching lines" {
  run bash -c "set -euo pipefail; source '$LIB'; safe_grep_log 'E20-S20' --oneline"
  [ "$status" -eq 0 ]
  [[ "$output" == *"E20-S20"* ]]
  # Two seed commits include E20-S20; unrelated one must not appear.
  [[ "$output" != *"E99-S1"* ]]
}

# AC3 case 2 — non-matching
@test "safe_grep_log: non-matching pattern returns 1 and prints nothing" {
  run bash -c "set -euo pipefail; source '$LIB'; safe_grep_log 'E404-NOPE' --oneline"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

# AC3 case 3 — empty log (fresh repo, no commits)
@test "safe_grep_log: empty log returns 1 cleanly under strict mode" {
  rm -rf .git
  git init -q -b main .
  # Realistic strict-mode usage: callers test the helper via `if` (or `|| true`),
  # exactly as verify-pr-merged.sh does. The SENTINEL line proves the script kept
  # running past the call rather than aborting on a missing function or SIGPIPE.
  run bash -c "
    set -euo pipefail
    source '$LIB'
    if safe_grep_log 'anything' --oneline; then
      echo SENTINEL=match
    else
      echo SENTINEL=nomatch
    fi
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"SENTINEL=nomatch"* ]]
}

# AC3 case 4 — strict mode (set -euo pipefail) does not trip
@test "safe_grep_log: set -euo pipefail does not trip when grep early-exits" {
  # The original anti-pattern is `git log | grep -q PATTERN` with `set -o pipefail`:
  # grep exits 0 on first match and closes the pipe, sending SIGPIPE (141) to
  # git log; pipefail then propagates the 141 even though the user-visible
  # outcome was "match found". safe_grep_log must shield callers from that.
  run bash -c "
    set -euo pipefail
    source '$LIB'
    safe_grep_log 'E20-S20' --oneline >/dev/null
    echo OK_AFTER_MATCH
    safe_grep_log 'E404-NOPE' --oneline >/dev/null || true
    echo OK_AFTER_NOMATCH
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK_AFTER_MATCH"* ]]
  [[ "$output" == *"OK_AFTER_NOMATCH"* ]]
}

# AC3 — case-insensitive flag passthrough (mirrors verify-pr-merged.sh usage)
@test "safe_grep_log: -i flag matches case-insensitively" {
  run bash -c "set -euo pipefail; source '$LIB'; safe_grep_log -i 'e20-s20' --oneline"
  [ "$status" -eq 0 ]
  [[ "$output" == *"E20-S20"* ]]
}

# AC3 — extended-regex flag (-E) passthrough.
# Pattern uses an alternation, which is ERE-only — would not match under BRE.
@test "safe_grep_log: -E flag enables extended regex" {
  run bash -c "set -euo pipefail; source '$LIB'; safe_grep_log -E '(E20-S20|nope)' --oneline"
  [ "$status" -eq 0 ]
  [[ "$output" == *"E20-S20"* ]]
}

# AC3 — usage / arg validation
@test "safe_grep_log: missing pattern argument returns non-zero" {
  run bash -c "set -euo pipefail; source '$LIB'; safe_grep_log"
  [ "$status" -ne 0 ]
}
