#!/usr/bin/env bash
# next-step.sh — GAIA foundation script (E28-S16)
#
# Suggests the next workflow command for a given current workflow by reading
# the resolved `lifecycle-sequence.yaml` and cross-checking every candidate
# command name against `workflow-manifest.csv`. Codifies the CLAUDE.md
# invariant "never invent command names" as an exit-2 guard.
#
# Refs: FR-325, FR-328, NFR-048, ADR-042, ADR-048
# Brief: P2-S8 (docs/creative-artifacts/gaia-native-conversion-feature-brief-2026-04-14.md)
#
# Invocation contract:
#
#   next-step.sh --workflow <current> [--story <key>] [--status <result>] [--help]
#
# Flags:
#   --workflow <name>  REQUIRED. Current workflow name (the sequence key, not
#                      the slash command). e.g. "create-story", "dev-story".
#   --story <key>      Optional. Story key for contextual suggestions.
#                      Accepted but not currently used for branch selection.
#   --status <result>  Optional. "pass" | "fail". When set and the sequence
#                      entry declares next.on_pass / next.on_fail, pick the
#                      matching branch instead of next.primary.
#   --help             Print usage and exit 0.
#
# Exit codes:
#   0  success — suggestion printed to stdout
#   1  user error (unknown workflow, bad args)
#   2  internal/contract violation (malformed yaml, unresolved command name,
#      missing sequence/manifest files)
#
# Output (stable, newline-terminated):
#   primary:<SPACE><command>
#   [alternatives:<SPACE><command>] (one per line)
#   [on_pass:<SPACE><command>]
#   [on_fail:<SPACE><command>]
#   [standalone:<SPACE>true]
#   [suggestions:<SPACE><command>] (one per line)
#
# Dependencies:
#   * resolve-config.sh (soft — used only if present; otherwise this script
#     falls back to a co-located default set of paths).
#   * yq (required for yaml parsing).
#   * awk (POSIX, for csv parsing).
#
set -euo pipefail
LC_ALL=C
export LC_ALL

readonly SELF="next-step.sh"

err() { printf "[%s] ERROR: %s\n" "$SELF" "$*" >&2; }

usage() {
  cat <<'USAGE'
Usage: next-step.sh --workflow <current> [--story <key>] [--status <pass|fail>] [--help]

Prints the suggested next workflow command(s) for <current>, read from
lifecycle-sequence.yaml and verified against workflow-manifest.csv.

Flags:
  --workflow <name>  Required. Current sequence key (e.g. create-story).
  --story <key>      Optional. Story key for context. Not used for branch
                     selection yet.
  --status pass|fail Optional. Selects next.on_pass / next.on_fail branches.
  --help             Print this message and exit 0.

Exit codes:
  0 success
  1 user error (unknown workflow)
  2 internal/contract violation (bad yaml, unresolved command, missing files)
USAGE
}

# --- resolve paths to lifecycle-sequence.yaml and workflow-manifest.csv -----
resolve_paths() {
  local here installed_path sequence_file manifest_file

  here="$(cd "$(dirname "$0")" && pwd)"

  # Preferred: ask resolve-config.sh for installed_path.
  local resolver=""
  if command -v resolve-config.sh >/dev/null 2>&1; then
    resolver="$(command -v resolve-config.sh)"
  elif [ -x "$here/resolve-config.sh" ]; then
    resolver="$here/resolve-config.sh"
  fi

  installed_path=""
  if [ -n "$resolver" ]; then
    local line
    line="$("$resolver" 2>/dev/null | grep -E "^installed_path=" || true)"
    if [ -n "$line" ]; then
      installed_path="${line#installed_path=}"
      installed_path="${installed_path#\'}"
      installed_path="${installed_path%\'}"
    fi
  fi

  # Search strategy — canonical first, then plugin-local fallbacks.
  local candidates_seq=()
  local candidates_man=()

  if [ -n "$installed_path" ]; then
    candidates_seq+=("$installed_path/_config/lifecycle-sequence.yaml")
    candidates_man+=("$installed_path/_config/workflow-manifest.csv")
  fi

  candidates_seq+=("$here/../manifests/lifecycle-sequence.yaml")
  candidates_seq+=("$here/../../../_gaia/_config/lifecycle-sequence.yaml")

  candidates_man+=("$here/../manifests/workflow-manifest.csv")
  candidates_man+=("$here/../../../_gaia/_config/workflow-manifest.csv")

  sequence_file=""
  for c in "${candidates_seq[@]}"; do
    if [ -f "$c" ]; then sequence_file="$c"; break; fi
  done
  manifest_file=""
  for c in "${candidates_man[@]}"; do
    if [ -f "$c" ]; then manifest_file="$c"; break; fi
  done

  # E28-S126: graceful-missing-file fallback (Val v1 Finding 2).
  # Under the native plugin (post-ADR-048 cutover) lifecycle-sequence.yaml and
  # workflow-manifest.csv are retired. Print a clear notice and exit 0 — do NOT
  # treat absence as an error. Preserve the original exit-2 behavior only when
  # the caller sets GAIA_NEXT_STEP_STRICT=1 (opt-in for legacy callers).
  if [ -z "$sequence_file" ] || [ -z "$manifest_file" ]; then
    if [ "${GAIA_NEXT_STEP_STRICT:-0}" = "1" ]; then
      [ -z "$sequence_file" ] && err "lifecycle-sequence.yaml not found (searched: ${candidates_seq[*]})"
      [ -z "$manifest_file" ] && err "workflow-manifest.csv not found (searched: ${candidates_man[*]})"
      return 2
    fi
    # Print to stdout so callers that capture stdout see a predictable message.
    echo "next-step: legacy manifests not available under native plugin — nothing to suggest"
    return 10  # sentinel value: "no manifests" — callers treat as no-op, wrapper below exits 0
  fi

  printf "%s\n%s\n" "$sequence_file" "$manifest_file"
}

# --- verify a command name exists in workflow-manifest.csv ------------------
manifest_has_command() {
  local cmd="$1" manifest="$2"
  # workflow-manifest.csv header: name,displayName,description,module,phase,path,command,agent
  # Command column is index 7 (1-based). Values are double-quoted.
  # Strip any leading slash from cmd to be tolerant.
  local needle="${cmd#/}"
  # Compare against column 7 with surrounding quotes stripped.
  awk -F',' -v needle="$needle" '
    NR == 1 { next }
    {
      c = $7
      gsub(/"/, "", c)
      sub(/^\//, "", c)
      if (c == needle) { found = 1; exit }
    }
    END { exit (found ? 0 : 1) }
  ' "$manifest"
}

# --- arg parsing -------------------------------------------------------------
workflow=""
story=""
status_arg=""

while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --workflow)
      [ $# -ge 2 ] || { err "--workflow requires a value"; exit 1; }
      workflow="$2"; shift 2 ;;
    --story)
      [ $# -ge 2 ] || { err "--story requires a value"; exit 1; }
      story="$2"; shift 2 ;;
    --status)
      [ $# -ge 2 ] || { err "--status requires a value"; exit 1; }
      status_arg="$2"; shift 2 ;;
    --*) err "unknown flag: $1"; exit 1 ;;
    *)   err "unexpected positional argument: $1"; exit 1 ;;
  esac
done

: "${story}"  # reserved — silence set -u

if [ -z "$workflow" ]; then
  err "--workflow is required"
  exit 1
fi

case "$status_arg" in
  ""|pass|fail) : ;;
  *) err "--status must be 'pass' or 'fail' (got: $status_arg)"; exit 1 ;;
esac

# --- resolve files -----------------------------------------------------------
# E28-S126 graceful-missing-file fallback (Val v1 Finding 2):
# resolve_paths returns 10 when manifests are absent under the native plugin.
# In that case print the fallback notice (already printed inside resolve_paths)
# and exit 0 — next-step is a no-op in the native model.
paths_output="$(resolve_paths)" || rc=$?
if [ "${rc:-0}" -eq 10 ]; then
  printf "%s\n" "$paths_output"
  exit 0
fi
sequence_file="$(printf "%s\n" "$paths_output" | sed -n 1p)"
manifest_file="$(printf "%s\n" "$paths_output" | sed -n 2p)"

# --- require yq --------------------------------------------------------------
if ! command -v yq >/dev/null 2>&1; then
  err "yq is required to parse lifecycle-sequence.yaml but is not on PATH"
  exit 2
fi

# --- parse: does the workflow exist in the sequence? -----------------------
if ! yq ".sequence | has(\"$workflow\")" "$sequence_file" 2>/dev/null | grep -qx "true"; then
  # Distinguish "unknown workflow" (exit 1) from "malformed yaml" (exit 2).
  if ! yq '.sequence | keys' "$sequence_file" >/dev/null 2>&1; then
    err "failed to parse lifecycle-sequence.yaml"
    exit 2
  fi
  err "unknown workflow: $workflow"
  exit 1
fi

# --- collect candidate commands ---------------------------------------------
# We collect every command name we're about to print, so we can validate
# them all against workflow-manifest.csv BEFORE writing anything to stdout.
# (AC6: on mismatch, stdout MUST be empty.)

declare -a out_lines=()
declare -a all_commands=()

add_line()   { out_lines+=("$1"); }
add_command() { all_commands+=("$1"); }

read_yq() {
  # read_yq <path> — returns empty string if null/missing.
  local v
  v="$(yq -r "$1 // \"\"" "$sequence_file" 2>/dev/null || true)"
  printf "%s" "$v"
}

primary="$(read_yq ".sequence.\"$workflow\".next.primary")"
on_pass="$(read_yq ".sequence.\"$workflow\".next.on_pass")"
on_fail="$(read_yq ".sequence.\"$workflow\".next.on_fail")"
standalone="$(read_yq ".sequence.\"$workflow\".next.standalone")"

# Branch selection: --status overrides primary when the branch exists.
chosen_primary=""
if [ "$status_arg" = "pass" ] && [ -n "$on_pass" ]; then
  chosen_primary="$on_pass"
elif [ "$status_arg" = "fail" ] && [ -n "$on_fail" ]; then
  chosen_primary="$on_fail"
else
  chosen_primary="$primary"
fi

if [ -n "$chosen_primary" ]; then
  add_line "primary: $chosen_primary"
  add_command "$chosen_primary"
fi

# Alternatives (list of {command, context}).
alts="$(yq -r ".sequence.\"$workflow\".next.alternatives // [] | .[] | .command // \"\"" "$sequence_file" 2>/dev/null || true)"
if [ -n "$alts" ]; then
  while IFS= read -r cmd; do
    [ -n "$cmd" ] || continue
    add_line "alternative: $cmd"
    add_command "$cmd"
  done <<EOF
$alts
EOF
fi

# Suggestions (list of {command, context}).
sugs="$(yq -r ".sequence.\"$workflow\".next.suggestions // [] | .[] | .command // \"\"" "$sequence_file" 2>/dev/null || true)"
if [ -n "$sugs" ]; then
  while IFS= read -r cmd; do
    [ -n "$cmd" ] || continue
    add_line "suggestion: $cmd"
    add_command "$cmd"
  done <<EOF
$sugs
EOF
fi

if [ "$standalone" = "true" ]; then
  add_line "standalone: true"
fi

# --- verify every command exists in the manifest (AC2 / AC6) ---------------
for cmd in ${all_commands[@]+"${all_commands[@]}"}; do
  if ! manifest_has_command "$cmd" "$manifest_file"; then
    err "next-step command '$cmd' is not present in workflow-manifest.csv"
    exit 2
  fi
done

# --- emit, finally -----------------------------------------------------------
if [ "${#out_lines[@]}" -eq 0 ]; then
  # No next step defined — emit nothing, exit 0 (terminal workflow).
  exit 0
fi

for line in "${out_lines[@]}"; do
  printf "%s\n" "$line"
done

exit 0
