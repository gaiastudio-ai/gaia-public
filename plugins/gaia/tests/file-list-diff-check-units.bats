#!/usr/bin/env bats
# file-list-diff-check-units.bats — unit coverage for file-list-diff-check.sh helpers (NFR-052)
#
# Public-function direct unit tests for file-list-diff-check.sh:
#   - extract_file_list
#   - parse_file_entries
#   - to_json_array
#
# Each helper is sourced via awk-extracted bodies so the script's top-level
# argument-parsing and main pipeline does not execute. Behavioural coverage
# lives in file-list-diff-check.bats.

load 'test_helper.bash'

bats_require_minimum_version 1.5.0

setup() {
  common_setup
  SCRIPT="$SCRIPTS_DIR/file-list-diff-check.sh"
  STORY="$TEST_TMP/story.md"
}
teardown() { common_teardown; }

_load_helpers() {
  local tmp
  tmp="$(mktemp -t flist-helpers.XXXXXX)"
  awk '
    /^extract_file_list\(\) \{/,/^\}/ { print; next }
    /^parse_file_entries\(\) \{/,/^\}/ { print; next }
    /^to_json_array\(\) \{/,/^\}/ { print; next }
  ' "$SCRIPT" > "$tmp"
  STORY_VAR="$STORY"
  STORY="$STORY_VAR"
  # shellcheck disable=SC1090
  source "$tmp"
  rm -f "$tmp"
}

# ---------------------------------------------------------------------------
# extract_file_list
# ---------------------------------------------------------------------------

@test "extract_file_list: returns lines between '## File List' and next H2" {
  _load_helpers
  cat > "$STORY" <<'EOF'
# Title

## File List

- `path/a.ts`
- `path/b.ts`

## Dev Notes

other
EOF
  STORY="$STORY"
  run extract_file_list
  [ "$status" -eq 0 ]
  [[ "$output" == *"path/a.ts"* ]]
  [[ "$output" == *"path/b.ts"* ]]
  [[ "$output" != *"Dev Notes"* ]]
  [[ "$output" != *"other"* ]]
}

@test "extract_file_list: matches case-insensitive 'File list' heading" {
  _load_helpers
  cat > "$STORY" <<'EOF'
## File list

- foo.ts
EOF
  run extract_file_list
  [ "$status" -eq 0 ]
  [[ "$output" == *"foo.ts"* ]]
}

@test "extract_file_list: returns empty when no File List section" {
  _load_helpers
  cat > "$STORY" <<'EOF'
# Title

## Dev Notes

nothing here
EOF
  run extract_file_list
  [ "$status" -eq 0 ]
  [ -z "$(printf '%s' "$output" | tr -d '[:space:]')" ]
}

# ---------------------------------------------------------------------------
# parse_file_entries
# ---------------------------------------------------------------------------

@test "parse_file_entries: extracts paths from markdown bullets, strips backticks" {
  _load_helpers
  cat > "$STORY" <<'EOF'
## File List

- `path/a.ts`
- `path/b.ts` — comment
* `path/c.ts`
EOF
  run parse_file_entries
  [ "$status" -eq 0 ]
  [[ "$output" == *"path/a.ts"* ]]
  [[ "$output" == *"path/b.ts"* ]]
  [[ "$output" == *"path/c.ts"* ]]
  [[ "$output" != *"comment"* ]]
}

@test "parse_file_entries: skips non-bullet lines inside section" {
  _load_helpers
  cat > "$STORY" <<'EOF'
## File List

Some prose introducing the list.

- `kept.ts`
EOF
  run parse_file_entries
  [ "$status" -eq 0 ]
  [[ "$output" == *"kept.ts"* ]]
  [[ "$output" != *"prose"* ]]
}

@test "parse_file_entries: emits no path entries when section is empty" {
  _load_helpers
  cat > "$STORY" <<'EOF'
## File List

## Dev Notes
EOF
  run parse_file_entries
  # grep with no matches in the inner pipeline can return non-zero — the
  # contract is "no path entries on stdout", not a specific exit code.
  [ -z "$(printf '%s' "$output" | tr -d '[:space:]')" ]
}

# ---------------------------------------------------------------------------
# to_json_array
# ---------------------------------------------------------------------------

@test "to_json_array: builds JSON array of quoted strings" {
  _load_helpers
  got="$(to_json_array "$(printf 'a.ts\nb.ts\n')")"
  [ "$got" = '["a.ts","b.ts"]' ]
}

@test "to_json_array: empty input yields empty array" {
  _load_helpers
  got="$(to_json_array "")"
  [ "$got" = '[]' ]
}

@test "to_json_array: escapes embedded double-quotes" {
  _load_helpers
  got="$(to_json_array 'has"quote')"
  [ "$got" = '["has\"quote"]' ]
}

@test "to_json_array: escapes backslashes" {
  _load_helpers
  got="$(to_json_array 'a\b')"
  [ "$got" = '["a\\b"]' ]
}

@test "to_json_array: skips blank lines" {
  _load_helpers
  got="$(to_json_array "$(printf 'a\n\nb\n')")"
  [ "$got" = '["a","b"]' ]
}
