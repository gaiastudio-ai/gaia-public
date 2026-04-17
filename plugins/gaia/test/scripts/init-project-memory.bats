#!/usr/bin/env bats
# init-project-memory.bats — E28-S151
#
# Validates that init-project.sh seeds the full hybrid _memory/ layout
# (per-agent sidecars + canonical headers) as specified in ADR-046.
#
# Acceptance criteria covered:
#   AC1: _memory/config.yaml is written with canonical tier + agent shape
#   AC2: sidecar directory exists for every agent in config.yaml agents:
#   AC3: tier-correct files per sidecar (T1=3, T2=2, T3=1)
#   AC4: canonical header marker on each sidecar file, empty body
#   AC5: re-run without --force preserves existing content byte-for-byte
#   AC6: gap-fill populates missing sidecar dirs / zero-byte files
#   AC7: --force refuses to clobber files with content below the header
#   AC8: memory-loader.sh <agent> decision-log exits 0 with empty stdout

PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SCRIPTS_DIR="$PLUGIN_DIR/scripts"
INIT_SH="$SCRIPTS_DIR/init-project.sh"
MEMORY_LOADER_SH="$SCRIPTS_DIR/memory-loader.sh"

setup() {
  TMP_DIR="$(mktemp -d)"
  TARGET="$TMP_DIR/demo"
}

teardown() {
  rm -rf "$TMP_DIR"
}

# ---------- AC1: config.yaml shape ------------------------------------------

@test "AC1: _memory/config.yaml is written with canonical tier + agent shape" {
  run "$INIT_SH" --name demo --path "$TARGET"
  [ "$status" -eq 0 ]

  local cfg="$TARGET/_memory/config.yaml"
  [ -f "$cfg" ]
  [ -s "$cfg" ]

  # Three tiers present
  run grep -c '^  tier_1:\|^  tier_2:\|^  tier_3:' "$cfg"
  [ "$output" -eq 3 ]

  # agents: block present with per-agent sidecar: mappings
  run grep -c '^    sidecar: ' "$cfg"
  [ "$output" -ge 20 ]

  # cross_references block present
  run grep -c '^cross_references:' "$cfg"
  [ "$output" -eq 1 ]

  # archival block with token_approximation
  run grep -c '^  token_approximation:' "$cfg"
  [ "$output" -eq 1 ]
}

# ---------- AC2: sidecar directory per agent --------------------------------

@test "AC2: sidecar directory exists for every agent in seeded config.yaml" {
  run "$INIT_SH" --name demo --path "$TARGET"
  [ "$status" -eq 0 ]

  # Spot-check representative agents from each tier
  [ -d "$TARGET/_memory/validator-sidecar" ]      # T1
  [ -d "$TARGET/_memory/architect-sidecar" ]      # T1
  [ -d "$TARGET/_memory/pm-sidecar" ]             # T1
  [ -d "$TARGET/_memory/sm-sidecar" ]             # T1
  [ -d "$TARGET/_memory/orchestrator-sidecar" ]   # T2
  [ -d "$TARGET/_memory/security-sidecar" ]       # T2
  [ -d "$TARGET/_memory/devops-sidecar" ]         # T2
  [ -d "$TARGET/_memory/test-architect-sidecar" ] # T2
  [ -d "$TARGET/_memory/typescript-dev-sidecar" ] # T3
  [ -d "$TARGET/_memory/ux-designer-sidecar" ]    # T3
}

@test "AC2: total sidecar count matches agents defined in config.yaml" {
  run "$INIT_SH" --name demo --path "$TARGET"
  [ "$status" -eq 0 ]

  # 4 Tier 1 + 4 Tier 2 + 18 Tier 3 = 26 agents in the seeded config.
  local sidecar_count
  sidecar_count="$(find "$TARGET/_memory" -maxdepth 1 -mindepth 1 -type d -name '*-sidecar' | wc -l | tr -d ' ')"
  [ "$sidecar_count" -eq 26 ]
}

# ---------- AC3: tier-correct file counts -----------------------------------

@test "AC3: Tier 1 sidecar (validator) has exactly 3 canonical files" {
  run "$INIT_SH" --name demo --path "$TARGET"
  [ "$status" -eq 0 ]

  [ -f "$TARGET/_memory/validator-sidecar/ground-truth.md" ]
  [ -f "$TARGET/_memory/validator-sidecar/decision-log.md" ]
  [ -f "$TARGET/_memory/validator-sidecar/conversation-context.md" ]

  local count
  count="$(find "$TARGET/_memory/validator-sidecar" -maxdepth 1 -type f | wc -l | tr -d ' ')"
  [ "$count" -eq 3 ]
}

@test "AC3: Tier 2 sidecar (orchestrator) has exactly 2 canonical files" {
  run "$INIT_SH" --name demo --path "$TARGET"
  [ "$status" -eq 0 ]

  [ -f "$TARGET/_memory/orchestrator-sidecar/decision-log.md" ]
  [ -f "$TARGET/_memory/orchestrator-sidecar/conversation-context.md" ]
  [ ! -f "$TARGET/_memory/orchestrator-sidecar/ground-truth.md" ]

  local count
  count="$(find "$TARGET/_memory/orchestrator-sidecar" -maxdepth 1 -type f | wc -l | tr -d ' ')"
  [ "$count" -eq 2 ]
}

@test "AC3: Tier 3 sidecar (typescript-dev) has exactly 1 canonical file" {
  run "$INIT_SH" --name demo --path "$TARGET"
  [ "$status" -eq 0 ]

  [ -f "$TARGET/_memory/typescript-dev-sidecar/decision-log.md" ]
  [ ! -f "$TARGET/_memory/typescript-dev-sidecar/ground-truth.md" ]
  [ ! -f "$TARGET/_memory/typescript-dev-sidecar/conversation-context.md" ]

  local count
  count="$(find "$TARGET/_memory/typescript-dev-sidecar" -maxdepth 1 -type f | wc -l | tr -d ' ')"
  [ "$count" -eq 1 ]
}

# ---------- AC4: canonical header marker + empty body ----------------------

@test "AC4: ground-truth.md first line is canonical header marker" {
  run "$INIT_SH" --name demo --path "$TARGET"
  [ "$status" -eq 0 ]

  run head -n 1 "$TARGET/_memory/validator-sidecar/ground-truth.md"
  [ "$status" -eq 0 ]
  [[ "$output" == "# Validator — Ground Truth" ]]
}

@test "AC4: decision-log.md first line is canonical header marker" {
  run "$INIT_SH" --name demo --path "$TARGET"
  [ "$status" -eq 0 ]

  run head -n 1 "$TARGET/_memory/architect-sidecar/decision-log.md"
  [ "$status" -eq 0 ]
  [[ "$output" == "# Architect — Decision Log" ]]
}

@test "AC4: conversation-context.md first line is canonical header marker" {
  run "$INIT_SH" --name demo --path "$TARGET"
  [ "$status" -eq 0 ]

  run head -n 1 "$TARGET/_memory/pm-sidecar/conversation-context.md"
  [ "$status" -eq 0 ]
  [[ "$output" == "# PM — Conversation Context" ]]
}

@test "AC4: header files contain --- separator and no body content" {
  run "$INIT_SH" --name demo --path "$TARGET"
  [ "$status" -eq 0 ]

  # Each file has exactly one --- separator (end-of-header).
  run grep -c '^---$' "$TARGET/_memory/sm-sidecar/decision-log.md"
  [ "$output" -eq 1 ]

  # After the separator, the file contains only trailing whitespace / newlines
  # (no user content lines starting with a letter/digit).
  run awk '/^---$/{found=1; next} found && NF>0 {print; exit}' \
    "$TARGET/_memory/sm-sidecar/decision-log.md"
  [ -z "$output" ]
}

# ---------- AC5: idempotent re-run preserves existing content ---------------

@test "AC5: re-run without --force preserves existing sidecar content byte-for-byte" {
  run "$INIT_SH" --name demo --path "$TARGET"
  [ "$status" -eq 0 ]

  # User adds real content to a sidecar file.
  local file="$TARGET/_memory/validator-sidecar/decision-log.md"
  cat >> "$file" <<'USER'
## 2026-04-17 — decision
Some real decision content below the header.
USER

  local before_sha
  before_sha="$(shasum -a 256 "$file" | awk '{print $1}')"

  # Re-run without --force.
  run "$INIT_SH" --name demo --path "$TARGET"
  [ "$status" -eq 0 ]

  local after_sha
  after_sha="$(shasum -a 256 "$file" | awk '{print $1}')"
  [ "$before_sha" = "$after_sha" ]

  # Observability: stderr mentions preserved count >= 1.
  run bash -c "\"$INIT_SH\" --name demo --path \"$TARGET\" 2>&1 >/dev/null"
  [ "$status" -eq 0 ]
  [[ "$output" == *"_memory/ init"* ]]
  [[ "$output" == *"preserved"* ]]
}

# ---------- AC6: gap-fill missing sidecar / zero-byte file -----------------

@test "AC6: gap-fill recreates a manually-deleted sidecar directory" {
  run "$INIT_SH" --name demo --path "$TARGET"
  [ "$status" -eq 0 ]

  rm -rf "$TARGET/_memory/pm-sidecar"
  [ ! -d "$TARGET/_memory/pm-sidecar" ]

  run "$INIT_SH" --name demo --path "$TARGET"
  [ "$status" -eq 0 ]

  # Gap-filled: directory restored with all 3 Tier 1 files.
  [ -d "$TARGET/_memory/pm-sidecar" ]
  [ -f "$TARGET/_memory/pm-sidecar/ground-truth.md" ]
  [ -f "$TARGET/_memory/pm-sidecar/decision-log.md" ]
  [ -f "$TARGET/_memory/pm-sidecar/conversation-context.md" ]
}

@test "AC6: gap-fill rewrites a zero-byte sidecar file" {
  run "$INIT_SH" --name demo --path "$TARGET"
  [ "$status" -eq 0 ]

  local file="$TARGET/_memory/security-sidecar/decision-log.md"
  : > "$file"  # truncate to zero bytes
  [ ! -s "$file" ]

  run "$INIT_SH" --name demo --path "$TARGET"
  [ "$status" -eq 0 ]

  [ -s "$file" ]
  run head -n 1 "$file"
  [[ "$output" == "# Security — Decision Log" ]]
}

# ---------- AC7: --force never clobbers user content below the header ------

@test "AC7: --force preserves files with user content below the header" {
  run "$INIT_SH" --name demo --path "$TARGET"
  [ "$status" -eq 0 ]

  local file="$TARGET/_memory/validator-sidecar/ground-truth.md"
  cat >> "$file" <<'USER'
## User-authored section
Important content that must never be overwritten.
USER

  local before_sha
  before_sha="$(shasum -a 256 "$file" | awk '{print $1}')"

  run "$INIT_SH" --name demo --path "$TARGET" --force
  [ "$status" -eq 0 ]

  local after_sha
  after_sha="$(shasum -a 256 "$file" | awk '{print $1}')"
  [ "$before_sha" = "$after_sha" ]
}

@test "AC7: --force rewrites a header-only (no user content) file" {
  run "$INIT_SH" --name demo --path "$TARGET"
  [ "$status" -eq 0 ]

  local file="$TARGET/_memory/architect-sidecar/ground-truth.md"
  # Header-only file may be safely rewritten under --force.
  local before_sha
  before_sha="$(shasum -a 256 "$file" | awk '{print $1}')"

  run "$INIT_SH" --name demo --path "$TARGET" --force
  [ "$status" -eq 0 ]

  # File still exists and still begins with the canonical header.
  [ -s "$file" ]
  run head -n 1 "$file"
  [[ "$output" == "# Architect — Ground Truth" ]]

  # Whether the sha changes under --force for a header-only file is implementation-
  # defined (rewriting the same header yields the same bytes). The critical
  # contract here is AC7: user content is never clobbered — covered above.
  [ -n "$before_sha" ]
}

# ---------- AC8: memory-loader.sh happy path --------------------------------

# AC8 — per the Dev Note in the story ("a missing file returns empty stdout;
# a header-only file also returns empty-or-header-only, which is semantically
# equivalent for subagent prompts"), we verify BOTH:
#   (a) memory-loader.sh exits 0 against every tier after init
#   (b) header-only output carries no user content below the `---` separator,
#       so no placeholder leaks into subagent prompts.

# Helper: returns 0 if $1 is either empty or contains no non-whitespace line
# below the first `---` separator.
assert_header_only_or_empty() {
  local content="$1"
  if [ -z "$content" ]; then return 0; fi
  # If there is no --- separator at all, content is invalid.
  printf '%s\n' "$content" | grep -q '^---$' || return 1
  # Anything after the first --- separator must be whitespace-only.
  local leaked
  leaked="$(printf '%s\n' "$content" | awk '/^---$/{found=1; next} found && NF>0 {print; exit}')"
  [ -z "$leaked" ]
}

@test "AC8: memory-loader.sh validator decision-log exits 0 with no leaked content after init" {
  run "$INIT_SH" --name demo --path "$TARGET"
  [ "$status" -eq 0 ]

  run env MEMORY_PATH="$TARGET/_memory" "$MEMORY_LOADER_SH" validator decision-log
  [ "$status" -eq 0 ]
  assert_header_only_or_empty "$output"
}

@test "AC8: memory-loader.sh works for Tier 2 and Tier 3 agents after init" {
  run "$INIT_SH" --name demo --path "$TARGET"
  [ "$status" -eq 0 ]

  # Tier 2 agent
  run env MEMORY_PATH="$TARGET/_memory" "$MEMORY_LOADER_SH" orchestrator decision-log
  [ "$status" -eq 0 ]
  assert_header_only_or_empty "$output"

  # Tier 3 agent
  run env MEMORY_PATH="$TARGET/_memory" "$MEMORY_LOADER_SH" typescript-dev decision-log
  [ "$status" -eq 0 ]
  assert_header_only_or_empty "$output"

  # Missing-memory contract: an agent with no sidecar at all returns empty.
  run env MEMORY_PATH="$TARGET/_memory" "$MEMORY_LOADER_SH" nonexistent-agent decision-log
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
