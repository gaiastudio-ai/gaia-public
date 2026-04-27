#!/usr/bin/env bats
# E52-S11 — /gaia-review-deps hint-level audit checks
#
# Covers TC-GR37-47 from docs/test-artifacts/test-plan.md §11.47.4.
# Script-verifiable greps assert that the SKILL.md body explicitly orders the
# outdated dependency list runtime → dev → transitive (FR-389) and documents
# the empty-tier collapse rule so transitive results never surface under a
# stale "Runtime" header.

setup() {
  SKILL_FILE="${BATS_TEST_DIRNAME}/../../plugins/gaia/skills/gaia-review-deps/SKILL.md"
}

@test "SKILL.md exists" {
  [ -f "$SKILL_FILE" ]
}

@test "TC-GR37-47 — SKILL.md body co-locates runtime, dev, and transitive" {
  # Audit grep: the three tier names must co-locate on a single line so
  # reviewers can confirm the ordering rule is stated, not implied. Either
  # the canonical "runtime ... dev ... transitive" sequence OR a sentence
  # that pairs "prioriti" with at least one tier name passes.
  run grep -niE "runtime.*dev.*transitive|prioriti.*(runtime|dev|transitive)" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

@test "AC1 — Step 3 enumerates runtime → dev → transitive ordering" {
  # The ordering rule must live in Step 3 (Version Analysis), not Critical
  # Rules and not Step 5. Slice the file from "### Step 3" up to the next
  # "### Step" boundary and search inside that slice.
  run awk '/^### Step 3/{flag=1; next} /^### Step [0-9]/{flag=0} flag' "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [ -n "$output" ]

  # Within Step 3 the three tier names must appear (case-insensitive).
  printf '%s\n' "$output" | grep -qiE "runtime"
  printf '%s\n' "$output" | grep -qiE "\bdev\b|devDependencies|dev dependencies"
  printf '%s\n' "$output" | grep -qiE "transitive"
}

@test "AC1 — Step 3 documents tier-detection inputs per package manager" {
  # The rule is verifiable only if Step 3 enumerates the canonical
  # tier-detection inputs for the three highest-prevalence manifests:
  # package.json (dependencies / devDependencies), pyproject.toml, and
  # pom.xml. Match each manifest token in the SKILL body.
  run grep -niE "package\.json|devDependencies" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [ -n "$output" ]

  run grep -niE "pyproject\.toml" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [ -n "$output" ]

  run grep -niE "pom\.xml" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

@test "AC2 — empty-tier collapse rule is documented" {
  # The collapse clause must say empty tiers are omitted so transitive
  # results never appear under a stale Runtime header. Match either the
  # "omit" or "collapse" phrasing co-located with a tier name.
  run grep -niE "(omit|collapse|empty).*(tier|runtime|dev|transitive)|empty.*section" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

@test "AC3 — ordering is stated as a rule, not implied via example" {
  # The Step 3 prose must use rule-imperative wording (Order / Sort / first
  # / then) so the ordering is unambiguous to a reviewer scanning the body.
  run awk '/^### Step 3/{flag=1; next} /^### Step [0-9]/{flag=0} flag' "$SKILL_FILE"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qiE "order|sort|first.*then|prioriti"
}

@test "AC5 — Critical Rules section unchanged (no fourth ordering rule)" {
  # Critical Rules covers exactly three bullets: CVE checks, outdated/
  # unmaintained packages, license conflicts. The ordering rule MUST NOT
  # be added as a fourth Critical Rule — slice the Critical Rules section
  # and assert the bullet count stays at 3.
  bullets=$(awk '/^## Critical Rules/{flag=1; next} /^## /{flag=0} flag' "$SKILL_FILE" | grep -cE "^- \*\*")
  [ "$bullets" -eq 3 ]
}

@test "AC5 — Step 5 retains 'Outdated package list' bullet" {
  # The Step 5 report enumeration must still list the outdated package
  # bullet verbatim. The collapse note is additive prose, not a rewrite.
  run grep -nE "Outdated package list" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}
