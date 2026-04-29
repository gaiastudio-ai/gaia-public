#!/usr/bin/env bats
# frontmatter-lib.bats — coverage for skills/gaia-dev-story/scripts/frontmatter-lib.sh
#
# Story: E64-S1 — Dev-story tooling quirks cleanup
# AC: AC3 (shared frontmatter helper), AC-EC3 (canonical error on malformed frontmatter)
# TC: TC-E64-6, TC-E64-7

load 'test_helper.bash'

setup() {
  common_setup
  FRONTMATTER_LIB="$(cd "$BATS_TEST_DIRNAME/../skills/gaia-dev-story/scripts" && pwd)/frontmatter-lib.sh"
  cd "$TEST_TMP"
}

teardown() { common_teardown; }

# ---------------------------------------------------------------------------
# Sanity — the lib file exists and is sourceable
# ---------------------------------------------------------------------------

@test "frontmatter-lib: file exists" {
  [ -f "$FRONTMATTER_LIB" ]
}

@test "frontmatter-lib: source does not execute side effects" {
  bash -c "set -euo pipefail; source '$FRONTMATTER_LIB'; type fm_slice >/dev/null; type fm_get_field >/dev/null"
}

# ---------------------------------------------------------------------------
# AC3 / TC-E64-6 — fm_get_field happy path
# ---------------------------------------------------------------------------

@test "frontmatter-lib: fm_get_field returns the value of an existing field" {
  cat > story.md <<'EOF'
---
template: 'story'
key: "E64-S1"
title: "Test Story"
status: ready-for-dev
risk: "low"
---

# Body
EOF
  out="$(bash -c "source '$FRONTMATTER_LIB'; fm_slice 'story.md' | fm_get_field key")"
  [ "$out" = "E64-S1" ]
}

@test "frontmatter-lib: fm_get_field strips double quotes" {
  cat > story.md <<'EOF'
---
key: "E64-S1"
title: "Hello world"
---
EOF
  out="$(bash -c "source '$FRONTMATTER_LIB'; fm_slice 'story.md' | fm_get_field title")"
  [ "$out" = "Hello world" ]
}

@test "frontmatter-lib: fm_get_field strips single quotes" {
  cat > story.md <<'EOF'
---
template: 'story'
key: 'E64-S1'
---
EOF
  out="$(bash -c "source '$FRONTMATTER_LIB'; fm_slice 'story.md' | fm_get_field template")"
  [ "$out" = "story" ]
}

@test "frontmatter-lib: fm_get_field returns empty string for missing field" {
  cat > story.md <<'EOF'
---
key: "E64-S1"
---
EOF
  out="$(bash -c "source '$FRONTMATTER_LIB'; fm_slice 'story.md' | fm_get_field nonexistent")"
  [ -z "$out" ]
}

# ---------------------------------------------------------------------------
# AC-EC3 / TC-E64-7 — canonical error on malformed frontmatter
# ---------------------------------------------------------------------------

@test "frontmatter-lib: fm_slice fails on missing closing --- marker" {
  cat > story.md <<'EOF'
---
key: "E64-S1"
title: "No closing marker"

# Body without closing fence
EOF
  run bash -c "source '$FRONTMATTER_LIB'; fm_slice 'story.md'"
  [ "$status" -ne 0 ]
}

@test "frontmatter-lib: fm_slice fails on missing opening --- marker" {
  cat > story.md <<'EOF'
key: "E64-S1"

# Plain markdown, no frontmatter at all
EOF
  run bash -c "source '$FRONTMATTER_LIB'; fm_slice 'story.md'"
  [ "$status" -ne 0 ]
}

@test "frontmatter-lib: fm_slice fails on missing file" {
  run bash -c "source '$FRONTMATTER_LIB'; fm_slice 'does-not-exist.md'"
  [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# Edge — CRLF line endings
# ---------------------------------------------------------------------------

@test "frontmatter-lib: fm_get_field handles CRLF line endings" {
  printf -- '---\r\nkey: "E64-S1"\r\ntitle: "CRLF"\r\n---\r\n\r\n# Body\r\n' > story.md
  out="$(bash -c "source '$FRONTMATTER_LIB'; fm_slice 'story.md' | fm_get_field key")"
  [ "$out" = "E64-S1" ]
}

# ---------------------------------------------------------------------------
# Behavior preservation — leading whitespace in field
# ---------------------------------------------------------------------------

@test "frontmatter-lib: fm_get_field handles leading whitespace before key" {
  cat > story.md <<'EOF'
---
  key: "E64-S1"
  title: "Indented"
---
EOF
  out="$(bash -c "source '$FRONTMATTER_LIB'; fm_slice 'story.md' | fm_get_field key")"
  [ "$out" = "E64-S1" ]
}
