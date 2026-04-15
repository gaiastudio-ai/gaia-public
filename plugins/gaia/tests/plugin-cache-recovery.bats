#!/usr/bin/env bats
# plugin-cache-recovery.bats — unit tests for plugin-cache-recovery.sh.
# (The story's foundation-script list calls this out as S16 family;
# including it keeps the bats suite covering every script under
# plugins/gaia/scripts/ per NFR-052.)
# Public functions covered: validate_slug, classify_entry, mode_list,
# mode_detect, mode_clear, main.

load 'test_helper.bash'

setup() {
  common_setup
  SCRIPT="$SCRIPTS_DIR/plugin-cache-recovery.sh"
  CACHE="$TEST_TMP/cache"
  mkdir -p "$CACHE"
}
teardown() { common_teardown; }

make_polluted() { mkdir -p "$CACHE/$1"; : > "$CACHE/$1/partial.tar"; }
make_healthy() {
  mkdir -p "$CACHE/$1/.git"
  printf 'ref: refs/heads/main\n' > "$CACHE/$1/.git/HEAD"
  : > "$CACHE/$1/README.md"
}
make_empty() { mkdir -p "$CACHE/$1"; }

@test "plugin-cache-recovery.sh: --help exits 0" {
  run "$SCRIPT" --help
  [ "$status" -eq 0 ]
}

@test "plugin-cache-recovery.sh: missing --slug exits 1" {
  run "$SCRIPT"
  [ "$status" -eq 1 ]
}

@test "plugin-cache-recovery.sh: slash in slug rejected" {
  run "$SCRIPT" --slug "evil/../../etc" --cache-root "$CACHE"
  [ "$status" -eq 1 ]
}

@test "plugin-cache-recovery.sh: leading-dash slug rejected" {
  run "$SCRIPT" --slug "-bad" --cache-root "$CACHE"
  [ "$status" -eq 1 ]
}

@test "plugin-cache-recovery.sh: double-dot slug rejected" {
  run "$SCRIPT" --slug ".." --cache-root "$CACHE"
  [ "$status" -eq 1 ]
}

@test "plugin-cache-recovery.sh: space in slug rejected" {
  run "$SCRIPT" --slug "has space" --cache-root "$CACHE"
  [ "$status" -eq 1 ]
}

@test "plugin-cache-recovery.sh: absent entry — clear is a no-op exit 0" {
  run "$SCRIPT" --slug "owner-repo" --cache-root "$CACHE" --quiet
  [ "$status" -eq 0 ]
}

@test "plugin-cache-recovery.sh: detect on empty dir → exit 2 (polluted)" {
  make_empty "owner-repo"
  run "$SCRIPT" --detect --slug "owner-repo" --cache-root "$CACHE" --quiet
  [ "$status" -eq 2 ]
}

@test "plugin-cache-recovery.sh: clear removes polluted empty dir" {
  make_empty "owner-repo"
  run "$SCRIPT" --slug "owner-repo" --cache-root "$CACHE" --quiet
  [ "$status" -eq 0 ]
  [ ! -e "$CACHE/owner-repo" ]
}

@test "plugin-cache-recovery.sh: dry-run preserves polluted entry" {
  make_polluted "owner-repo"
  run "$SCRIPT" --slug "owner-repo" --cache-root "$CACHE" --dry-run --quiet
  [ "$status" -eq 0 ]
  [ -e "$CACHE/owner-repo" ]
}

@test "plugin-cache-recovery.sh: detect healthy entry → exit 0" {
  make_healthy "owner-repo"
  run "$SCRIPT" --detect --slug "owner-repo" --cache-root "$CACHE" --quiet
  [ "$status" -eq 0 ]
}

@test "plugin-cache-recovery.sh: clear refuses healthy entry without --force" {
  make_healthy "owner-repo"
  run "$SCRIPT" --slug "owner-repo" --cache-root "$CACHE" --quiet
  [ "$status" -eq 1 ]
  [ -e "$CACHE/owner-repo/.git/HEAD" ]
}

@test "plugin-cache-recovery.sh: --force clears healthy entry" {
  make_healthy "owner-repo"
  run "$SCRIPT" --slug "owner-repo" --cache-root "$CACHE" --force --quiet
  [ "$status" -eq 0 ]
  [ ! -e "$CACHE/owner-repo" ]
}

@test "plugin-cache-recovery.sh: --list on absent root exits 0" {
  run "$SCRIPT" --list --cache-root "$TEST_TMP/nope" --quiet
  [ "$status" -eq 0 ]
}

@test "plugin-cache-recovery.sh: --list reports all entries" {
  make_polluted "owner-a"
  make_healthy  "owner-b"
  run "$SCRIPT" --list --cache-root "$CACHE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"owner-a"* ]]
  [[ "$output" == *"owner-b"* ]]
}

@test "plugin-cache-recovery.sh: unknown flag rejected" {
  run "$SCRIPT" --slug "owner-repo" --cache-root "$CACHE" --banana
  [ "$status" -eq 1 ]
}
