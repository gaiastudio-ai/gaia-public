#!/usr/bin/env bats
# ATDD — E28-S171 Create docs/INDEX.md as single discovery entry point for artifact dirs
# Source: docs/implementation-artifacts/E28-S171-*.md
#
# E28-S132 triage finding F1 (missing-setup, low): `docs/INDEX.md` was not
# present in the repo. Task 6 of E28-S132 pointed at it, and the §11.37
# back-pointer in test-plan.md covered discoverability as a workaround.
# This story creates the proper entry point so future plans and readers
# have a single top-level pointer to the three artifact directories.
#
# Acceptance Criteria:
#   AC1: `docs/INDEX.md` exists and links to each of the three artifact
#        directories with a one-line description per link.
#   AC2: The file briefly describes the role of each artifact directory.
#   AC3: Top-level README.md links to `docs/INDEX.md`.

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  INDEX_FILE="${REPO_ROOT}/docs/INDEX.md"
  README_FILE="${REPO_ROOT}/README.md"
}

@test "AC1: docs/INDEX.md exists" {
  [ -f "${INDEX_FILE}" ]
}

@test "AC1: docs/INDEX.md references test-artifacts directory" {
  run grep -E "test-artifacts/?" "${INDEX_FILE}"
  [ "$status" -eq 0 ]
}

@test "AC1: docs/INDEX.md references planning-artifacts directory" {
  run grep -E "planning-artifacts/?" "${INDEX_FILE}"
  [ "$status" -eq 0 ]
}

@test "AC1: docs/INDEX.md references implementation-artifacts directory" {
  run grep -E "implementation-artifacts/?" "${INDEX_FILE}"
  [ "$status" -eq 0 ]
}

@test "AC2: docs/INDEX.md describes the role of test-artifacts" {
  # Look for a heading or bullet describing test-artifacts with explanatory prose
  run bash -c "grep -E -A1 'test-artifacts' '${INDEX_FILE}' | grep -E -i 'test|plan|atdd|qa|coverage'"
  [ "$status" -eq 0 ]
}

@test "AC2: docs/INDEX.md describes the role of planning-artifacts" {
  run bash -c "grep -E -A1 'planning-artifacts' '${INDEX_FILE}' | grep -E -i 'prd|architecture|epic|plan|design|requirement'"
  [ "$status" -eq 0 ]
}

@test "AC2: docs/INDEX.md describes the role of implementation-artifacts" {
  run bash -c "grep -E -A1 'implementation-artifacts' '${INDEX_FILE}' | grep -E -i 'story|implement|review|dev|sprint'"
  [ "$status" -eq 0 ]
}

@test "AC3: top-level README.md links to docs/INDEX.md" {
  run grep -E "docs/INDEX\.md" "${README_FILE}"
  [ "$status" -eq 0 ]
}

@test "Structure: INDEX.md has a top-level heading" {
  run grep -E "^# " "${INDEX_FILE}"
  [ "$status" -eq 0 ]
}

@test "Structure: INDEX.md is non-trivial (at least 20 lines)" {
  line_count=$(wc -l < "${INDEX_FILE}")
  [ "${line_count}" -ge 20 ]
}
