#!/usr/bin/env bash
# shell-idioms.sh — reusable shell helpers for GAIA scripts.
#
# This file is intended to be SOURCED, not executed:
#
#   source "$(dirname "$0")/../../../scripts/lib/shell-idioms.sh"
#
# Story: E20-S20 — Extract safe_grep_log() shell helper for the
#                  set -euo pipefail + grep-in-pipeline SIGPIPE pattern.
# Refs:  AC1, AC4. Companion docs in skills/gaia-shell-idioms/SKILL.md.
#
# All helpers are written for POSIX-compatible bash (3.2+ for macOS) and
# avoid GNU-only options.

# safe_grep_log — SIGPIPE-safe `git log | grep` replacement.
#
# Background:
#   `git log | grep -q PATTERN` combined with `set -euo pipefail` is unsafe.
#   When grep matches early it closes the pipe; git log then receives SIGPIPE
#   and exits 141. With `pipefail` set, the pipeline's overall status becomes
#   141 even though the user-visible outcome was "match found", and `set -e`
#   aborts the caller. The recurring workaround is to capture git log output
#   into a variable first, then grep the variable. This helper centralises
#   that workaround so every caller doesn't reinvent it.
#
# Usage:
#   safe_grep_log [grep_flags...] <pattern> [git_log_args...]
#
#   Any leading args starting with `-` are forwarded to grep (e.g. -i, -E,
#   -q). The first non-flag arg is the grep pattern. Remaining args are
#   forwarded to `git log` (e.g. --oneline, a branch name, --format='%B').
#
# Output:
#   Lines from `git log <git_log_args>` matching <pattern> are printed on
#   stdout, one per line.
#
# Exit codes:
#   0 — at least one matching line was found
#   1 — no matching lines (clean no-match; not an error)
#   2 — usage error (missing pattern)
#
# Examples:
#   # Was: git log --oneline main | grep -iqE "\bE20-S20\b"   (SIGPIPE-prone)
#   # Now: safe_grep_log -i -E "\bE20-S20\b" --oneline main
#
#   # Match against full commit bodies:
#   safe_grep_log -i -E "Story:[[:space:]]*E20-S20" --format='%B' main
#
# Implementation note: we run `git log` inside a command substitution so its
# stdout is captured fully BEFORE grep ever runs. That means grep can never
# close the pipe early on git, so SIGPIPE is impossible by construction.
# `|| true` on the capture line guards against `set -e` aborting on a git
# error (e.g. unknown branch); the empty capture then yields the expected
# exit-1 no-match.
safe_grep_log() {
  local grep_flags=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --) shift; break ;;
      -*) grep_flags+=("$1"); shift ;;
      *)  break ;;
    esac
  done

  if [ $# -lt 1 ]; then
    printf 'safe_grep_log: missing required <pattern> argument\n' >&2
    return 2
  fi

  local pattern="$1"; shift
  # Remaining args go to git log. May be empty.

  local log_output
  log_output="$(git log "$@" 2>/dev/null)" || true

  # Pipe the captured variable into grep. Because the producer is now `printf`
  # on a fully-realised string (not a long-lived git process), there is no
  # SIGPIPE risk and pipefail is harmless. grep returns 0 on match, 1 on
  # no-match — propagate that as our own exit code.
  # ${arr[@]+"${arr[@]}"} guards against the bash-3.2 + set -u "unbound
  # variable" trap on empty-array expansion. macOS still ships bash 3.2.
  #
  # We capture grep's exit code into `rc` rather than letting the pipeline's
  # status reach the caller directly. Otherwise, when the caller is running
  # under `set -e`, grep's expected exit-1 (clean no-match) would abort them.
  # This function's own contract — return 0 / 1 / 2 — is unaffected.
  local rc=0
  printf '%s\n' "$log_output" | grep ${grep_flags[@]+"${grep_flags[@]}"} -- "$pattern" || rc=$?
  return "$rc"
}
