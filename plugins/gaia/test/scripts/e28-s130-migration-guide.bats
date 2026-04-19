#!/usr/bin/env bats
# e28-s130-migration-guide.bats — bats tests for the v1 to v2 migration guide (E28-S130)
#
# Asserts the guide structure (9 sections), required content (two-track procedure,
# Reviewer Orientation, preserved Legacy engine cleanup subsection from E28-S126),
# and the project-root pointer file existence.

PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
GAIA_PUBLIC="$(cd "$PLUGIN_DIR/../.." && pwd)"
PROJECT_ROOT="$(cd "$GAIA_PUBLIC/.." && pwd)"
GUIDE="$GAIA_PUBLIC/docs/migration-guide-v2.md"
POINTER="$PROJECT_ROOT/docs/migration/migration-guide-v2.md"

@test "E28-S130: gaia-public/docs/migration-guide-v2.md exists" {
  [ -f "$GUIDE" ]
}

@test "E28-S130: project-root docs/migration/migration-guide-v2.md pointer exists" {
  [ -f "$POINTER" ]
}

@test "E28-S130: AC2 contains Prerequisites section" {
  [ -f "$GUIDE" ] || skip "guide not yet present"
  grep -qE '^## .*Prerequisites' "$GUIDE"
}

@test "E28-S130: AC2 contains Backup section" {
  [ -f "$GUIDE" ] || skip "guide not yet present"
  grep -qE '^## .*Backup' "$GUIDE"
}

@test "E28-S130: AC2 contains Install section" {
  [ -f "$GUIDE" ] || skip "guide not yet present"
  grep -qE '^## .*Install' "$GUIDE"
}

@test "E28-S130: AC2 contains Migrate Templates section" {
  [ -f "$GUIDE" ] || skip "guide not yet present"
  grep -qE '^## .*Migrate Templates' "$GUIDE"
}

@test "E28-S130: AC2 contains Migrate Memory section" {
  [ -f "$GUIDE" ] || skip "guide not yet present"
  grep -qE '^## .*Migrate Memory' "$GUIDE"
}

@test "E28-S130: AC2 contains Update CLAUDE.md section" {
  [ -f "$GUIDE" ] || skip "guide not yet present"
  grep -qE '^## .*Update CLAUDE\.md' "$GUIDE"
}

@test "E28-S130: contains Verify section (anchors E28-S126 cleanup subsection)" {
  [ -f "$GUIDE" ] || skip "guide not yet present"
  grep -qE '^## .*Verify' "$GUIDE"
}

@test "E28-S130: AC3 contains Rollback section" {
  [ -f "$GUIDE" ] || skip "guide not yet present"
  grep -qE '^## .*Rollback' "$GUIDE"
}

@test "E28-S130: AC-EC9 contains Reviewer Orientation appendix" {
  [ -f "$GUIDE" ] || skip "guide not yet present"
  grep -qE '^## .*Reviewer Orientation' "$GUIDE"
}

@test "E28-S130: E28-S126 'Legacy engine cleanup' subsection preserved verbatim" {
  [ -f "$GUIDE" ] || skip "guide not yet present"
  grep -qE '^### Legacy engine cleanup' "$GUIDE"
}

@test "E28-S130: AC4/AC-EC2 contains Track A heading" {
  [ -f "$GUIDE" ] || skip "guide not yet present"
  grep -qE '^### Track A' "$GUIDE"
}

@test "E28-S130: AC4/AC-EC2 contains Track B heading" {
  [ -f "$GUIDE" ] || skip "guide not yet present"
  grep -qE '^### Track B' "$GUIDE"
}

@test "E28-S130: AC-EC9 Reviewer Orientation references ADR-041" {
  [ -f "$GUIDE" ] || skip "guide not yet present"
  awk '/^## .*Reviewer Orientation/{flag=1; next} flag && /^## /{flag=0} flag' "$GUIDE" | grep -q 'ADR-041'
}

@test "E28-S130: AC-EC9 Reviewer Orientation references ADR-048" {
  [ -f "$GUIDE" ] || skip "guide not yet present"
  awk '/^## .*Reviewer Orientation/{flag=1; next} flag && /^## /{flag=0} flag' "$GUIDE" | grep -q 'ADR-048'
}

@test "E28-S130: AC-EC10 Prerequisites mentions plugin marketplace list check" {
  [ -f "$GUIDE" ] || skip "guide not yet present"
  awk '/^## .*Prerequisites/{flag=1; next} flag && /^## /{flag=0} flag' "$GUIDE" | grep -q 'marketplace list'
}

@test "E28-S130: AC3/AC-EC5 Rollback section first action is STOP" {
  [ -f "$GUIDE" ] || skip "guide not yet present"
  awk '/^## .*Rollback/{flag=1; next} flag && /^## /{flag=0} flag' "$GUIDE" | grep -m1 -E '^\*\*S[0-9]+\.[0-9]+' | grep -qi 'STOP'
}

@test "E28-S130: pointer file links to canonical gaia-public location" {
  [ -f "$POINTER" ] || skip "pointer not yet present"
  grep -q 'gaia-public/docs/migration-guide-v2.md' "$POINTER"
}
