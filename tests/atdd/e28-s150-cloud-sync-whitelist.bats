#!/usr/bin/env bats
# ATDD — E28-S150 Validate cloud sync whitelist
# Source: docs/implementation-artifacts/E28-S150-*.md
# ADR-046 "Hybrid Memory Loading" — decision-log.md and ground-truth.md are
# persisted/synced (git-tracked); conversation-context.md is ephemeral per-session
# (gitignored). Checkpoints and archive/ are also gitignored (architecture.md §5.1).

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  GITIGNORE="${REPO_ROOT}/.gitignore"
  MEM_DIR="${REPO_ROOT}/_memory"

  # Tier 1 agents (4): validator, architect, pm, sm — have ground-truth.md
  TIER1_AGENTS=(validator architect pm sm)

  # Tier 2 agents (per _memory/config.yaml) — have conversation-context.md but NOT ground-truth.md
  TIER2_AGENTS=(orchestrator security devops test-architect)

  # Tier 3 agents — decision-log.md only
  TIER3_AGENTS=(angular-dev typescript-dev flutter-dev java-dev python-dev mobile-dev)
}

# Helper — ensure a candidate file path exists so `git check-ignore` resolves
# deterministically for pattern matching. `git check-ignore` operates on the
# repository-relative path regardless of whether the file exists on disk, so
# we only create the placeholder when it's absent and do not pollute tracked
# content. The .gitignore rules we validate ensure these placeholders remain
# ignored (archive/ and conversation-context.md patterns).
ensure_path() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
  [ -f "$path" ] || touch "$path"
}

# Assert that a file path is NOT ignored (synced via cloud sync whitelist).
assert_synced() {
  local f="$1"
  ensure_path "$f"
  cd "$REPO_ROOT"
  run git check-ignore "$f"
  [ "$status" -eq 1 ]
}

# Assert that a file path IS ignored (local only / excluded from sync).
assert_excluded() {
  local f="$1"
  ensure_path "$f"
  cd "$REPO_ROOT"
  run git check-ignore "$f"
  [ "$status" -eq 0 ]
}

# --- AC1 — decision-log.md INCLUDED (not ignored) across all sidecars ------

@test "AC1: decision-log.md is synced for Tier 1 sm-sidecar" {
  [ -f "$GITIGNORE" ]
  assert_synced "${MEM_DIR}/sm-sidecar/decision-log.md"
}

@test "AC1: decision-log.md is synced for Tier 2 orchestrator-sidecar" {
  [ -f "$GITIGNORE" ]
  assert_synced "${MEM_DIR}/orchestrator-sidecar/decision-log.md"
}

@test "AC1: decision-log.md is synced for Tier 3 typescript-dev-sidecar" {
  [ -f "$GITIGNORE" ]
  assert_synced "${MEM_DIR}/typescript-dev-sidecar/decision-log.md"
}

# --- AC2 — ground-truth.md INCLUDED (not ignored) for Tier 1 --------------

@test "AC2: ground-truth.md is synced for Tier 1 validator-sidecar" {
  [ -f "$GITIGNORE" ]
  assert_synced "${MEM_DIR}/validator-sidecar/ground-truth.md"
}

@test "AC2: ground-truth.md is synced for Tier 1 architect-sidecar" {
  [ -f "$GITIGNORE" ]
  assert_synced "${MEM_DIR}/architect-sidecar/ground-truth.md"
}

@test "AC2: ground-truth.md is synced for Tier 1 pm-sidecar and sm-sidecar" {
  [ -f "$GITIGNORE" ]
  for agent in pm sm; do
    assert_synced "${MEM_DIR}/${agent}-sidecar/ground-truth.md"
  done
}

# --- AC3 — conversation-context.md EXCLUDED (ignored) across all tiers -----

@test "AC3: conversation-context.md is excluded for Tier 1 sm-sidecar" {
  [ -f "$GITIGNORE" ]
  assert_excluded "${MEM_DIR}/sm-sidecar/conversation-context.md"
}

@test "AC3: conversation-context.md is excluded for Tier 2 security-sidecar" {
  [ -f "$GITIGNORE" ]
  assert_excluded "${MEM_DIR}/security-sidecar/conversation-context.md"
}

@test "AC3: conversation-context.md is excluded uniformly across all Tier 1 and Tier 2 sidecars" {
  [ -f "$GITIGNORE" ]
  for agent in "${TIER1_AGENTS[@]}" "${TIER2_AGENTS[@]}"; do
    assert_excluded "${MEM_DIR}/${agent}-sidecar/conversation-context.md"
  done
}

# --- AC4 — whitelist documented and matches ADR-046 spec -------------------

@test "AC4: .gitignore contains a comment block citing ADR-046 as source of truth" {
  [ -f "$GITIGNORE" ]
  run grep -E 'ADR-046' "$GITIGNORE"
  [ "$status" -eq 0 ]
}

@test "AC4: .gitignore contains the three canonical sidecar file patterns" {
  [ -f "$GITIGNORE" ]
  # decision-log.md must NOT appear as an ignore pattern (it's synced) —
  # but may appear in a comment. Check it's not on an active pattern line.
  run bash -c "grep -vE '^[[:space:]]*(#|\$)' '$GITIGNORE' | grep -E '^[!/]?.*decision-log\\.md[[:space:]]*\$'"
  [ "$status" -ne 0 ] || {
    # If it appears, it must be a negation (! prefix) — allowed
    run bash -c "grep -vE '^[[:space:]]*(#|\$)' '$GITIGNORE' | grep -E '^decision-log\\.md' | grep -v '^!'"
    [ "$status" -ne 0 ]
  }
  # conversation-context.md MUST appear as an active ignore pattern
  run bash -c "grep -vE '^[[:space:]]*(#|\$)' '$GITIGNORE' | grep -E 'conversation-context\\.md'"
  [ "$status" -eq 0 ]
}

@test "AC4: checkpoints directory is gitignored" {
  [ -f "$GITIGNORE" ]
  assert_excluded "${MEM_DIR}/checkpoints/some-checkpoint.yaml"
}

@test "AC4: archive subdirectory under sidecars is gitignored" {
  [ -f "$GITIGNORE" ]
  assert_excluded "${MEM_DIR}/sm-sidecar/archive/old-decision.md"
}
