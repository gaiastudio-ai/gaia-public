#!/usr/bin/env bash
# git-branch.sh — gaia-dev-story feature branch creation (E28-S53)
#
# Creates a feature branch following the git-workflow skill convention:
#   feat/{story_key}-{slug}
#
# Handles collision detection: if the branch already exists, offers resume
# instead of force-overwriting. Never destroys user work.
#
# Usage:
#   git-branch.sh <story_key> <slug>
#
# Environment:
#   PROJECT_PATH — required. The git working directory.
#
# Exit codes:
#   0 — branch created or already exists (resume)
#   1 — error (no git repo, invalid args, etc.)

set -euo pipefail
LC_ALL=C
export LC_ALL

SCRIPT_NAME="gaia-dev-story/git-branch.sh"

log() { printf '%s: %s\n' "$SCRIPT_NAME" "$*" >&2; }
die() { log "$*"; exit 1; }

if [ $# -lt 2 ]; then
  die "usage: git-branch.sh <story_key> <slug>"
fi

STORY_KEY="$1"
SLUG="$2"
BRANCH_NAME="feat/${STORY_KEY}-${SLUG}"

WORK_DIR="${PROJECT_PATH:-.}"
cd "$WORK_DIR" || die "cannot cd to $WORK_DIR"

# Verify we are in a git repo
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  die "not a git repository: $WORK_DIR"
fi

# Check if the branch already exists (local)
if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME" 2>/dev/null; then
  log "branch '$BRANCH_NAME' already exists — collision detected"
  log "to resume work on this branch: git checkout $BRANCH_NAME"
  echo "already exists: $BRANCH_NAME"
  exit 0
fi

# Check if the branch exists on remote
if git show-ref --verify --quiet "refs/remotes/origin/$BRANCH_NAME" 2>/dev/null; then
  log "branch '$BRANCH_NAME' exists on remote — checking out"
  git checkout -b "$BRANCH_NAME" "origin/$BRANCH_NAME" 2>&1
  echo "checked out from remote: $BRANCH_NAME"
  exit 0
fi

# Create the branch from current HEAD
git checkout -b "$BRANCH_NAME" 2>&1
log "created branch: $BRANCH_NAME"
echo "created: $BRANCH_NAME"
exit 0
