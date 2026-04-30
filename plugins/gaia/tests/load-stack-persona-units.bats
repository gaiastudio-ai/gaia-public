#!/usr/bin/env bats
# load-stack-persona-units.bats — unit coverage for load-stack-persona.sh helpers (NFR-052)
#
# Public-function direct unit tests for load-stack-persona.sh:
#   - canonical_to_filename
#   - detect_stack_from_files
#
# Helpers are sourced via awk-extracted bodies so the script's CLI parsing
# and main pipeline does not execute. Behavioural coverage lives in
# load-stack-persona.bats.

load 'test_helper.bash'

bats_require_minimum_version 1.5.0

setup() {
  common_setup
  SCRIPT="$SCRIPTS_DIR/load-stack-persona.sh"
}
teardown() { common_teardown; }

_load_helpers() {
  local tmp
  tmp="$(mktemp -t persona-helpers.XXXXXX)"
  awk '
    /^canonical_to_filename\(\) \{/,/^\}/ { print; next }
    /^detect_stack_from_files\(\) \{/,/^\}/ { print; next }
  ' "$SCRIPT" > "$tmp"
  # shellcheck disable=SC1090
  source "$tmp"
  rm -f "$tmp"
}

# ---------------------------------------------------------------------------
# canonical_to_filename
# ---------------------------------------------------------------------------

@test "canonical_to_filename: ts-dev -> typescript-dev.md" {
  _load_helpers
  got="$(canonical_to_filename ts-dev)"
  [ "$got" = "typescript-dev.md" ]
}

@test "canonical_to_filename: java-dev -> java-dev.md" {
  _load_helpers
  got="$(canonical_to_filename java-dev)"
  [ "$got" = "java-dev.md" ]
}

@test "canonical_to_filename: python-dev -> python-dev.md" {
  _load_helpers
  got="$(canonical_to_filename python-dev)"
  [ "$got" = "python-dev.md" ]
}

@test "canonical_to_filename: go-dev -> go-dev.md" {
  _load_helpers
  got="$(canonical_to_filename go-dev)"
  [ "$got" = "go-dev.md" ]
}

@test "canonical_to_filename: flutter-dev -> flutter-dev.md" {
  _load_helpers
  got="$(canonical_to_filename flutter-dev)"
  [ "$got" = "flutter-dev.md" ]
}

@test "canonical_to_filename: mobile-dev -> mobile-dev.md" {
  _load_helpers
  got="$(canonical_to_filename mobile-dev)"
  [ "$got" = "mobile-dev.md" ]
}

@test "canonical_to_filename: angular-dev -> angular-dev.md" {
  _load_helpers
  got="$(canonical_to_filename angular-dev)"
  [ "$got" = "angular-dev.md" ]
}

@test "canonical_to_filename: unknown stack returns non-zero" {
  _load_helpers
  run canonical_to_filename "no-such-stack"
  [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# detect_stack_from_files
# ---------------------------------------------------------------------------

@test "detect_stack_from_files: angular.json -> angular-dev" {
  _load_helpers
  local root="$TEST_TMP/proj-ng"; mkdir -p "$root"
  : > "$root/angular.json"
  got="$(detect_stack_from_files "$root")"
  [ "$got" = "angular-dev" ]
}

@test "detect_stack_from_files: pubspec.yaml -> flutter-dev" {
  _load_helpers
  local root="$TEST_TMP/proj-flutter"; mkdir -p "$root"
  : > "$root/pubspec.yaml"
  got="$(detect_stack_from_files "$root")"
  [ "$got" = "flutter-dev" ]
}

@test "detect_stack_from_files: go.mod -> go-dev" {
  _load_helpers
  local root="$TEST_TMP/proj-go"; mkdir -p "$root"
  : > "$root/go.mod"
  got="$(detect_stack_from_files "$root")"
  [ "$got" = "go-dev" ]
}

@test "detect_stack_from_files: pom.xml -> java-dev" {
  _load_helpers
  local root="$TEST_TMP/proj-java"; mkdir -p "$root"
  : > "$root/pom.xml"
  got="$(detect_stack_from_files "$root")"
  [ "$got" = "java-dev" ]
}

@test "detect_stack_from_files: requirements.txt -> python-dev" {
  _load_helpers
  local root="$TEST_TMP/proj-py"; mkdir -p "$root"
  : > "$root/requirements.txt"
  got="$(detect_stack_from_files "$root")"
  [ "$got" = "python-dev" ]
}

@test "detect_stack_from_files: tsconfig.json -> ts-dev" {
  _load_helpers
  local root="$TEST_TMP/proj-ts"; mkdir -p "$root"
  echo '{}' > "$root/tsconfig.json"
  got="$(detect_stack_from_files "$root")"
  [ "$got" = "ts-dev" ]
}

@test "detect_stack_from_files: AndroidManifest.xml under app/src/main -> mobile-dev" {
  _load_helpers
  local root="$TEST_TMP/proj-android"; mkdir -p "$root/app/src/main"
  : > "$root/app/src/main/AndroidManifest.xml"
  got="$(detect_stack_from_files "$root")"
  [ "$got" = "mobile-dev" ]
}

@test "detect_stack_from_files: angular.json takes precedence over package.json" {
  _load_helpers
  local root="$TEST_TMP/proj-mixed"; mkdir -p "$root"
  : > "$root/angular.json"
  echo '{}' > "$root/package.json"
  got="$(detect_stack_from_files "$root")"
  [ "$got" = "angular-dev" ]
}

@test "detect_stack_from_files: empty project returns non-zero" {
  _load_helpers
  local root="$TEST_TMP/proj-empty"; mkdir -p "$root"
  run detect_stack_from_files "$root"
  [ "$status" -ne 0 ]
}
