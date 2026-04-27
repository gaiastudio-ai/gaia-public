#!/usr/bin/env bats
# gaia-editorial-structure.bats — editorial-structure skill content tests (E51-S2)
#
# Validates:
#   TC-GR37-20 / AC1: SKILL.md documents canonical sections per document type
#                     (PRD, architecture, story, brief) in a Doc-Type Conventions
#                     reference block.
#   TC-GR37-20 / AC2: SKILL.md "missing sections" evaluation logic explicitly states
#                     it assumes knowledge of doc-type conventions and cross-references
#                     the Doc-Type Conventions block.
#
# Usage:
#   bats tests/skills/gaia-editorial-structure.bats
#
# Dependencies: bats-core 1.10+

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SKILL_FILE="$REPO_ROOT/plugins/gaia/skills/gaia-editorial-structure/SKILL.md"
}

@test "SKILL.md exists" {
  [ -f "$SKILL_FILE" ]
}

@test "SKILL.md has a dedicated Doc-Type Conventions heading" {
  # Accept any H2/H3 heading whose text contains 'Doc-Type Conventions' (case-insensitive).
  run grep -i -E '^##+[[:space:]]+.*Doc[- ]Type Conventions' "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "Doc-Type Conventions block references PRD canonical sections" {
  # The conventions block must call out PRD as a labelled doc type.
  run grep -E '\*\*PRD\*\*|^- \*\*PRD\*\*|^- \*\*PRD\*\*[[:space:]]' "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "Doc-Type Conventions block references architecture canonical sections" {
  # The conventions block must call out architecture as a labelled doc type.
  run grep -i -E '\*\*Architecture\*\*|^- \*\*Architecture\*\*|^- \*\*Architecture\*\*[[:space:]]' "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "Doc-Type Conventions block references story canonical sections" {
  # The conventions block must call out story as a labelled doc type.
  run grep -i -E '\*\*Story\*\*|^- \*\*Story\*\*|^- \*\*Story\*\*[[:space:]]' "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "Doc-Type Conventions block references brief canonical sections" {
  # The conventions block must call out brief as a labelled doc type.
  run grep -i -E '\*\*Brief\*\*|^- \*\*Brief\*\*|^- \*\*Brief\*\*[[:space:]]' "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "Missing sections evaluation cites doc-type conventions" {
  # The 'missing sections' bullet must explicitly state that the evaluation
  # assumes knowledge of doc-type conventions (not a free-form heuristic).
  run grep -i -E "missing sections.*doc[- ]type|doc[- ]type convention.*missing|assumes.*doc[- ]type|doc[- ]type.*knowledge" "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "Missing sections evaluation cross-references the Doc-Type Conventions block" {
  # Inline cross-reference so reviewers can locate the canonical list quickly.
  run grep -i -E "see Doc[- ]Type Conventions|see the Doc[- ]Type Conventions" "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "Doc-type unknown fallback documented" {
  # If the doc-type cannot be inferred, the report must note 'doc-type unknown — missing-sections evaluation skipped'.
  run grep -i -E "doc[- ]type unknown" "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "YAML frontmatter intact — name field unchanged" {
  run grep -E '^name: gaia-editorial-structure$' "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "YAML frontmatter intact — allowed-tools unchanged" {
  run grep -E '^allowed-tools: \[Read, Grep\]$' "$SKILL_FILE"
  [ "$status" -eq 0 ]
}
