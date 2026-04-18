#!/usr/bin/env bash
# dead-reference-scan.sh — GAIA foundation script (E28-S126)
#
# Scans the project tree for references to legacy-engine paths that were retired
# by ADR-048. Produces a clean pass (exit 0) only when every match lies in the
# allowlist (docs, CHANGELOG, migration guide, parity-guard bats, E28-S126
# tooling itself, and explicit per-file allowlist entries for passive/historical
# prose references).
#
# Refs: FR-328, NFR-050, ADR-048 (program-closing CI compensating control)
# Story: E28-S126 Task 3 / AC6 / AC-EC7
#
# Used by .github/workflows/adr-048-guard.yml as the required PR check.
#
# Exit codes:
#   0 — clean (no active-code references)
#   1 — one or more active-code references found
#   64 — usage error
#
# Usage: dead-reference-scan.sh --project-root PATH

set -euo pipefail

PROJECT_ROOT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-root) PROJECT_ROOT="${2:-}"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 --project-root PATH"
      exit 0
      ;;
    *) echo "Unknown argument: $1" >&2; echo "Usage: $0 --project-root PATH" >&2; exit 64 ;;
  esac
done

if [[ -z "$PROJECT_ROOT" ]]; then
  echo "Usage: $0 --project-root PATH" >&2
  exit 64
fi
if [[ ! -d "$PROJECT_ROOT" ]]; then
  echo "project-root does not exist: $PROJECT_ROOT" >&2
  exit 64
fi

# Patterns that identify references to retired artifacts. Three families covered:
#   (1) ADR-048 engine/protocols/manifests (E28-S126 scope)
#   (2) FR-329 slash-command file-path references — anchored on .md extension so
#       the invocation form "/gaia-foo" (used freely in skill prose) does NOT match.
#   (3) E28-S128 workflow-artifact filenames — word-boundary match catches backtick-
#       prose, parenthesized, colon-prefixed, and path-form references. Shell-variable
#       forms (e.g., "$workflow.yaml" in checkpoint.sh) are stripped by the
#       is_shell_variable_context() negative-filter below.
#
# The slash-command patterns are deliberately written against file-path context:
#   .claude/commands/gaia-{name}.md   — legacy runtime surface
#   plugins/gaia/commands/gaia-{name}.md — retired product-source surface
PATTERN='workflow\.xml|core/protocols|\.resolved/|lifecycle-sequence\.yaml|workflow-manifest\.csv|task-manifest\.csv|skill-manifest\.csv|\.claude/commands/gaia-[a-z0-9-]+\.md|plugins/gaia/commands/gaia-[a-z0-9-]+\.md|(^|[^-a-z])workflow\.yaml\b|(^|[^-a-z])instructions\.xml\b|(^|[^-a-z])checklist\.md\b'

# E28-S128 negative filter — a matched line is treated as a false-positive (and dropped)
# when the match is a shell-variable expansion rather than a literal reference.
# Examples of false-positives:
#   local target="$CHECKPOINT_PATH/$workflow.yaml"          (variable)
#   local lockfile="$CHECKPOINT_PATH/$workflow.yaml.lock"   (variable + suffix)
#   out="${name}.yaml"                                       (parameter expansion)
# These patterns are bash runtime expansions, not stale references to the retired
# workflow.yaml/instructions.xml/checklist.md filenames.
is_shell_variable_context() {
  local line="$1"
  # $workflow.yaml or $workflow.xml (and any ".lock" etc. trailing suffix) — dollar-then-identifier-then-dot-extension
  [[ "$line" =~ \$workflow\.yaml ]] && return 0
  [[ "$line" =~ \$instructions\.xml ]] && return 0
  [[ "$line" =~ \$checklist\.md ]] && return 0
  # ${anything}.yaml / .xml / .md — parameter-expansion form
  [[ "$line" =~ \$\{[a-zA-Z_][a-zA-Z_0-9]*\}\.(yaml|xml|md) ]] && return 0
  return 1
}

# Scope: only scan active-code locations. Documentation and test parity-guards are out of scope.
SCAN_PATHS=(
  "$PROJECT_ROOT/plugins/gaia"
  "$PROJECT_ROOT/.github/workflows"
  "$PROJECT_ROOT/.github/scripts"
)

# Files that may contain legacy references for historical or contractual reasons.
is_allowlisted() {
  local path="$1"
  # Everything under docs/ is documentation — allowlisted.
  [[ "$path" == */docs/* ]] && return 0
  # CHANGELOG at any depth is changelog — allowlisted.
  [[ "$(basename "$path")" == "CHANGELOG.md" ]] && return 0
  # Migration-guide filename is allowlisted.
  [[ "$(basename "$path")" == migration-guide* ]] && return 0
  # The Cluster 19 parity guard ASSERTS zero engine loads — preserve verbatim.
  [[ "$path" == */plugins/gaia/test/e28-s133-full-lifecycle-atdd.bats ]] && return 0
  # Comment-only references in foundation scripts (see plan v4 Modified-files table).
  [[ "$path" == */plugins/gaia/scripts/resolve-config.sh ]] && return 0
  [[ "$path" == */plugins/gaia/scripts/checkpoint.sh ]] && return 0
  # Negated mandate in orchestrator.md ("NEVER execute workflow engine plumbing").
  [[ "$path" == */plugins/gaia/agents/orchestrator.md ]] && return 0
  # Descriptive mention in _SCHEMA.md (documents what the native model replaces).
  [[ "$path" == */plugins/gaia/agents/_SCHEMA.md ]] && return 0
  # Test fixtures that must contain legacy paths (they simulate pre-cleanup state).
  [[ "$path" == */test/scripts/fixtures/* ]] && return 0
  # E28-S126 tooling itself — the migration CLI and its tests intentionally name
  # legacy paths (they ARE the deletion mechanism).
  [[ "$path" == */plugins/gaia/scripts/gaia-cleanup-legacy-engine.sh ]] && return 0
  [[ "$path" == */plugins/gaia/scripts/dead-reference-scan.sh ]] && return 0
  [[ "$path" == */plugins/gaia/scripts/verify-cluster-gates.sh ]] && return 0
  [[ "$path" == */plugins/gaia/test/scripts/e28-s126-*.bats ]] && return 0
  # E28-S127 tooling itself — commands-guard.sh and its bats fixtures intentionally
  # create retired-surface paths in test scaffolds.
  [[ "$path" == */plugins/gaia/scripts/commands-guard.sh ]] && return 0
  [[ "$path" == */plugins/gaia/test/scripts/e28-s127-*.bats ]] && return 0
  # E28-S129 bats file — asserts CLAUDE.md does NOT contain legacy paths, so its
  # negative-match assertions include the retired tokens as literals.
  [[ "$path" == */plugins/gaia/test/scripts/e28-s129-*.bats ]] && return 0
  # E28-S131 migration tooling — gaia-migrate skill + script + bats + fixture all
  # intentionally reference v1 retired paths (workflow.xml, etc.) for v1 detection
  # and migration. Test fixtures simulate a v1 install and contain the literal files.
  [[ "$path" == */plugins/gaia/skills/gaia-migrate/SKILL.md ]] && return 0
  [[ "$path" == */plugins/gaia/scripts/gaia-migrate.sh ]] && return 0
  [[ "$path" == */plugins/gaia/test/scripts/e28-s131-*.bats ]] && return 0
  [[ "$path" == */test/scripts/fixtures/v1-install/* ]] && return 0
  # next-step.sh is the fallback mechanism itself — it ships with a
  # graceful-missing-file handler and all references are part of implementing
  # the fallback (see Val v1 Finding 2).
  [[ "$path" == */plugins/gaia/scripts/next-step.sh ]] && return 0
  # E28-S162 — the shared missing-file graceful fallback helper and its smoke
  # test legitimately name the retired files in docstrings/examples because the
  # helper IS the fallback mechanism for those exact paths. next-step.sh above
  # already has this carve-out for the same reason.
  [[ "$path" == */plugins/gaia/scripts/lib/missing-file-fallback.sh ]] && return 0
  [[ "$path" == */plugins/gaia/scripts/tests/smoke-e28-s162.sh ]] && return 0
  # gaia-help/SKILL.md IS the no-hallucination fallback contract; its
  # references document the AC-EC2 fallback mechanism and are guarded by
  # e28-s126-gaia-help-fallback.bats (Val v1 Finding 8).
  [[ "$path" == */plugins/gaia/skills/gaia-help/SKILL.md ]] && return 0
  # gaia-val-validate-plan SKILL.md references are heuristic descriptions
  # (validation patterns for plans that mention workflow-manifest.csv).
  [[ "$path" == */plugins/gaia/skills/gaia-val-validate-plan/SKILL.md ]] && return 0
  # gaia-validation-patterns SKILL.md references are heuristic descriptions.
  [[ "$path" == */plugins/gaia/skills/gaia-validation-patterns/SKILL.md ]] && return 0
  # gaia-performance-review references are negated ("no workflow.xml engine").
  [[ "$path" == */plugins/gaia/skills/gaia-performance-review/SKILL.md ]] && return 0
  # gaia-tech-debt-review references are negated ("no workflow.xml engine").
  [[ "$path" == */plugins/gaia/skills/gaia-tech-debt-review/SKILL.md ]] && return 0
  # gaia-git-workflow reference is negated ("no longer runs through workflow.xml").
  [[ "$path" == */plugins/gaia/skills/gaia-git-workflow/SKILL.md ]] && return 0
  # gaia-memory-management, gaia-ground-truth-management, gaia-document-rulesets
  # retain historical prose describing their original engine integration — no
  # runtime load. Plan v4 triage classifies these as allowlist-only (INFO refresh deferred).
  [[ "$path" == */plugins/gaia/skills/gaia-memory-management/SKILL.md ]] && return 0
  [[ "$path" == */plugins/gaia/skills/gaia-ground-truth-management/SKILL.md ]] && return 0
  [[ "$path" == */plugins/gaia/skills/gaia-document-rulesets/SKILL.md ]] && return 0
  # gaia-product-brief and gaia-brainstorm reference lifecycle-sequence.yaml in
  # their template output as a pointer — actual next-step computation delegates
  # to next-step.sh which has its own fallback (see above).
  [[ "$path" == */plugins/gaia/skills/gaia-product-brief/SKILL.md ]] && return 0
  [[ "$path" == */plugins/gaia/skills/gaia-brainstorm/SKILL.md ]] && return 0
  # The ADR-048 guard workflow itself names the patterns it is supposed to catch.
  [[ "$path" == */.github/workflows/adr-048-guard.yml ]] && return 0
  # gaia-validate-framework prose now documents what was retired by ADR-044/ADR-048
  # (the new text explicitly calls out the removed mechanisms so future readers
  # understand the native model — these are retirement notices, not active loads).
  [[ "$path" == */plugins/gaia/skills/gaia-validate-framework/SKILL.md ]] && return 0
  # gaia-bridge-toggle prose similarly documents the retired build-configs step.
  [[ "$path" == */plugins/gaia/skills/gaia-bridge-toggle/SKILL.md ]] && return 0
  # E28-S128 — 41 SKILL.md and skill-companion-script files cite legacy filenames
  # (workflow.yaml, instructions.xml, checklist.md) as parity references per NFR-053.
  # These are historical documentation, not active loads. The commands-guard from
  # E28-S127 and the PATTERN negative-filter catch real regressions; active loads
  # would break at runtime and be caught by the Cluster 19 parity harness.
  # See docs/implementation-artifacts/E28-S128-triage-ledger.md for the full triage.
  case "$path" in
    */plugins/gaia/scripts/tests/smoke-e28-s36.sh|\
    */plugins/gaia/skills/edge-cases/SKILL.md|\
    */plugins/gaia/skills/gaia-a11y-testing/SKILL.md|\
    */plugins/gaia/skills/gaia-action-items/SKILL.md|\
    */plugins/gaia/skills/gaia-advanced-elicitation/SKILL.md|\
    */plugins/gaia/skills/gaia-bridge-disable/SKILL.md|\
    */plugins/gaia/skills/gaia-bridge-enable/SKILL.md|\
    */plugins/gaia/skills/gaia-brownfield/SKILL.md|\
    */plugins/gaia/skills/gaia-code-review-standards/SKILL.md|\
    */plugins/gaia/skills/gaia-create-arch/SKILL.md|\
    */plugins/gaia/skills/gaia-create-epics/SKILL.md|\
    */plugins/gaia/skills/gaia-create-prd/SKILL.md|\
    */plugins/gaia/skills/gaia-create-stakeholder/SKILL.md|\
    */plugins/gaia/skills/gaia-create-ux/SKILL.md|\
    */plugins/gaia/skills/gaia-creative-sprint/SKILL.md|\
    */plugins/gaia/skills/gaia-domain-research/SKILL.md|\
    */plugins/gaia/skills/gaia-domain-research/scripts/setup.sh|\
    */plugins/gaia/skills/gaia-edit-arch/SKILL.md|\
    */plugins/gaia/skills/gaia-edit-prd/SKILL.md|\
    */plugins/gaia/skills/gaia-edit-test-plan/SKILL.md|\
    */plugins/gaia/skills/gaia-edit-ux/SKILL.md|\
    */plugins/gaia/skills/gaia-infra-design/SKILL.md|\
    */plugins/gaia/skills/gaia-market-research/SKILL.md|\
    */plugins/gaia/skills/gaia-market-research/scripts/setup.sh|\
    */plugins/gaia/skills/gaia-memory-hygiene/SKILL.md|\
    */plugins/gaia/skills/gaia-mobile-testing/SKILL.md|\
    */plugins/gaia/skills/gaia-nfr/SKILL.md|\
    */plugins/gaia/skills/gaia-party/SKILL.md|\
    */plugins/gaia/skills/gaia-perf-testing/SKILL.md|\
    */plugins/gaia/skills/gaia-problem-solving/SKILL.md|\
    */plugins/gaia/skills/gaia-product-brief/scripts/setup.sh|\
    */plugins/gaia/skills/gaia-quick-dev/SKILL.md|\
    */plugins/gaia/skills/gaia-quick-spec/SKILL.md|\
    */plugins/gaia/skills/gaia-readiness-check/SKILL.md|\
    */plugins/gaia/skills/gaia-teach-testing/SKILL.md|\
    */plugins/gaia/skills/gaia-tech-debt-review/scripts/scan-findings.sh|\
    */plugins/gaia/skills/gaia-tech-research/SKILL.md|\
    */plugins/gaia/skills/gaia-test-design/SKILL.md|\
    */plugins/gaia/skills/gaia-test-framework/SKILL.md|\
    */plugins/gaia/skills/gaia-threat-model/SKILL.md|\
    */plugins/gaia/skills/gaia-trace/SKILL.md)
      return 0
      ;;
  esac
  return 1
}

# Collect matches.
matches=""
for root in "${SCAN_PATHS[@]}"; do
  [[ -d "$root" ]] || continue
  # grep exits 1 on no match; `|| true` keeps the script running under `set -e`.
  # shellcheck disable=SC2016
  found=$(grep -rEn "$PATTERN" "$root" 2>/dev/null || true)
  matches+="${found}"$'\n'
done

# Filter out allowlisted paths AND shell-variable false-positives.
offending=""
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  # Line format: path:linenum:match
  path="${line%%:*}"
  if is_allowlisted "$path"; then
    continue
  fi
  # E28-S128 — strip shell-variable false-positives (e.g., "$workflow.yaml" in checkpoint.sh)
  if is_shell_variable_context "$line"; then
    continue
  fi
  offending+="${line}"$'\n'
done <<< "$matches"

offending=$(printf '%s' "$offending" | sed '/^$/d')

if [[ -z "$offending" ]]; then
  echo "dead-reference-scan: CLEAN — no active-code references to ADR-048 deletion targets"
  exit 0
fi

echo "dead-reference-scan: FAILED — active-code references to legacy-engine paths found:"
echo
printf '%s\n' "$offending"
echo
echo "Each reference above is in active code (skill body, script, hook, CI workflow, or agent file)"
echo "and is NOT covered by the documentation/parity-guard allowlist."
echo "Either scrub the reference, add a fallback, or extend the allowlist in this script."
exit 1
