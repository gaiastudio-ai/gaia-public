#!/usr/bin/env bash
# resolve-config.sh — GAIA foundation script (E28-S9)
set -euo pipefail
LC_ALL=C
export LC_ALL
#
# Reads ${CLAUDE_SKILL_DIR}/config/project-config.yaml (or --config <path>),
# merges GAIA_* environment overrides (env wins), validates required fields,
# and emits deterministic output on stdout:
#   - default:        KEY='VALUE' lines, single-quoted, alpha-sorted
#   - --format json:  a single JSON object with the same keys
#
# POSIX discipline: the only non-POSIX constructs tolerated in this file are
# [[ ... ]] tests and Bash indexed arrays; every other construct stays POSIX.
# The shebang is bash because this project standardizes on bash foundation
# scripts (ADR-048). LC_ALL=C pins sort order and locale for determinism.
# Intentionally avoids associative arrays so macOS /bin/bash 3.2 can run it.
#
# Required fields:
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

validate_yaml_basic() {
  local file="$1"
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

# ---------- Argument parsing ----------

CONFIG_PATH=""
FORMAT="shell"

while [ $# -gt 0 ]; do
  case "$1" in
    --config)
      [ $# -ge 2 ] || die "flag --config requires a path argument"
      CONFIG_PATH="$2"; shift 2 ;;
    --config=*)
      CONFIG_PATH="${1#--config=}"; shift ;;
    --format)
      [ $# -ge 2 ] || die "flag --format requires shell|json"
      FORMAT="$2"; shift 2 ;;
    --format=*)
      FORMAT="${1#--format=}"; shift ;;
    -h|--help)
      sed -n '1,40p' "$0" >&2; exit 0 ;;
    *)
      die "unknown argument: $1" ;;
  esac
done

case "$FORMAT" in
  shell|json) ;;
  *) die "unsupported --format '$FORMAT' (expected shell|json)" ;;
esac

# ---------- Config discovery ----------

if [ -z "$CONFIG_PATH" ]; then
  if [ -n "${CLAUDE_SKILL_DIR:-}" ]; then
    CONFIG_PATH="${CLAUDE_SKILL_DIR}/config/project-config.yaml"
  else
    die "no config path — set CLAUDE_SKILL_DIR or pass --config <path>"
  fi
fi

if [ ! -f "$CONFIG_PATH" ]; then
  die "config file not found: $CONFIG_PATH"
fi

if ! validate_yaml_basic "$CONFIG_PATH"; then
  die "malformed YAML in $CONFIG_PATH"
fi

# ---------- Extract required fields ----------
# Required keys, alphabetically sorted (determinism for emit order).
# Stored as plain variables (v_<key>) because bash 3.2 has no associative arrays.

v_checkpoint_path=$(parse_yaml_key "$CONFIG_PATH" checkpoint_path)
v_date=$(parse_yaml_key "$CONFIG_PATH" date)
v_framework_version=$(parse_yaml_key "$CONFIG_PATH" framework_version)
v_installed_path=$(parse_yaml_key "$CONFIG_PATH" installed_path)
v_memory_path=$(parse_yaml_key "$CONFIG_PATH" memory_path)
v_project_path=$(parse_yaml_key "$CONFIG_PATH" project_path)
v_project_root=$(parse_yaml_key "$CONFIG_PATH" project_root)

# ---------- Apply environment overrides (env wins) ----------

[ -n "${GAIA_PROJECT_ROOT:-}" ]    && v_project_root="$GAIA_PROJECT_ROOT"
[ -n "${GAIA_PROJECT_PATH:-}" ]    && v_project_path="$GAIA_PROJECT_PATH"
[ -n "${GAIA_MEMORY_PATH:-}" ]     && v_memory_path="$GAIA_MEMORY_PATH"
[ -n "${GAIA_CHECKPOINT_PATH:-}" ] && v_checkpoint_path="$GAIA_CHECKPOINT_PATH"

# ---------- Required-field check ----------

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
  # Alphabetical order, hard-coded to guarantee determinism.
  emit_pair_shell checkpoint_path   "$v_checkpoint_path"
  emit_pair_shell date              "$v_date"
  emit_pair_shell framework_version "$v_framework_version"
  emit_pair_shell installed_path    "$v_installed_path"
  emit_pair_shell memory_path       "$v_memory_path"
  emit_pair_shell project_path      "$v_project_path"
  emit_pair_shell project_root      "$v_project_root"
else
  if command -v jq >/dev/null 2>&1; then
    jq -n \
      --arg checkpoint_path   "$v_checkpoint_path" \
      --arg date              "$v_date" \
      --arg framework_version "$v_framework_version" \
      --arg installed_path    "$v_installed_path" \
      --arg memory_path       "$v_memory_path" \
      --arg project_path      "$v_project_path" \
      --arg project_root      "$v_project_root" \
      '{checkpoint_path: $checkpoint_path, date: $date, framework_version: $framework_version, installed_path: $installed_path, memory_path: $memory_path, project_path: $project_path, project_root: $project_root}'
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
