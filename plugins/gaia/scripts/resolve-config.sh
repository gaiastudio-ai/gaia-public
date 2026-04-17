#!/usr/bin/env bash
# resolve-config.sh — GAIA foundation script (E28-S9, extended by E28-S142)
set -euo pipefail
LC_ALL=C
export LC_ALL
#
# Reads up to two input files and merges them:
#   - team-shared: ${CLAUDE_SKILL_DIR}/config/project-config.yaml
#                  (or --shared <path>, or --config <path> legacy alias)
#   - machine-local: global.yaml (or --local <path>)
# Applies GAIA_* environment overrides on top, validates required fields,
# and emits deterministic output on stdout:
#   - default:        KEY='VALUE' lines, single-quoted, alpha-sorted
#   - --format json:  a single JSON object with the same keys
#
# =============================================================================
# Config Split Merge (ADR-044 / E28-S141 / E28-S142)
# =============================================================================
# Two-file merge with strict precedence: env > local > shared.
# 1. Load the team-shared file (config/project-config.yaml) first as the
#    base layer. Missing → empty base layer (AC4 graceful fallback).
# 2. Overlay the machine-local file (global.yaml). Missing → no overlay.
# 3. Apply GAIA_* environment variables last; env wins over both layers.
#
# Flat merge on top-level keys — the resolver already flattens nested keys
# (e.g., val_integration.template_output_review) to dotted form, so the
# overlay happens at the flattened-key level. No structural deep-merge.
#
# See:
#   - gaia-public/plugins/gaia/config/project-config.schema.yaml (schema)
#   - gaia-public/plugins/gaia/config/MIGRATION-from-global-yaml.md
#   - architecture.md §10.26.6 (Config Split Diagram), §Decision Log ADR-044
# =============================================================================
#
# POSIX discipline: the only non-POSIX constructs tolerated in this file are
# [[ ... ]] tests and Bash indexed arrays; every other construct stays POSIX.
# The shebang is bash because this project standardizes on bash foundation
# scripts (ADR-048). LC_ALL=C pins sort order and locale for determinism.
# Intentionally avoids associative arrays so macOS /bin/bash 3.2 can run it.
#
# Required fields (checked on the merged, post-env map):
#   project_root, project_path, memory_path, checkpoint_path,
#   installed_path, framework_version, date
#
# Environment overrides (env wins over file values):
#   GAIA_PROJECT_ROOT    → project_root
#   GAIA_PROJECT_PATH    → project_path
#   GAIA_MEMORY_PATH     → memory_path
#   GAIA_CHECKPOINT_PATH → checkpoint_path
#
# Exit codes:
#   0 — success, all required fields resolved
#   2 — user/config error (missing file, missing field, parse error,
#       path traversal in project_path, no config path provided)
#
# Latency budget: <100ms on developer laptop (shell fast path; yq optional).
# Consumed by: every GAIA-native skill and downstream foundation script
# at startup — replaces the LLM-driven `.resolved/*.yaml` inheritance chain.

# ---------- Helpers ----------

die() {
  printf 'resolve-config: %s\n' "$1" >&2
  exit 2
}

shell_escape() {
  # Emit a single-quoted shell-safe literal. Embedded ' → '\''.
  local s="$1"
  local escaped
  escaped=$(printf '%s' "$s" | sed "s/'/'\\\\''/g")
  printf "'%s'" "$escaped"
}

json_escape() {
  local s="$1"
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  printf '%s' "$s"
}

parse_yaml_key() {
  # parse_yaml_key <file> <key> — print top-level flat key value, or empty.
  local file="$1" key="$2" line value
  [ -f "$file" ] || return 0
  line=$(grep -E "^${key}[[:space:]]*:" "$file" 2>/dev/null | head -n1 || true)
  [ -z "$line" ] && return 0
  value=${line#*:}
  # trim leading whitespace
  value=${value#"${value%%[![:space:]]*}"}
  # trim trailing whitespace
  value=${value%"${value##*[![:space:]]}"}
  # strip balanced surrounding quotes
  case "$value" in
    \"*\") value=${value#\"}; value=${value%\"} ;;
    \'*\') value=${value#\'}; value=${value%\'} ;;
  esac
  printf '%s' "$value"
}

parse_yaml_nested_key() {
  # parse_yaml_nested_key <file> <parent> <child> — print the value of
  # `parent.child` where the YAML looks like:
  #   parent:
  #     child: value
  # Prints empty if the key is absent. Handles single-line comments.
  local file="$1" parent="$2" child="$3"
  [ -f "$file" ] || return 0
  awk -v P="$parent" -v C="$child" '
    BEGIN { in_parent=0 }
    # End of the parent block: a new non-indented key line.
    /^[A-Za-z_][A-Za-z0-9_]*[[:space:]]*:/ {
      if (in_parent) { in_parent=0 }
    }
    $0 ~ "^"P"[[:space:]]*:[[:space:]]*$" { in_parent=1; next }
    in_parent && $0 ~ "^[[:space:]]+"C"[[:space:]]*:" {
      line=$0
      sub(/^[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*:[[:space:]]*/, "", line)
      sub(/[[:space:]]+$/, "", line)
      sub(/[[:space:]]+#.*$/, "", line)
      # strip balanced surrounding quotes
      if (line ~ /^".*"$/) { line=substr(line, 2, length(line)-2) }
      else if (line ~ /^\x27.*\x27$/) { line=substr(line, 2, length(line)-2) }
      print line
      exit
    }
  ' "$file"
}

validate_yaml_basic() {
  local file="$1"
  [ -f "$file" ] || return 0
  # Reject unclosed bracket on a value line.
  if grep -qE '^[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*:[[:space:]]*\[[^]]*$' "$file"; then
    return 1
  fi
  # Reject lines with multiple bare colons — breaks flat-key invariant.
  if grep -qE '^[[:space:]]*[^#[:space:]].*:[[:space:]]*:[[:space:]]*:' "$file"; then
    return 1
  fi
  return 0
}

# validate_schema — E28-S18 / ADR-044 enforcement.
# Reads project-config.schema.yaml (sibling of the config file by default,
# or overridden via --schema) and rejects any top-level key in the config
# file that is not declared under `fields:` in the schema. Unknown keys
# exit with code 2 and a clear stderr message per AC5.
validate_schema() {
  local config="$1" schema="$2"
  [ -f "$config" ] || return 0  # no config → nothing to validate
  [ -f "$schema" ] || return 0  # schema optional — silent no-op if absent
  # Extract declared field names from schema: lines matching "  <name>:"
  # exactly two-space-indented inside the fields: block.
  local allowed
  allowed=$(awk '
    /^fields:[[:space:]]*$/ { in_fields=1; next }
    in_fields && /^[^[:space:]]/ { in_fields=0 }
    in_fields && /^  [a-zA-Z_][a-zA-Z0-9_]*:[[:space:]]*$/ {
      gsub(/^  /,""); gsub(/:.*/,""); print
    }
  ' "$schema")
  # Extract top-level keys from config: zero-indent "<name>:" lines,
  # skipping comments and blanks.
  local config_keys
  config_keys=$(awk '
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*$/ { next }
    /^[a-zA-Z_][a-zA-Z0-9_]*:/ {
      k=$0; sub(/:.*/,"",k); print k
    }
  ' "$config")
  local key
  for key in $config_keys; do
    if ! printf '%s\n' "$allowed" | grep -qx "$key"; then
      printf 'resolve-config: unknown field in %s: %s (not declared in %s)\n' \
        "$config" "$key" "$schema" >&2
      exit 2
    fi
  done
}

# ---------- Argument parsing ----------
#
# New in E28-S142 — two-file merge:
#   --shared <path>   team-shared project-config.yaml (default: CLAUDE_SKILL_DIR/config/project-config.yaml)
#   --local <path>    machine-local global.yaml (no default — omitted when absent)
#
# Legacy alias (E28-S9 single-file mode):
#   --config <path>   equivalent to --shared <path>; kept for backward compat.

SHARED_PATH=""
LOCAL_PATH=""
SCHEMA_PATH=""
FORMAT="shell"

while [ $# -gt 0 ]; do
  case "$1" in
    --shared)
      [ $# -ge 2 ] || die "flag --shared requires a path argument"
      SHARED_PATH="$2"; shift 2 ;;
    --shared=*)
      SHARED_PATH="${1#--shared=}"; shift ;;
    --local)
      [ $# -ge 2 ] || die "flag --local requires a path argument"
      LOCAL_PATH="$2"; shift 2 ;;
    --local=*)
      LOCAL_PATH="${1#--local=}"; shift ;;
    --config)
      [ $# -ge 2 ] || die "flag --config requires a path argument"
      SHARED_PATH="$2"; shift 2 ;;
    --config=*)
      SHARED_PATH="${1#--config=}"; shift ;;
    --schema)
      [ $# -ge 2 ] || die "flag --schema requires a path argument"
      SCHEMA_PATH="$2"; shift 2 ;;
    --schema=*)
      SCHEMA_PATH="${1#--schema=}"; shift ;;
    --format)
      [ $# -ge 2 ] || die "flag --format requires shell|json"
      FORMAT="$2"; shift 2 ;;
    --format=*)
      FORMAT="${1#--format=}"; shift ;;
    -h|--help)
      sed -n '1,56p' "$0" >&2; exit 0 ;;
    *)
      die "unknown argument: $1" ;;
  esac
done

case "$FORMAT" in
  shell|json) ;;
  *) die "unsupported --format '$FORMAT' (expected shell|json)" ;;
esac

# ---------- Shared-file discovery ----------

if [ -z "$SHARED_PATH" ]; then
  if [ -n "${CLAUDE_SKILL_DIR:-}" ]; then
    SHARED_PATH="${CLAUDE_SKILL_DIR}/config/project-config.yaml"
  fi
fi

# ---------- Detect "at least one input is present" ----------
#
# When both inputs are absent, fall back to the legacy AC-EC6 error so
# existing behavior is preserved (required CLAUDE_SKILL_DIR or --config).

SHARED_EXISTS=0
LOCAL_EXISTS=0
[ -n "$SHARED_PATH" ] && [ -f "$SHARED_PATH" ] && SHARED_EXISTS=1
[ -n "$LOCAL_PATH" ]  && [ -f "$LOCAL_PATH" ]  && LOCAL_EXISTS=1

if [ "$SHARED_EXISTS" -eq 0 ] && [ "$LOCAL_EXISTS" -eq 0 ]; then
  # Neither input resolvable — preserve existing error semantics.
  if [ -n "$SHARED_PATH" ]; then
    die "config file not found: $SHARED_PATH"
  elif [ -n "$LOCAL_PATH" ]; then
    die "config file not found: $LOCAL_PATH"
  else
    die "no config path — set CLAUDE_SKILL_DIR or pass --config <path>"
  fi
fi

# ---------- Parse validation (runs per-file so errors name the file) ----------

if [ "$SHARED_EXISTS" -eq 1 ] && ! validate_yaml_basic "$SHARED_PATH"; then
  die "parse error in $SHARED_PATH"
fi
if [ "$LOCAL_EXISTS" -eq 1 ] && ! validate_yaml_basic "$LOCAL_PATH"; then
  die "parse error in $LOCAL_PATH"
fi

# Schema enforcement on the shared file (authoritative schema surface).
# Default schema lives next to the shared file as project-config.schema.yaml.
if [ "$SHARED_EXISTS" -eq 1 ]; then
  if [ -z "$SCHEMA_PATH" ]; then
    SCHEMA_PATH="$(dirname "$SHARED_PATH")/project-config.schema.yaml"
  fi
  validate_schema "$SHARED_PATH" "$SCHEMA_PATH"
fi

# ---------- Merge layers: shared first, local overlays ----------
#
# Helper: read a flat top-level key from shared first, then prefer local if
# local defines it. Implemented as sequential reads because bash 3.2 has no
# associative arrays and the resolver's key surface is small & fixed.

merge_key() {
  local key="$1" v=""
  if [ "$SHARED_EXISTS" -eq 1 ]; then
    v=$(parse_yaml_key "$SHARED_PATH" "$key")
  fi
  if [ "$LOCAL_EXISTS" -eq 1 ]; then
    local lv
    lv=$(parse_yaml_key "$LOCAL_PATH" "$key")
    [ -n "$lv" ] && v="$lv"
  fi
  printf '%s' "$v"
}

merge_nested_key() {
  # merge_nested_key <parent> <child> — merge a YAML-nested key with the
  # same precedence rule as merge_key. Uses parse_yaml_nested_key so a
  # `parent:` block with `child: value` resolves correctly.
  local parent="$1" child="$2" v=""
  if [ "$SHARED_EXISTS" -eq 1 ]; then
    v=$(parse_yaml_nested_key "$SHARED_PATH" "$parent" "$child")
  fi
  if [ "$LOCAL_EXISTS" -eq 1 ]; then
    local lv
    lv=$(parse_yaml_nested_key "$LOCAL_PATH" "$parent" "$child")
    [ -n "$lv" ] && v="$lv"
  fi
  printf '%s' "$v"
}

v_checkpoint_path=$(merge_key checkpoint_path)
v_date=$(merge_key date)
v_framework_version=$(merge_key framework_version)
v_installed_path=$(merge_key installed_path)
v_memory_path=$(merge_key memory_path)
v_project_path=$(merge_key project_path)
v_project_root=$(merge_key project_root)

# Flattened nested keys — emitted as dotted keys so shell eval-friendly.
# Only val_integration.template_output_review is surfaced today; adding
# more flattened keys is a one-liner (future-proof).
v_val_integration_template_output_review=$(merge_nested_key val_integration template_output_review)

# ---------- Apply environment overrides (env wins) ----------

[ -n "${GAIA_PROJECT_ROOT:-}" ]    && v_project_root="$GAIA_PROJECT_ROOT"
[ -n "${GAIA_PROJECT_PATH:-}" ]    && v_project_path="$GAIA_PROJECT_PATH"
[ -n "${GAIA_MEMORY_PATH:-}" ]     && v_memory_path="$GAIA_MEMORY_PATH"
[ -n "${GAIA_CHECKPOINT_PATH:-}" ] && v_checkpoint_path="$GAIA_CHECKPOINT_PATH"

# ---------- Required-field check (post-merge, post-env) ----------

[ -z "$v_checkpoint_path" ]   && die "missing required field: checkpoint_path"
[ -z "$v_date" ]              && die "missing required field: date"
[ -z "$v_framework_version" ] && die "missing required field: framework_version"
[ -z "$v_installed_path" ]    && die "missing required field: installed_path"
[ -z "$v_memory_path" ]       && die "missing required field: memory_path"
[ -z "$v_project_path" ]      && die "missing required field: project_path"
[ -z "$v_project_root" ]      && die "missing required field: project_root"

# ---------- Path-traversal guard on project_path ----------

case "$v_project_path" in
  *..*) die "path traversal rejected in project_path: $v_project_path" ;;
esac

# ---------- Emit ----------

emit_pair_shell() {
  printf '%s=%s\n' "$1" "$(shell_escape "$2")"
}

if [ "$FORMAT" = "shell" ]; then
  # Alphabetical order, hard-coded to guarantee determinism. Flattened keys
  # are emitted only when they have a value so absent nested blocks do not
  # pollute the output surface.
  emit_pair_shell checkpoint_path   "$v_checkpoint_path"
  emit_pair_shell date              "$v_date"
  emit_pair_shell framework_version "$v_framework_version"
  emit_pair_shell installed_path    "$v_installed_path"
  emit_pair_shell memory_path       "$v_memory_path"
  emit_pair_shell project_path      "$v_project_path"
  emit_pair_shell project_root      "$v_project_root"
  if [ -n "$v_val_integration_template_output_review" ]; then
    emit_pair_shell val_integration.template_output_review \
      "$v_val_integration_template_output_review"
  fi
else
  if command -v jq >/dev/null 2>&1; then
    if [ -n "$v_val_integration_template_output_review" ]; then
      jq -n \
        --arg checkpoint_path   "$v_checkpoint_path" \
        --arg date              "$v_date" \
        --arg framework_version "$v_framework_version" \
        --arg installed_path    "$v_installed_path" \
        --arg memory_path       "$v_memory_path" \
        --arg project_path      "$v_project_path" \
        --arg project_root      "$v_project_root" \
        --arg val_template_output_review "$v_val_integration_template_output_review" \
        '{checkpoint_path: $checkpoint_path, date: $date, framework_version: $framework_version, installed_path: $installed_path, memory_path: $memory_path, project_path: $project_path, project_root: $project_root, "val_integration.template_output_review": $val_template_output_review}'
    else
      jq -n \
        --arg checkpoint_path   "$v_checkpoint_path" \
        --arg date              "$v_date" \
        --arg framework_version "$v_framework_version" \
        --arg installed_path    "$v_installed_path" \
        --arg memory_path       "$v_memory_path" \
        --arg project_path      "$v_project_path" \
        --arg project_root      "$v_project_root" \
        '{checkpoint_path: $checkpoint_path, date: $date, framework_version: $framework_version, installed_path: $installed_path, memory_path: $memory_path, project_path: $project_path, project_root: $project_root}'
    fi
  else
    printf '{"checkpoint_path": "%s", "date": "%s", "framework_version": "%s", "installed_path": "%s", "memory_path": "%s", "project_path": "%s", "project_root": "%s"}\n' \
      "$(json_escape "$v_checkpoint_path")" \
      "$(json_escape "$v_date")" \
      "$(json_escape "$v_framework_version")" \
      "$(json_escape "$v_installed_path")" \
      "$(json_escape "$v_memory_path")" \
      "$(json_escape "$v_project_path")" \
      "$(json_escape "$v_project_root")"
  fi
fi
