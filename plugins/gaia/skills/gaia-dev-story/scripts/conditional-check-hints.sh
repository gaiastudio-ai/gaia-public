#!/usr/bin/env bash
# conditional-check-hints.sh — gaia-dev-story Step 6b advisory hints (E55-S7)
#
# Purpose:
#   After Step 6 TDD Green, scan the staged file list for change patterns that
#   commonly carry hidden risk and emit a SINGLE advisory line per matching
#   category. Pure advisory: this script NEVER halts the workflow — exit code
#   is always 0. The agent reads the advisories and decides whether to address
#   them in the current story or capture them as Findings.
#
# Patterns (FR-DSH-9 / ADR-073):
#   1. API route changes — any path matching `*/routes/*.{ts,py,go}` OR
#      `*/api/*.{ts,py,go}`. Emits:
#        advisory: api-route changes detected — verify contract tests cover
#        the new/modified endpoints. files=<csv>
#   2. Schema/migration changes — any path matching `*/migrations/*.sql` OR a
#      basename containing `schema` with extension `.ts`/`.py`/`.sql`. Emits:
#        advisory: schema/migration changes detected — verify migration script
#        runs cleanly forward and (if applicable) backward. files=<csv>
#   3. Large blast radius — total staged file count >= BLAST_RADIUS_THRESHOLD
#      (default 10). Emits:
#        advisory: large blast radius (N files) — consider feature-flag
#        candidacy review. count=N
#
# Each category emits exactly ONE advisory line; the file list is comma-
# separated and capped at the first 10 paths followed by `,...` if truncated.
#
# Usage:
#   conditional-check-hints.sh [file ...]
#     Reads the staged file list from `git diff --cached --name-only` when no
#     positional args are supplied. For testability, callers MAY pass an
#     explicit list of paths as positional args; the script then bypasses git.
#
# Environment:
#   BLAST_RADIUS_THRESHOLD — integer file-count threshold for the blast-radius
#                            advisory (default 10). Tunable for calibration
#                            without re-shipping; documented in the story
#                            E55-S7 Dev Notes.
#
# Exit codes:
#   0 — always (advisories are informational, never blocking).

set -euo pipefail
LC_ALL=C
export LC_ALL

THRESHOLD="${BLAST_RADIUS_THRESHOLD:-10}"

# ---------- Gather staged file list ----------

files=()
if [ "$#" -gt 0 ]; then
  # Explicit list provided — bypass git.
  for f in "$@"; do
    files+=("$f")
  done
else
  # Read from git's staged set. Use mapfile when available (bash 4+); fall
  # back to a while-read loop for older bash. Tolerate `git` not being
  # available or there being no repo — the helper is non-fatal.
  if command -v git >/dev/null 2>&1; then
    while IFS= read -r line; do
      [ -n "$line" ] && files+=("$line")
    done < <(git diff --cached --name-only 2>/dev/null || true)
  fi
fi

# ---------- Pattern matching ----------

api_files=()
schema_files=()
for f in "${files[@]+"${files[@]}"}"; do
  # Pattern 1: API route — `*/routes/*.{ts,py,go}` OR `*/api/*.{ts,py,go}`.
  if [[ "$f" =~ (^|/)(routes|api)/.+\.(ts|py|go)$ ]]; then
    api_files+=("$f")
  fi
  # Pattern 2: Schema/migration — `*/migrations/*.sql` OR a basename
  # containing `schema` with extension `.ts`/`.py`/`.sql`.
  base="${f##*/}"
  if [[ "$f" =~ (^|/)migrations/.+\.sql$ ]] \
     || [[ "$base" =~ schema.*\.(ts|py|sql)$ ]]; then
    schema_files+=("$f")
  fi
done

# ---------- Format helper ----------

# format_files <path...> — emit a comma-separated list of up to the first 10
# paths; if more are present, append `,...` to indicate truncation.
format_files() {
  local -a arr=("$@")
  local n="${#arr[@]}"
  local i
  if (( n <= 10 )); then
    local IFS=','
    printf '%s' "${arr[*]}"
  else
    local first10=("${arr[@]:0:10}")
    local IFS=','
    printf '%s,...' "${first10[*]}"
  fi
}

# ---------- Emit advisories ----------

if (( "${#api_files[@]}" > 0 )); then
  printf 'advisory: api-route changes detected — verify contract tests cover the new/modified endpoints. files=%s\n' \
    "$(format_files "${api_files[@]}")"
fi

if (( "${#schema_files[@]}" > 0 )); then
  printf 'advisory: schema/migration changes detected — verify migration script runs cleanly forward and (if applicable) backward. files=%s\n' \
    "$(format_files "${schema_files[@]}")"
fi

if (( "${#files[@]}" >= THRESHOLD )); then
  printf 'advisory: large blast radius (%d files) — consider feature-flag candidacy review. count=%d\n' \
    "${#files[@]}" "${#files[@]}"
fi

exit 0
