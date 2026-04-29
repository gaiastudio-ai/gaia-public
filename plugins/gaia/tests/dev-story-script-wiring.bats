#!/usr/bin/env bats
# dev-story-script-wiring.bats — bats coverage for E57-S8
#
# Story: E57-S8 — SKILL.md script wiring (Steps 1, 10, 11) + narrative-fallback retention
#
# Acceptance Criteria covered:
#   AC1 — Step 1 invokes story-parse.sh, detect-mode.sh, check-deps.sh and
#         contains a narrative-fallback block (TC-DSS-09).
#   AC2 — Step 10 invokes promotion-chain-guard.sh at the top of the CI section
#         AND commit-msg.sh in the commit subsection (TC-DSS-09).
#   AC3 — Step 11 documents that pr-create.sh reads its body from
#         pr-body.sh output (TC-DSS-09).
#   AC5 — Regression: re-introducing inline LLM frontmatter parsing or inline
#         PR body construction causes this test to FAIL naming the offending
#         step (TC-DSS-10).
#
# Refs: FR-DSS-1..6, AF-2026-04-28-6.

load 'test_helper.bash'

setup() {
  common_setup
  SKILL_MD="$(cd "$BATS_TEST_DIRNAME/../skills/gaia-dev-story" && pwd)/SKILL.md"
  export SKILL_MD
  [ -f "$SKILL_MD" ] || { echo "SKILL.md not found at $SKILL_MD" >&2; return 1; }
}

teardown() { common_teardown; }

# ---------------------------------------------------------------------------
# Marker pairs — each wired step has begin/end HTML comment markers so
# regression failures name the offending step.
# ---------------------------------------------------------------------------

@test "AC5: Step 1 script-wiring marker pair is present" {
  run grep -c '<!-- E57-S8: step1 script-wiring begin -->' "$SKILL_MD"
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
  run grep -c '<!-- E57-S8: step1 script-wiring end -->' "$SKILL_MD"
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}

@test "AC5: Step 10 script-wiring marker pair is present" {
  run grep -c '<!-- E57-S8: step10 script-wiring begin -->' "$SKILL_MD"
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
  run grep -c '<!-- E57-S8: step10 script-wiring end -->' "$SKILL_MD"
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}

@test "AC5: Step 11 script-wiring marker pair is present" {
  run grep -c '<!-- E57-S8: step11 script-wiring begin -->' "$SKILL_MD"
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
  run grep -c '<!-- E57-S8: step11 script-wiring end -->' "$SKILL_MD"
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}

# ---------------------------------------------------------------------------
# AC1 — Step 1 invokes story-parse.sh, detect-mode.sh, check-deps.sh and
# contains a narrative-fallback block.
# ---------------------------------------------------------------------------

@test "AC1: Step 1 block invokes story-parse.sh" {
  block="$(awk '/<!-- E57-S8: step1 script-wiring begin -->/,/<!-- E57-S8: step1 script-wiring end -->/' "$SKILL_MD")"
  [ -n "$block" ]
  echo "$block" | grep -Fq 'story-parse.sh'
}

@test "AC1: Step 1 block invokes detect-mode.sh" {
  block="$(awk '/<!-- E57-S8: step1 script-wiring begin -->/,/<!-- E57-S8: step1 script-wiring end -->/' "$SKILL_MD")"
  [ -n "$block" ]
  echo "$block" | grep -Fq 'detect-mode.sh'
}

@test "AC1: Step 1 block invokes check-deps.sh" {
  block="$(awk '/<!-- E57-S8: step1 script-wiring begin -->/,/<!-- E57-S8: step1 script-wiring end -->/' "$SKILL_MD")"
  [ -n "$block" ]
  echo "$block" | grep -Fq 'check-deps.sh'
}

@test "AC1: Step 1 block contains a Narrative Fallback section" {
  block="$(awk '/<!-- E57-S8: step1 script-wiring begin -->/,/<!-- E57-S8: step1 script-wiring end -->/' "$SKILL_MD")"
  [ -n "$block" ]
  echo "$block" | grep -Fq 'Narrative Fallback'
  # The fallback is gated on the absence of the new script via `command -v`.
  echo "$block" | grep -Fq 'command -v story-parse.sh'
}

# ---------------------------------------------------------------------------
# AC2 — Step 10 invokes promotion-chain-guard.sh at the top of the CI section
# AND commit-msg.sh in the commit subsection.
# ---------------------------------------------------------------------------

@test "AC2: Step 10 block invokes promotion-chain-guard.sh" {
  block="$(awk '/<!-- E57-S8: step10 script-wiring begin -->/,/<!-- E57-S8: step10 script-wiring end -->/' "$SKILL_MD")"
  [ -n "$block" ]
  echo "$block" | grep -Fq 'promotion-chain-guard.sh'
}

@test "AC2: Step 10 block invokes commit-msg.sh" {
  block="$(awk '/<!-- E57-S8: step10 script-wiring begin -->/,/<!-- E57-S8: step10 script-wiring end -->/' "$SKILL_MD")"
  [ -n "$block" ]
  echo "$block" | grep -Fq 'commit-msg.sh'
}

@test "AC2: Step 10 block contains a Narrative Fallback section" {
  block="$(awk '/<!-- E57-S8: step10 script-wiring begin -->/,/<!-- E57-S8: step10 script-wiring end -->/' "$SKILL_MD")"
  [ -n "$block" ]
  echo "$block" | grep -Fq 'Narrative Fallback'
  echo "$block" | grep -Fq 'command -v commit-msg.sh'
}

@test "AC2: promotion-chain-guard.sh appears BEFORE commit-msg.sh inside Step 10 block" {
  block="$(awk '/<!-- E57-S8: step10 script-wiring begin -->/,/<!-- E57-S8: step10 script-wiring end -->/' "$SKILL_MD")"
  [ -n "$block" ]
  guard_off="$(printf '%s\n' "$block" | grep -boF 'promotion-chain-guard.sh' | head -1 | cut -d: -f1)"
  msg_off="$(printf '%s\n' "$block" | grep -boF 'commit-msg.sh' | head -1 | cut -d: -f1)"
  [ -n "$guard_off" ] && [ -n "$msg_off" ]
  [ "$guard_off" -lt "$msg_off" ]
}

# ---------------------------------------------------------------------------
# AC3 — Step 11 documents that pr-create.sh reads its body from pr-body.sh.
# ---------------------------------------------------------------------------

@test "AC3: Step 11 block invokes pr-body.sh" {
  block="$(awk '/<!-- E57-S8: step11 script-wiring begin -->/,/<!-- E57-S8: step11 script-wiring end -->/' "$SKILL_MD")"
  [ -n "$block" ]
  echo "$block" | grep -Fq 'pr-body.sh'
}

@test "AC3: Step 11 block references pr-create.sh" {
  block="$(awk '/<!-- E57-S8: step11 script-wiring begin -->/,/<!-- E57-S8: step11 script-wiring end -->/' "$SKILL_MD")"
  [ -n "$block" ]
  echo "$block" | grep -Fq 'pr-create.sh'
}

@test "AC3: Step 11 block contains a Narrative Fallback section" {
  block="$(awk '/<!-- E57-S8: step11 script-wiring begin -->/,/<!-- E57-S8: step11 script-wiring end -->/' "$SKILL_MD")"
  [ -n "$block" ]
  echo "$block" | grep -Fq 'Narrative Fallback'
  echo "$block" | grep -Fq 'command -v pr-body.sh'
}

# ---------------------------------------------------------------------------
# Hook ordering — each script-wiring block must appear AFTER its
# corresponding step header. The Step N header precedes the matching marker.
# ---------------------------------------------------------------------------

@test "Step 1 wiring block follows Step 1 -- Load Story header" {
  step1_line="$(grep -n '^### Step 1 -- Load Story' "$SKILL_MD" | head -1 | cut -d: -f1)"
  hook_line="$(grep -n '<!-- E57-S8: step1 script-wiring begin -->' "$SKILL_MD" | head -1 | cut -d: -f1)"
  [ -n "$step1_line" ] && [ -n "$hook_line" ]
  [ "$hook_line" -gt "$step1_line" ]
}

@test "Step 10 wiring block follows Step 10 -- Commit and Push header" {
  step10_line="$(grep -n '^### Step 10 -- Commit and Push' "$SKILL_MD" | head -1 | cut -d: -f1)"
  hook_line="$(grep -n '<!-- E57-S8: step10 script-wiring begin -->' "$SKILL_MD" | head -1 | cut -d: -f1)"
  [ -n "$step10_line" ] && [ -n "$hook_line" ]
  [ "$hook_line" -gt "$step10_line" ]
}

@test "Step 11 wiring block follows Step 11 -- Create PR header" {
  step11_line="$(grep -n '^### Step 11 -- Create PR' "$SKILL_MD" | head -1 | cut -d: -f1)"
  hook_line="$(grep -n '<!-- E57-S8: step11 script-wiring begin -->' "$SKILL_MD" | head -1 | cut -d: -f1)"
  [ -n "$step11_line" ] && [ -n "$hook_line" ]
  [ "$hook_line" -gt "$step11_line" ]
}

# ---------------------------------------------------------------------------
# AC5 — Deprecation cadence: each fallback block names the v1.131.x → v1.132.0
# removal window so brownfield users can plan the upgrade.
# ---------------------------------------------------------------------------

@test "AC5: each fallback block names the v1.131.x deprecation cadence" {
  for marker in step1 step10 step11; do
    block="$(awk "/<!-- E57-S8: ${marker} script-wiring begin -->/,/<!-- E57-S8: ${marker} script-wiring end -->/" "$SKILL_MD")"
    [ -n "$block" ]
    echo "$block" | grep -Fq 'v1.131.x'
    echo "$block" | grep -Fq 'v1.132.0'
  done
}

# ---------------------------------------------------------------------------
# AC5 (TC-DSS-10) — Absence-assertion regression contract.
#
# The wiring blocks above prove the new scripts are PRESENT. AC5 also requires
# that the legacy LLM narrative is ABSENT outside the marker-fenced regions.
# A regression that re-introduces inline frontmatter parsing or inline PR-body
# construction (alongside, or in place of, the new script invocations) MUST
# cause this test to FAIL naming the offending step.
#
# Strategy: strip the three E57-S8 wiring blocks (begin..end inclusive) from
# SKILL.md, then grep the residue for legacy patterns. The Narrative Fallback
# subsections live INSIDE the wiring blocks, so they are not flagged.
# ---------------------------------------------------------------------------

# Emit SKILL.md with all three E57-S8 wiring blocks removed (begin..end inclusive).
_skill_md_minus_wiring_blocks() {
  awk '
    /<!-- E57-S8: step1 script-wiring begin -->/  { skip=1 }
    /<!-- E57-S8: step10 script-wiring begin -->/ { skip=1 }
    /<!-- E57-S8: step11 script-wiring begin -->/ { skip=1 }
    skip == 0 { print }
    /<!-- E57-S8: step1 script-wiring end -->/    { skip=0; next }
    /<!-- E57-S8: step10 script-wiring end -->/   { skip=0; next }
    /<!-- E57-S8: step11 script-wiring end -->/   { skip=0; next }
  ' "$SKILL_MD"
}

@test "AC5 absence: Step 1 — no inline frontmatter parsing outside wiring block" {
  residue="$(_skill_md_minus_wiring_blocks)"
  # Legacy inline narrative: 'Read the story file: extract' / 'Detect execution mode' / 'FRESH (new implementation)'.
  # Any of these outside the wiring block means a regression has re-introduced
  # the inline LLM frontmatter-parsing path that script-wiring replaced.
  if echo "$residue" | grep -nE 'Read the story file: extract|Detect execution mode|FRESH \(new implementation\)|REWORK \(fix review|RESUME \(continue from'; then
    echo "REGRESSION: Step 1 inline LLM frontmatter parsing re-introduced outside <!-- E57-S8: step1 script-wiring --> block." >&2
    echo "story-parse.sh + detect-mode.sh are the single source of truth (FR-DSS-1, FR-DSS-2)." >&2
    return 1
  fi
}

@test "AC5 absence: Step 10 — no inline commit-subject construction outside wiring block" {
  residue="$(_skill_md_minus_wiring_blocks)"
  # Legacy inline narrative: 'Conventional Commit' subject composition guidance, or
  # an inline 'git commit -m' usage that hand-crafts the subject. commit-msg.sh
  # is the single source of truth (FR-DSS-5, FR-DSS-6).
  if echo "$residue" | grep -nE 'Compose .*Conventional Commit subject|hand-craft.*commit subject|git commit -m "[^"]*\$\{?story_key\}?'; then
    echo "REGRESSION: Step 10 inline commit-subject composition re-introduced outside <!-- E57-S8: step10 script-wiring --> block." >&2
    echo "commit-msg.sh is the single source of truth (FR-DSS-5, FR-DSS-6, NFR-DSS-1)." >&2
    return 1
  fi
}

@test "AC5 absence: Step 11 — no inline PR-body construction outside wiring block" {
  residue="$(_skill_md_minus_wiring_blocks)"
  # Legacy inline narrative: heredoc-built PR body fed straight to gh, or
  # 'pr-create.sh ... --body "$(cat <<' inline-body construction. pr-body.sh is
  # the single source of truth (FR-DSS-5, FR-DSS-6).
  if echo "$residue" | grep -nE 'gh pr create .*--body "\$\(cat <<|pr-create\.sh.*--body "\$\(cat <<|Compose the PR body inline|hand-craft the PR body'; then
    echo "REGRESSION: Step 11 inline PR-body construction re-introduced outside <!-- E57-S8: step11 script-wiring --> block." >&2
    echo "pr-body.sh is the single source of truth (FR-DSS-5, FR-DSS-6)." >&2
    return 1
  fi
}

@test "AC5 absence: residue still names every wired step (sanity — strip didn't eat the world)" {
  residue="$(_skill_md_minus_wiring_blocks)"
  # Sanity guard: if the awk strip ever over-deletes (e.g. a regex change drops
  # too much), this test fails loudly rather than silently passing the absence
  # checks above on an empty residue.
  echo "$residue" | grep -Fq '### Step 1 -- Load Story'
  echo "$residue" | grep -Fq '### Step 10 -- Commit and Push'
  echo "$residue" | grep -Fq '### Step 11 -- Create PR'
}
