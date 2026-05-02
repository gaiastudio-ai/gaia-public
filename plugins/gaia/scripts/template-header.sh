#!/usr/bin/env bash
# template-header.sh — GAIA foundation script (E28-S16)
#
# Emits a deterministic markdown template metadata header block to stdout.
# No filesystem side effects — stdout-only. Consumed by template generators
# and workflow authoring tools so that template headers are byte-stable
# across runs for the same inputs (modulo date), never depending on an LLM.
#
# Refs: FR-325, FR-328, NFR-048, ADR-042, ADR-048
# Brief: P2-S8 (docs/creative-artifacts/narratives/gaia-native-conversion-feature-brief-2026-04-14.md)
#
# Invocation contract:
#
#   template-header.sh --template <name> --workflow <name> [--var key=val ...] [--force] [--help]
#
# Required flags:
#   --template <name>   Template identifier (letters/digits/_/-)
#   --workflow <name>   Workflow identifier (letters/digits/_/-)
#
# Optional flags:
#   --var key=val       Extra key/value metadata. Repeatable. The key MUST
#                       match ^[A-Za-z_][A-Za-z0-9_]*$ — empty keys and shell
#                       metacharacters are rejected. The value is passed
#                       through as a single-quoted string (literal: no
#                       expansion), so shell metacharacters in values are
#                       safe by construction.
#   --force             Reserved for future use. Accepted but ignored — the
#                       script never writes to disk, so there is nothing to
#                       clobber. Present for contract parity with the other
#                       foundation scripts in the plugin.
#   --help              Print usage and exit 0.
#
# Exit codes:
#   0  success — header emitted to stdout
#   1  user error (bad flags, bad --var, missing required flag)
#   2  internal/contract violation (resolve-config.sh unavailable AND
#      plugin.json fallback failed)
#
# Output format (stable, diff-friendly, single trailing newline):
#
#   <!-- GAIA template header -->
#   workflow: <workflow>
#   template: <template>
#   date: <ISO 8601 UTC>
#   framework_version: <resolved>
#   <sorted key: 'value' lines for each --var>
#   <!-- /GAIA template header -->
#
# Determinism rules:
#   * Fixed key order for the first four lines (workflow, template, date,
#     framework_version).
#   * --var entries are sorted by key (LC_ALL=C) so callers cannot leak
#     argv order into the output.
#   * Values from --var are rendered as single-quoted literals; a literal
#     single quote inside the value is rendered as '\''.
#   * The date line is the ONLY source of run-to-run churn. Callers that
#     need fully byte-stable output can set SOURCE_DATE_EPOCH (honored here
#     per the reproducible-builds convention) to freeze the date.
#
set -euo pipefail
LC_ALL=C
export LC_ALL

readonly SELF="template-header.sh"

err() { printf "[%s] ERROR: %s\n" "$SELF" "$*" >&2; }

usage() {
  cat <<'USAGE'
Usage: template-header.sh --template <name> --workflow <name> [--var key=val ...] [--force] [--help]

Emits a deterministic markdown template metadata header block to stdout.

Required:
  --template <name>   Template identifier (e.g. story, prd, architecture)
  --workflow <name>   Workflow identifier (e.g. create-story)

Optional:
  --var key=val       Extra metadata. Repeatable. Key must match
                      ^[A-Za-z_][A-Za-z0-9_]*$. Value is rendered as a
                      single-quoted literal (shell-safe).
  --force             Accepted for contract parity; ignored (no disk writes).
  --help              Print this message and exit 0.

Exit codes:
  0  success
  1  user error
  2  internal/contract violation (resolve-config.sh + plugin.json both unavailable)
USAGE
}

# --- single-quote escape for values (POSIX-safe) ----------------------------
sq_escape() {
  # Escape embedded single quotes: ' -> '\''
  printf "%s" "$1" | sed "s/'/'\\\\''/g"
}

# --- resolve framework_version ----------------------------------------------
resolve_framework_version() {
  local version=""

  # Preferred: resolve-config.sh on PATH (or co-located next to this script).
  local here
  here="$(cd "$(dirname "$0")" && pwd)"

  local resolver=""
  if command -v resolve-config.sh >/dev/null 2>&1; then
    resolver="$(command -v resolve-config.sh)"
  elif [ -x "$here/resolve-config.sh" ]; then
    resolver="$here/resolve-config.sh"
  fi

  if [ -n "$resolver" ]; then
    # Use default KEY='VALUE' output and grep the line.
    local line
    if line="$("$resolver" 2>/dev/null | grep -E "^framework_version=" || true)"; then
      # Strip KEY= and the surrounding single quotes.
      version="${line#framework_version=}"
      version="${version#\'}"
      version="${version%\'}"
    fi
  fi

  # Fallback: read plugin.json directly.
  if [ -z "$version" ]; then
    local plugin_json="$here/../.claude-plugin/plugin.json"
    if [ -f "$plugin_json" ]; then
      # Grep-based extraction (no jq dependency).
      version="$(grep -E '"version"[[:space:]]*:' "$plugin_json" \
                 | head -n 1 \
                 | sed -E 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')"
    fi
  fi

  if [ -z "$version" ]; then
    err "framework_version could not be resolved (resolve-config.sh unavailable and plugin.json missing)"
    return 2
  fi

  printf "%s" "$version"
}

# --- ISO 8601 UTC date -------------------------------------------------------
iso_date() {
  # Honor SOURCE_DATE_EPOCH for byte-stable reproducibility.
  if [ -n "${SOURCE_DATE_EPOCH:-}" ]; then
    # BSD date first (macOS), GNU date fallback (Linux).
    date -u -r "$SOURCE_DATE_EPOCH" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
      || date -u -d "@$SOURCE_DATE_EPOCH" +"%Y-%m-%dT%H:%M:%SZ"
  else
    date -u +"%Y-%m-%dT%H:%M:%SZ"
  fi
}

# --- arg parsing -------------------------------------------------------------
template=""
workflow=""
# vars_keys/vars_vals indexed arrays keep the pair together while sorting.
vars_keys=()
vars_vals=()
force=0

while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h)
      usage
      exit 0
      ;;
    --template)
      [ $# -ge 2 ] || { err "--template requires a value"; exit 1; }
      template="$2"; shift 2
      ;;
    --workflow)
      [ $# -ge 2 ] || { err "--workflow requires a value"; exit 1; }
      workflow="$2"; shift 2
      ;;
    --var)
      [ $# -ge 2 ] || { err "--var requires a key=val pair"; exit 1; }
      pair="$2"; shift 2
      case "$pair" in
        *=*) : ;;
        *)   err "--var pair must be key=val, got: $pair"; exit 1 ;;
      esac
      key="${pair%%=*}"
      val="${pair#*=}"
      if [ -z "$key" ]; then
        err "--var key is empty"
        exit 1
      fi
      if ! printf "%s" "$key" | grep -Eq '^[A-Za-z_][A-Za-z0-9_]*$'; then
        err "--var key '$key' is not a valid identifier (must match ^[A-Za-z_][A-Za-z0-9_]*$)"
        exit 1
      fi
      vars_keys+=("$key")
      vars_vals+=("$val")
      ;;
    --force)
      force=1; shift
      ;;
    --*)
      err "unknown flag: $1"
      exit 1
      ;;
    *)
      err "unexpected positional argument: $1"
      exit 1
      ;;
  esac
done

# Silence "unused variable" warning under set -u — --force is contract parity.
: "${force}"

if [ -z "$template" ]; then err "--template is required"; exit 1; fi
if [ -z "$workflow" ]; then err "--workflow is required"; exit 1; fi

# Validate template/workflow identifiers too.
if ! printf "%s" "$template" | grep -Eq '^[A-Za-z0-9_./-]+$'; then
  err "--template value '$template' contains invalid characters"
  exit 1
fi
if ! printf "%s" "$workflow" | grep -Eq '^[A-Za-z0-9_./-]+$'; then
  err "--workflow value '$workflow' contains invalid characters"
  exit 1
fi

# --- resolve framework_version (may exit 2) ---------------------------------
framework_version="$(resolve_framework_version)"

# --- render header -----------------------------------------------------------
date_str="$(iso_date)"

{
  printf "<!-- GAIA template header -->\n"
  printf "workflow: %s\n" "$workflow"
  printf "template: %s\n" "$template"
  printf "date: %s\n" "$date_str"
  printf "framework_version: %s\n" "$framework_version"

  # Sort --var pairs by key (LC_ALL=C so sort is byte-stable).
  if [ "${#vars_keys[@]}" -gt 0 ]; then
    i=0
    # Build "key<TAB>val" lines, sort, then render.
    tmp_lines=""
    while [ $i -lt "${#vars_keys[@]}" ]; do
      k="${vars_keys[$i]}"
      v="${vars_vals[$i]}"
      # Use a Record Separator (0x1e) to keep tabs/spaces safe in the value.
      tmp_lines="${tmp_lines}${k}"$'\x1e'"${v}"$'\n'
      i=$((i + 1))
    done
    sorted="$(printf "%s" "$tmp_lines" | sort)"
    # Walk sorted lines and emit.
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      k="${line%%$'\x1e'*}"
      v="${line#*$'\x1e'}"
      esc="$(sq_escape "$v")"
      printf "%s: '%s'\n" "$k" "$esc"
    done <<EOF
$sorted
EOF
  fi

  printf "<!-- /GAIA template header -->\n"
}

exit 0
