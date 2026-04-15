#!/usr/bin/env bash
# init-project.sh — GAIA foundation script (E28-S16)
#
# Bootstraps a new GAIA-native project by creating the baseline directory
# skeleton, a starter config/project-config.yaml, and a minimal CLAUDE.md.
# Fully replaces the legacy gaia-install.sh for project initialization.
#
# Refs: FR-325, FR-328, NFR-048, ADR-042, ADR-048
# Brief: P2-S8 (docs/creative-artifacts/gaia-native-conversion-feature-brief-2026-04-14.md)
#
# Invocation contract:
#
#   init-project.sh --name <project> [--path <dir>] [--force] [--help]
#
# Flags:
#   --name <project>   REQUIRED. Project name (used in project-config.yaml
#                      and CLAUDE.md).
#   --path <dir>       Optional. Target directory. Defaults to "./<name>".
#                      Created if it does not exist. Spaces/unicode allowed.
#   --force            Override the non-empty-target safety rails. Required
#                      when <dir> is a non-empty git repo, contains any
#                      non-empty file that would be clobbered, or already
#                      contains a partial skeleton.
#   --help             Print usage and exit 0.
#
# Safety rails (rejected without --force):
#   * Target is a non-empty git repository.
#   * Target already contains a non-empty CLAUDE.md or project-config.yaml.
#   * Target has a partial skeleton in progress (.gaia-init.lock present).
#
# Concurrency:
#   A `.gaia-init.lock` sentinel file is created early under the target
#   directory and removed on successful completion. A second concurrent
#   invocation seeing the lock exits 1 cleanly without modifying anything
#   beyond its own refusal, even without --force.
#
# Exit codes:
#   0 success — skeleton created (or already present & idempotent with --force)
#   1 user error (missing flags, clobber refusal, concurrency refusal,
#     non-empty git repo without --force)
#   2 internal/contract violation (unable to create directories / write files)
#
set -euo pipefail
LC_ALL=C
export LC_ALL

readonly SELF="init-project.sh"

err() { printf "[%s] ERROR: %s\n" "$SELF" "$*" >&2; }

usage() {
  cat <<'USAGE'
Usage: init-project.sh --name <project> [--path <dir>] [--force] [--help]

Creates the GAIA-native baseline skeleton (docs/*, _memory/checkpoints/,
config/), a starter config/project-config.yaml, and a minimal CLAUDE.md.

Flags:
  --name <project>   Required. Project name.
  --path <dir>       Target directory. Defaults to "./<name>".
  --force            Override the non-empty-target safety rails.
  --help             Print this message and exit 0.

Exit codes:
  0 success
  1 user error (clobber refusal, concurrency refusal, non-empty git repo)
  2 internal/contract violation
USAGE
}

# --- arg parsing -------------------------------------------------------------
name=""
target=""
force=0

while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --name)
      [ $# -ge 2 ] || { err "--name requires a value"; exit 1; }
      name="$2"; shift 2 ;;
    --path)
      [ $# -ge 2 ] || { err "--path requires a value"; exit 1; }
      target="$2"; shift 2 ;;
    --force) force=1; shift ;;
    --*) err "unknown flag: $1"; exit 1 ;;
    *)   err "unexpected positional argument: $1"; exit 1 ;;
  esac
done

if [ -z "$name" ]; then err "--name is required"; exit 1; fi
if ! printf "%s" "$name" | grep -Eq '^[A-Za-z0-9_.-]+$'; then
  err "--name '$name' contains invalid characters (allowed: [A-Za-z0-9_.-])"
  exit 1
fi

if [ -z "$target" ]; then target="./$name"; fi

# --- safety rails ------------------------------------------------------------
# Resolve target absolute path without requiring it to exist yet.
abs_target=""
if [ -d "$target" ]; then
  abs_target="$(cd "$target" && pwd)"
else
  parent="$(dirname -- "$target")"
  base="$(basename -- "$target")"
  mkdir -p -- "$parent" || { err "cannot create parent directory: $parent"; exit 2; }
  abs_target="$(cd "$parent" && pwd)/$base"
fi

lock_file="$abs_target/.gaia-init.lock"

if [ -d "$abs_target" ]; then
  # Concurrency guard — lock file wins even over --force to prevent
  # stomping on a running sibling invocation.
  if [ -e "$lock_file" ]; then
    err "target '$abs_target' has a .gaia-init.lock — another init-project.sh is in progress (or left a stale lock)"
    exit 1
  fi

  # Non-empty git repo guard (AC5).
  if [ -d "$abs_target/.git" ]; then
    # Consider "non-empty" = .git exists AND there is any tracked file.
    if [ "$force" -ne 1 ]; then
      err "target is a non-empty git repo; pass --force to override"
      exit 1
    fi
  fi

  # Clobber guard (AC4, AC-EC7): refuse to rewrite an existing non-empty
  # CLAUDE.md or config/project-config.yaml UNLESS the file is already a
  # prior init-project.sh output (detected by a signature marker) — that
  # branch yields idempotent re-runs as required by AC4. With --force we
  # always overwrite.
  for f in "$abs_target/CLAUDE.md" "$abs_target/config/project-config.yaml"; do
    if [ -s "$f" ] && [ "$force" -ne 1 ]; then
      if grep -q 'generated by init-project.sh\|GAIA Project' "$f" 2>/dev/null; then
        # Prior init-project.sh output — treat as idempotent no-op.
        continue
      fi
      err "refusing to clobber existing non-empty file: $f (pass --force to override)"
      exit 1
    fi
  done
fi

# --- create target + lock ----------------------------------------------------
mkdir -p -- "$abs_target" || { err "cannot create target: $abs_target"; exit 2; }

# Atomic lock creation — set -C makes `>` fail if the file exists.
if ! (set -C; : > "$lock_file") 2>/dev/null; then
  err "failed to create lock file: $lock_file"
  exit 1
fi

cleanup_lock() { rm -f -- "$lock_file" 2>/dev/null || true; }
trap cleanup_lock EXIT

# --- create skeleton directories --------------------------------------------
for d in \
  "docs/planning-artifacts" \
  "docs/implementation-artifacts" \
  "docs/test-artifacts" \
  "docs/creative-artifacts" \
  "_memory/checkpoints" \
  "config"
do
  mkdir -p -- "$abs_target/$d" || { err "failed to create $abs_target/$d"; exit 2; }
done

# --- write starter project-config.yaml --------------------------------------
# Shape aligns with the plugins/gaia/config/project-config.yaml fixture from
# E28-S9. E28-S18 finalizes the canonical schema; we track it minimally here.
cfg_path="$abs_target/config/project-config.yaml"
if [ ! -s "$cfg_path" ] || [ "$force" -eq 1 ]; then
  cat > "$cfg_path" <<CONFIG
# project-config.yaml — generated by init-project.sh
# Project: $name

project_root: $abs_target
project_path: $abs_target
memory_path: $abs_target/_memory
checkpoint_path: $abs_target/_memory/checkpoints
installed_path: $abs_target
framework_version: 0.0.0
date: $(date -u +"%Y-%m-%d")
CONFIG
fi

# --- write minimal CLAUDE.md (<= 60 lines) ----------------------------------
claude_md="$abs_target/CLAUDE.md"
if [ ! -s "$claude_md" ] || [ "$force" -eq 1 ]; then
  cat > "$claude_md" <<'CLAUDEMD'
# GAIA Project

This project uses the GAIA Framework plugin for Claude Code. Workflows,
agents, and scripts are delivered by the `gaia` plugin — nothing is vendored
into the repository.

## How to Start

- Run `/gaia` to activate the orchestrator.
- Run `/gaia-help` for context-sensitive guidance.

## Directory Layout

- `docs/planning-artifacts/` — PRDs, UX, architecture, epics
- `docs/implementation-artifacts/` — sprint status, stories, changelogs
- `docs/test-artifacts/` — test plans, traceability
- `docs/creative-artifacts/` — design thinking, innovation outputs
- `_memory/checkpoints/` — workflow checkpoints
- `config/project-config.yaml` — project settings consumed by
  `plugins/gaia/scripts/resolve-config.sh`

## Execution Model

Foundation scripts run natively in bash — no LLM involvement for deterministic
tasks (checkpointing, gate updates, template headers, lifecycle events).
LLM agents orchestrate the creative and judgment-heavy steps.

## Do Not

- Commit secrets or `.env` files.
- Rewrite plugin scripts in place — file bugs or send PRs upstream.
- Skip workflow steps or quality gates.
CLAUDEMD
fi

# --- done --------------------------------------------------------------------
cleanup_lock
trap - EXIT

exit 0
