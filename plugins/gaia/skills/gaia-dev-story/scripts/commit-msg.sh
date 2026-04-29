#!/usr/bin/env bash
# commit-msg.sh — gaia-dev-story Step 10 commit-message helper (E57-S7, P1-3)
#
# Reads a story file's YAML frontmatter (key, title, type) and emits a
# Conventional Commit message on stdout. The output is safe to feed to
# `git commit -F -`.
#
# Refs: FR-DSS-5, FR-DSS-6, NFR-DSS-1, AF-2026-04-28-6
# Story: E57-S7
#
# Usage:
#   commit-msg.sh <story_path>
#
# Output (subject line + optional body):
#   <type>(<story_key>): <story_title>
#
# Type mapping (from frontmatter `type:` field):
#   feature  -> feat
#   bug      -> fix
#   refactor -> refactor
#   chore    -> chore
#   missing or unrecognized -> feat (default)
#
# The subject line matches:
#   ^(feat|fix|refactor|chore)\([A-Z][0-9]+-S[0-9]+\): .+$
#
# Hard rules (per CLAUDE.md):
#   - The shell-builtin string-execution primitive is banned outright.
#     Frontmatter is parsed via awk; values flow through `printf '%s'` —
#     never echo, never command substitution into shell.
#   - No `Claude`, `AI`, or `Co-Authored-By` strings emitted.
#
# Exit codes:
#   0 — success; message printed on stdout.
#   1 — usage error / missing file.
#   2 — malformed frontmatter / missing required field (key or title).

set -euo pipefail
LC_ALL=C
export LC_ALL

SCRIPT_NAME="gaia-dev-story/commit-msg.sh"

log() { printf '%s: %s\n' "$SCRIPT_NAME" "$*" >&2; }
die_usage() { log "$*"; exit 1; }
die_parse() { log "$*"; exit 2; }

# --- Arg validation -------------------------------------------------------

if [ $# -lt 1 ]; then
  die_usage "usage: commit-msg.sh <story_path>"
fi

STORY_PATH_INPUT="$1"

# Path-traversal rejection (defense in depth)
case "$STORY_PATH_INPUT" in
  *..*) die_usage "path traversal rejected: $STORY_PATH_INPUT" ;;
esac

if [ ! -f "$STORY_PATH_INPUT" ]; then
  die_usage "story file not found: $STORY_PATH_INPUT"
fi

# --- Frontmatter extraction -----------------------------------------------
#
# Mirrors the get_field idiom from story-parse.sh. Reads the first frontmatter
# block (between the leading `---` markers) and pulls a single key's value.
# Strips surrounding single or double quotes. Returns empty string if absent.

FRONTMATTER="$(awk '
  BEGIN { state = 0 }
  state == 0 && $0 == "---" { state = 1; next }
  state == 1 && $0 == "---" { state = 2; exit }
  state == 1 { print }
  END { if (state != 2) exit 1 }
' "$STORY_PATH_INPUT")" || die_parse "malformed frontmatter (unbalanced '---' markers): $STORY_PATH_INPUT"

get_field() {
  key="$1"
  printf '%s\n' "$FRONTMATTER" | awk -v key="$key" '
    {
      if (match($0, "^[[:space:]]*" key "[[:space:]]*:[[:space:]]*")) {
        rest = substr($0, RSTART + RLENGTH)
        sub(/[[:space:]]+$/, "", rest)
        n = length(rest)
        if (n >= 2 && substr(rest, 1, 1) == "\"" && substr(rest, n, 1) == "\"") {
          print substr(rest, 2, n - 2); exit
        }
        if (n >= 2 && substr(rest, 1, 1) == "'"'"'" && substr(rest, n, 1) == "'"'"'") {
          print substr(rest, 2, n - 2); exit
        }
        print rest; exit
      }
    }
  '
}

STORY_KEY_VAL="$(get_field key)"
TITLE_VAL="$(get_field title)"
TYPE_VAL="$(get_field type)"

if [ -z "$STORY_KEY_VAL" ]; then
  die_parse "missing required frontmatter field: key"
fi
if [ -z "$TITLE_VAL" ]; then
  die_parse "missing required frontmatter field: title"
fi

# --- Type mapping ---------------------------------------------------------

case "$TYPE_VAL" in
  feature)  PREFIX="feat" ;;
  bug)      PREFIX="fix" ;;
  refactor) PREFIX="refactor" ;;
  chore)    PREFIX="chore" ;;
  *)        PREFIX="feat" ;;  # default for unrecognized or missing
esac

# --- Title sanitization ---------------------------------------------------
#
# Newlines must not break the single-line subject contract. Carriage returns
# get the same treatment for safety against CRLF input.
TITLE_ONELINE="$(printf '%s' "$TITLE_VAL" | tr '\r\n' '  ')"

# --- Subject construction + 72-char cap -----------------------------------
#
# Build the subject and truncate to 72 chars. bash parameter expansion is
# byte-based; LC_ALL=C is set so length math is consistent.
SUBJECT="$(printf '%s(%s): %s' "$PREFIX" "$STORY_KEY_VAL" "$TITLE_ONELINE")"
if [ "${#SUBJECT}" -gt 72 ]; then
  SUBJECT="${SUBJECT:0:72}"
fi

# --- Emit ----------------------------------------------------------------
#
# Subject line only — body lines (traces-to, validates) are out of scope for
# the AC contract. Adding them later is a non-breaking change.
printf '%s\n' "$SUBJECT"

exit 0
