#!/usr/bin/env bash
# merge.sh — gaia-dev-story PR merge (E28-S53)
#
# Merges a PR after CI passes. Handles conflict detection, branch protection
# failures, and merge strategy selection from the promotion chain config.
#
# Never uses admin-override or any branch-protection bypass flag.
#
# Usage:
#   merge.sh <pr_number> <story_key> [--strategy <merge|squash|rebase>] [--delete-branch]
#
# Environment:
#   PROJECT_PATH — required. The git working directory.
#
# Exit codes:
#   0 — PR merged successfully
#   1 — merge failed (conflict, protection, or other error)

set -euo pipefail
LC_ALL=C
export LC_ALL

SCRIPT_NAME="gaia-dev-story/merge.sh"

log() { printf '%s: %s\n' "$SCRIPT_NAME" "$*" >&2; }
die() { log "$*"; exit 1; }

if [ $# -lt 2 ]; then
  die "usage: merge.sh <pr_number> <story_key> [--strategy <merge|squash|rebase>] [--delete-branch]"
fi

PR_NUMBER="$1"
STORY_KEY="$2"
shift 2

STRATEGY="squash"
DELETE_BRANCH=true
while [ $# -gt 0 ]; do
  case "$1" in
    --strategy)
      STRATEGY="$2"
      shift 2
      ;;
    --delete-branch)
      DELETE_BRANCH=true
      shift
      ;;
    --no-delete-branch)
      DELETE_BRANCH=false
      shift
      ;;
    *) die "unknown option: $1" ;;
  esac
done

# Validate strategy
case "$STRATEGY" in
  merge|squash|rebase) ;;
  *) die "Invalid merge_strategy '${STRATEGY}'. Allowed: merge, squash, rebase." ;;
esac

WORK_DIR="${PROJECT_PATH:-.}"
cd "$WORK_DIR" || die "cannot cd to $WORK_DIR"

if ! command -v gh >/dev/null 2>&1; then
  die "Required tool gh not found. Install it or complete merge manually."
fi

# Idempotency check: is PR already merged?
pr_state=$(gh pr view "$PR_NUMBER" --json state,mergedAt --jq '.state' 2>/dev/null || echo "UNKNOWN")
if [ "$pr_state" = "MERGED" ]; then
  log "PR #${PR_NUMBER} already merged — skipping"
  echo "already_merged"
  exit 0
fi

# Build merge command
MERGE_CMD="gh pr merge $PR_NUMBER --${STRATEGY} --body \"Story: ${STORY_KEY}\""
if [ "$DELETE_BRANCH" = true ]; then
  MERGE_CMD="$MERGE_CMD --delete-branch"
fi

# Execute merge
merge_output=$(eval "$MERGE_CMD" 2>&1) || {
  # Classify failure
  if echo "$merge_output" | grep -qiE 'not mergeable|merge conflict|conflicts with base'; then
    log "Merge conflict detected. Resolve conflicts locally, push, and resume with /gaia-resume."
    exit 1
  fi

  if echo "$merge_output" | grep -qiE 'required status|required.*review|protected branch|review required'; then
    log "Branch protection blocked the merge. Unmet requirements:"
    printf '%s\n' "$merge_output" >&2
    log "Resolve protection requirements and retry."
    exit 1
  fi

  log "Merge failed: $merge_output"
  log "Resume with /gaia-resume after resolving."
  exit 1
}

log "PR #${PR_NUMBER} merged via ${STRATEGY}"
echo "merged:${STRATEGY}"
exit 0
