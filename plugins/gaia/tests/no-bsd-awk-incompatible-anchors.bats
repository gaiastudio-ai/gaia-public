#!/usr/bin/env bats
# no-bsd-awk-incompatible-anchors.bats — regression guard for E45-S7.
#
# mawk and BSD awk on macOS do not support the GNU awk word-boundary
# anchors `\<...\>`. When such a regex runs under mawk or BSD awk it
# silently produces false negatives. The portable replacement is
# `(^|[^A-Za-z0-9])...([^A-Za-z0-9]|$)`.
#
# This test scans plugins/gaia/scripts/ and plugins/gaia/tests/ for any
# remaining occurrences and fails if any are found. Comments that
# document the bad form (referenced as "no \\< \\>") are explicitly
# excluded so the canonical idiom doc and explanatory comments do not
# trip the guard.

load 'test_helper.bash'

setup() {
  common_setup
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
  export REPO_ROOT
}
teardown() { common_teardown; }

# _scan_awk_word_boundaries <dir>
# Walk every .sh and .bats file under <dir> looking for awk regexes
# containing the BSD/mawk-incompatible `\<` or `\>` word-boundary
# anchors. Heuristic: only flag lines that look like awk regex bodies —
# i.e., the literal sequence appears between a `/` and another `/`, or
# inside `~ /.../` (the awk match operator). Also skip:
#   - this guard test itself (which mentions the bad form by name)
#   - any line inside a shell comment that documents the bad form
#   - the gaia-shell-idioms SKILL.md is a .md file (not scanned anyway)
#
# Implementation: grep -E for `[/~][^/]*\\<` and `\\>[^/]*/` style
# windows, then strip noise.
_scan_awk_word_boundaries() {
  local dir="$1"
  [ -d "$dir" ] || return 0
  # Match a forward slash followed by any non-slash chars then \< (or
  # \>). This catches awk literal regexes like /\<foo\>/ and ~ /...\</.
  # Use -E with bracket-escaped backslash. Exclude this guard test file
  # from its own scan.
  local self="${BATS_TEST_FILENAME:-$BATS_TEST_DIRNAME/no-bsd-awk-incompatible-anchors.bats}"
  local self_base="${self##*/}"
  grep -rnE --include='*.sh' --include='*.bats' \
    '/[^/]*\\[<>]|\\[<>][^/]*/' "$dir" 2>/dev/null \
    | grep -v "/${self_base}:" \
    | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' \
    || true
}

@test "scripts/: no awk \\< or \\> word-boundary anchors remain" {
  local hits
  hits="$(_scan_awk_word_boundaries "$REPO_ROOT/plugins/gaia/scripts")"
  if [ -n "$hits" ]; then
    printf 'BSD/mawk-incompatible awk word boundaries found in scripts/:\n%s\n' "$hits" >&2
    return 1
  fi
}

@test "tests/: no awk \\< or \\> word-boundary anchors remain" {
  local hits
  hits="$(_scan_awk_word_boundaries "$REPO_ROOT/plugins/gaia/tests")"
  if [ -n "$hits" ]; then
    printf 'BSD/mawk-incompatible awk word boundaries found in tests/:\n%s\n' "$hits" >&2
    return 1
  fi
}

@test "skills/: no awk \\< or \\> word-boundary anchors remain" {
  # Skill scripts under plugins/gaia/skills/*/scripts/ are also in scope —
  # they run the same finalize/validation logic and must be portable.
  local hits
  hits="$(_scan_awk_word_boundaries "$REPO_ROOT/plugins/gaia/skills")"
  if [ -n "$hits" ]; then
    printf 'BSD/mawk-incompatible awk word boundaries found in skills/:\n%s\n' "$hits" >&2
    return 1
  fi
}

@test "shell-idioms skill documents the BSD/mawk word-boundary idiom" {
  local skill="$REPO_ROOT/plugins/gaia/skills/gaia-shell-idioms/SKILL.md"
  [ -f "$skill" ]
  grep -q 'BSD' "$skill"
  grep -q 'mawk' "$skill"
  grep -q 'word.boundary\|word-boundary' "$skill"
  grep -q '(\^|\[\^A-Za-z0-9\])' "$skill"
}
