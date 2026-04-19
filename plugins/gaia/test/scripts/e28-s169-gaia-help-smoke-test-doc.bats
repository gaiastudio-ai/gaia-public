#!/usr/bin/env bats
# e28-s169-gaia-help-smoke-test-doc.bats — bats tests for /gaia-migrate prose
# addition (E28-S169).
#
# Story E28-S169: Document /gaia-help manual smoke-test in /gaia-migrate
# when_to_use prose. After /gaia-migrate apply, users need to manually run
# /gaia-help to confirm the post-migration plugin install is wired up —
# filesystem-only validation cannot exercise skill invocation.

PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SKILL="$PLUGIN_DIR/skills/gaia-migrate/SKILL.md"

@test "E28-S169: AC1 gaia-migrate SKILL.md references /gaia-help as a manual smoke-test" {
  [ -f "$SKILL" ]
  grep -qE '/gaia-help' "$SKILL"
}

@test "E28-S169: AC1 prose instructs user to run /gaia-help AFTER /gaia-migrate apply" {
  [ -f "$SKILL" ]
  # Expect the instruction to live near the apply step context, pairing the
  # two commands in close proximity (on the same line or within the same
  # sentence).
  grep -qiE '(after|once).{0,80}(apply|migrat).{0,160}/gaia-help|/gaia-help.{0,160}(after|once).{0,80}(apply|migrat)' "$SKILL"
}

@test "E28-S169: AC2 prose explains why (filesystem-only validation cannot exercise skill invocation)" {
  [ -f "$SKILL" ]
  # The rationale must mention that the script's filesystem validation does
  # not (or cannot) exercise skill invocation — i.e., only running a real
  # slash-command invocation proves the install works end-to-end.
  grep -qiE 'filesystem(-only)?[^.]*(validation|check)[^.]*(cannot|does not|can not)[^.]*(skill|invocation|invoke)|(cannot|does not)[^.]*exercise[^.]*skill[^.]*invocation' "$SKILL"
}

@test "E28-S169: AC1 reference to /gaia-help appears in when_to_use frontmatter prose" {
  [ -f "$SKILL" ]
  # The when_to_use field is either (a) a single line in frontmatter, or (b)
  # expanded into a body section — the story title specifies when_to_use
  # prose, so /gaia-help MUST appear in the when_to_use block (frontmatter
  # line OR "## When to use" section).
  awk '
    BEGIN { in_fm=0; fm_done=0; in_wtu_section=0; found=0 }
    /^---[[:space:]]*$/ {
      if (in_fm==0 && fm_done==0) { in_fm=1; next }
      else if (in_fm==1) { in_fm=0; fm_done=1; next }
    }
    in_fm==1 && /^when_to_use:/ { if ($0 ~ /\/gaia-help/) found=1 }
    /^##[[:space:]]+[Ww]hen to use/ { in_wtu_section=1; next }
    in_wtu_section==1 && /^##[[:space:]]/ { in_wtu_section=0 }
    in_wtu_section==1 && /\/gaia-help/ { found=1 }
    END { exit (found==1 ? 0 : 1) }
  ' "$SKILL"
}
