#!/usr/bin/env bats
# e20-s19-verify-pr-merged.bats — regression tests for verify-pr-merged.sh (E20-S19)
#
# Covers:
#   AC1 — Gate checks git log for merge commit containing story key on target branch
#   AC2 — Gate failure triggers exit 2 (re-run signal) when no merge commit found
#   AC3 — Regression: "done but no push" (E17-S1) and "done but no PR/merge" (E28-S213)
#   AC4 — Gate documented in SKILL.md (structural test)
#
# Exit code contract:
#   0 — merge commit found on target branch (gate passes)
#   1 — usage/argument error
#   2 — no merge commit found (gate fails, orchestrator should re-run Steps 10-13)
#   3 — no promotion chain configured (gate skips silently)

PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SCRIPT="$PLUGIN_DIR/skills/gaia-dev-story/scripts/verify-pr-merged.sh"
SKILL_MD="$PLUGIN_DIR/skills/gaia-dev-story/SKILL.md"

setup() {
  TMP="$(mktemp -d)"
  export PROJECT_PATH="$TMP/repo"
  mkdir -p "$PROJECT_PATH"

  # Initialize a git repo with a target branch
  cd "$PROJECT_PATH"
  git init -q
  git config user.email "test@example.com"
  git config user.name "Test"
  git commit --allow-empty -m "init" -q
  git branch -M main
}

teardown() {
  rm -rf "$TMP"
}

# ---------- AC1: Happy path — merge commit present on target branch ----------

@test "AC1: exits 0 when merge commit with story key exists on target branch" {
  cd "$PROJECT_PATH"
  # Simulate a squash-merge commit containing the story key
  git commit --allow-empty -m "feat(gate): add post-completion gate (E20-S19)" -q
  run "$SCRIPT" E20-S19 main
  [ "$status" -eq 0 ]
}

@test "AC1: exits 0 when squash commit contains story key in message body" {
  cd "$PROJECT_PATH"
  git commit --allow-empty -m "feat: implement story
Story: E20-S19" -q
  run "$SCRIPT" E20-S19 main
  [ "$status" -eq 0 ]
}

@test "AC1: case-insensitive match finds story key" {
  cd "$PROJECT_PATH"
  git commit --allow-empty -m "Merge pull request #42 from feat/e20-s19-gate" -q
  run "$SCRIPT" E20-S19 main
  [ "$status" -eq 0 ]
}

# ---------- AC2: Gate failure — no merge commit found ----------

@test "AC2: exits 2 when no commit with story key exists on target branch" {
  cd "$PROJECT_PATH"
  git commit --allow-empty -m "unrelated commit" -q
  run "$SCRIPT" E20-S19 main
  [ "$status" -eq 2 ]
}

@test "AC2: stderr contains actionable message on gate failure" {
  cd "$PROJECT_PATH"
  git commit --allow-empty -m "unrelated commit" -q
  run "$SCRIPT" E20-S19 main
  [[ "$output" == *"no merge commit"* ]] || [[ "$output" == *"not found"* ]]
}

# ---------- AC3: Regression — E17-S1 failure mode (done but no push) ----------

@test "AC3-a: detects missing merge when subagent returned done but never pushed (E17-S1)" {
  cd "$PROJECT_PATH"
  # Target branch has only the init commit — no story-related commits at all
  run "$SCRIPT" E17-S1 main
  [ "$status" -eq 2 ]
}

# ---------- AC3: Regression — E28-S213 failure mode (done but no PR/merge) ----------

@test "AC3-b: detects missing merge when commits exist on feature branch but not on target (E28-S213)" {
  cd "$PROJECT_PATH"
  # Create a feature branch with story commits, but target branch has none
  git checkout -b feat/E28-S213-review -q
  git commit --allow-empty -m "feat: implement story E28-S213" -q
  git checkout main -q
  # Target branch (main) has no E28-S213 commits
  run "$SCRIPT" E28-S213 main
  [ "$status" -eq 2 ]
}

# ---------- Scenario 4: No promotion chain (exit 3 = skip) ----------

@test "SC4: exits 3 when --no-chain flag is passed (no promotion chain configured)" {
  run "$SCRIPT" E20-S19 --no-chain
  [ "$status" -eq 3 ]
}

# ---------- Scenario 5: Squash merge detection ----------

@test "SC5: detects squash merge commit with story key in --no-merges log" {
  cd "$PROJECT_PATH"
  # Non-merge commit (squash merge style) with story key
  git commit --allow-empty -m "E20-S19: add post-completion gate (#42)" -q
  run "$SCRIPT" E20-S19 main
  [ "$status" -eq 0 ]
}

# ---------- Usage / argument errors ----------

@test "exits 1 with usage message when called with no arguments" {
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"usage"* ]]
}

@test "exits 1 with usage message when called with one argument only" {
  run "$SCRIPT" E20-S19
  [ "$status" -eq 1 ]
  [[ "$output" == *"usage"* ]]
}

# ---------- Word-boundary matching (Val WARNING #2 mitigation) ----------

@test "does not false-positive on partial key match (E20-S1 vs E20-S19)" {
  cd "$PROJECT_PATH"
  git commit --allow-empty -m "feat: implement E20-S1 changes" -q
  run "$SCRIPT" E20-S19 main
  [ "$status" -eq 2 ]
}

@test "does not false-positive on key embedded in longer key (E20-S190)" {
  cd "$PROJECT_PATH"
  git commit --allow-empty -m "feat: implement E20-S190 changes" -q
  run "$SCRIPT" E20-S19 main
  [ "$status" -eq 2 ]
}

# ---------- AC4: SKILL.md documentation gate ----------

@test "AC4: SKILL.md contains Post-Completion Gate section" {
  run grep -c "Post-Completion Gate" "$SKILL_MD"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "AC4: SKILL.md Post-Completion Gate references verify-pr-merged.sh" {
  run grep -c "verify-pr-merged.sh" "$SKILL_MD"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "AC4: SKILL.md Post-Completion Gate documents E17-S1 failure mode" {
  run grep -c "E17-S1" "$SKILL_MD"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "AC4: SKILL.md Post-Completion Gate documents E28-S213 failure mode" {
  run grep -c "E28-S213" "$SKILL_MD"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "verify-pr-merged.sh exists and is executable" {
  [ -x "$SCRIPT" ]
}
