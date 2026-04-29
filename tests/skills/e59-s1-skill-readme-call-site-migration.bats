#!/usr/bin/env bats
# e59-s1-skill-readme-call-site-migration.bats — E59-S1 regression guard
#
# Story: E59-S1 (Migrate six SKILL.md/README call sites to transition-story-status.sh)
# Epic:  E59 (Status-Edit Discipline + Wrapper Removal)
# ADR:   ADR-074 contract C3 (status-edit discipline framework-wide hard rule)
#
# Asserts that the three documentation files migrated by E59-S1 contain zero
# `update-story-status` references and that each migrated reference invokes
# `transition-story-status.sh` with the canonical `--to <status>` form.
#
# AC mapping:
#   AC1 — Test 1: zero `update-story-status` matches in
#                 plugins/gaia/skills/gaia-create-story/SKILL.md
#   AC2 — Test 2: zero `update-story-status` matches in
#                 plugins/gaia/skills/gaia-dev-story/SKILL.md
#   AC3 — Test 3: gaia-dev-story/README.md table cell references
#                 `transition-story-status.sh`
#   Suite — Test 4: zero `update-story-status` matches across all
#                   plugins/gaia/skills/**/*.md (docs sweep)
#   AC1 — Test 5: gaia-create-story SKILL.md contains at least one
#                 `transition-story-status.sh KEY --to backlog` form
#   AC2 — Test 6: gaia-dev-story SKILL.md contains at least one
#                 `transition-story-status.sh {story_key} --to in-progress`
#                 and `--to review` form

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  CREATE_SKILL="${REPO_ROOT}/plugins/gaia/skills/gaia-create-story/SKILL.md"
  DEV_SKILL="${REPO_ROOT}/plugins/gaia/skills/gaia-dev-story/SKILL.md"
  DEV_README="${REPO_ROOT}/plugins/gaia/skills/gaia-dev-story/README.md"
  SKILLS_DIR="${REPO_ROOT}/plugins/gaia/skills"
}

@test "AC1: gaia-create-story/SKILL.md has zero update-story-status matches" {
  run grep -c 'update-story-status' "${CREATE_SKILL}"
  # grep -c prints count and exits 0 when matches > 0, exit 1 when 0 matches.
  # Accept either: status 1 (zero matches) OR status 0 with output "0".
  if [ "${status}" -eq 0 ]; then
    [ "${output}" = "0" ]
  else
    [ "${status}" -eq 1 ]
  fi
}

@test "AC2: gaia-dev-story/SKILL.md has zero update-story-status matches" {
  run grep -c 'update-story-status' "${DEV_SKILL}"
  if [ "${status}" -eq 0 ]; then
    [ "${output}" = "0" ]
  else
    [ "${status}" -eq 1 ]
  fi
}

@test "AC3: gaia-dev-story/README.md table cell references transition-story-status.sh" {
  run grep -F 'transition-story-status.sh' "${DEV_README}"
  [ "${status}" -eq 0 ]
  run grep -c 'update-story-status' "${DEV_README}"
  if [ "${status}" -eq 0 ]; then
    [ "${output}" = "0" ]
  else
    [ "${status}" -eq 1 ]
  fi
}

@test "Suite sweep: zero update-story-status matches across plugins/gaia/skills/**/*.md" {
  # Collect counts across all .md files under skills/.
  total=0
  while IFS= read -r f; do
    c=$(grep -c 'update-story-status' "$f" || true)
    total=$((total + c))
  done < <(find "${SKILLS_DIR}" -type f -name '*.md')
  [ "${total}" -eq 0 ]
}

@test "AC1: gaia-create-story/SKILL.md uses transition-story-status.sh --to backlog form" {
  run grep -F 'transition-story-status.sh' "${CREATE_SKILL}"
  [ "${status}" -eq 0 ]
  run grep -E 'transition-story-status\.sh.*--to backlog' "${CREATE_SKILL}"
  [ "${status}" -eq 0 ]
}

@test "AC2: gaia-dev-story/SKILL.md uses transition-story-status.sh --to in-progress and --to review forms" {
  run grep -E 'transition-story-status\.sh.*--to in-progress' "${DEV_SKILL}"
  [ "${status}" -eq 0 ]
  run grep -E 'transition-story-status\.sh.*--to review' "${DEV_SKILL}"
  [ "${status}" -eq 0 ]
}
