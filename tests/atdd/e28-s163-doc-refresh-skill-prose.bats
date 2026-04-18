#!/usr/bin/env bats
# ATDD — E28-S163 Doc-refresh pass to update stale workflow.xml prose in 3 skills
# Source: docs/implementation-artifacts/E28-S163-*.md
#
# Post-E28-S126 cleanup: the workflow.xml engine has been removed under
# ADR-041 (Native Execution Model). The three skills below still carried
# prose that described their JIT section loaders as being driven by
# `_gaia/core/engine/workflow.xml`. This suite enforces that the prose
# has been refreshed to describe the native marker loader instead.

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  SKILLS_DIR="${REPO_ROOT}/plugins/gaia/skills"

  MEMORY_MANAGEMENT_SKILL="${SKILLS_DIR}/gaia-memory-management/SKILL.md"
  GROUND_TRUTH_SKILL="${SKILLS_DIR}/gaia-ground-truth-management/SKILL.md"
  DOCUMENT_RULESETS_SKILL="${SKILLS_DIR}/gaia-document-rulesets/SKILL.md"
}

@test "AC1: gaia-memory-management/SKILL.md contains no workflow.xml references" {
  run grep -n "workflow\.xml" "${MEMORY_MANAGEMENT_SKILL}"
  [ "$status" -ne 0 ]
}

@test "AC1: gaia-ground-truth-management/SKILL.md contains no workflow.xml references" {
  run grep -n "workflow\.xml" "${GROUND_TRUTH_SKILL}"
  [ "$status" -ne 0 ]
}

@test "AC1: gaia-document-rulesets/SKILL.md contains no workflow.xml references" {
  run grep -n "workflow\.xml" "${DOCUMENT_RULESETS_SKILL}"
  [ "$status" -ne 0 ]
}

@test "AC2: gaia-memory-management/SKILL.md describes the native JIT marker loader" {
  run grep -E "SECTION|native|JIT" "${MEMORY_MANAGEMENT_SKILL}"
  [ "$status" -eq 0 ]
}

@test "AC2: gaia-ground-truth-management/SKILL.md describes the native JIT marker loader" {
  run grep -E "SECTION|native|JIT" "${GROUND_TRUTH_SKILL}"
  [ "$status" -eq 0 ]
}

@test "AC2: gaia-document-rulesets/SKILL.md describes the native JIT marker loader" {
  run grep -E "SECTION|native|JIT" "${DOCUMENT_RULESETS_SKILL}"
  [ "$status" -eq 0 ]
}
