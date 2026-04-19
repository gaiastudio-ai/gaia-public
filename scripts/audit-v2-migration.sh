#!/usr/bin/env bash
# audit-v2-migration.sh — E28-S190 audit harness
#
# Purpose: Exercise every installed plugin skill's setup.sh + finalize.sh after
# a v1→v2 /gaia-migrate apply and capture exit code + stderr per skill. The
# output is a machine-readable CSV the audit writeup consumes.
#
# Scope: READ-ONLY against the reporter's workspace. This script operates on a
# /tmp/ copy. It does NOT run /gaia-migrate apply against the caller's
# workspace — the caller provides a pre-migrated fixture directory.
#
# Usage:
#   audit-v2-migration.sh \
#     --plugin-cache <path-to-cache/gaia/VERSION/skills> \
#     --project-root <path-to-pre-migrated-project> \
#     [--out <output-csv-path>]
#
# Exit codes:
#   0 — audit completed (individual skill failures are reported in the CSV,
#       not as process exit codes)
#   2 — harness misconfiguration (missing flags, unreadable plugin cache)
#
# Output schema (CSV header):
#   skill_name,has_setup,setup_exit,setup_stderr_head,has_finalize,
#     finalize_exit,finalize_stderr_head,bucket
#
# Bucket classification (see E28-S190 story):
#   B1 — CLAUDE_SKILL_DIR path contract mismatch
#   B2 — Checkpoint write target deleted by migration
#   B3 — SKILL.md body references _gaia/_config/ literal paths
#   B4 — Missing global.yaml overlay fallback
#   B5 — Other
#   OK — setup & finalize both exited 0

set -uo pipefail
LC_ALL=C
export LC_ALL

die() { printf 'audit-v2-migration: %s\n' "$1" >&2; exit 2; }

PLUGIN_CACHE=""
PROJECT_ROOT=""
OUT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --plugin-cache) PLUGIN_CACHE="$2"; shift 2 ;;
    --project-root) PROJECT_ROOT="$2"; shift 2 ;;
    --out)          OUT="$2"; shift 2 ;;
    -h|--help)
      sed -n '1,36p' "$0" >&2; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[ -n "$PLUGIN_CACHE" ] || die "--plugin-cache <path> is required"
[ -n "$PROJECT_ROOT" ] || die "--project-root <path> is required"
[ -d "$PLUGIN_CACHE" ] || die "plugin-cache dir not found: $PLUGIN_CACHE"
[ -d "$PROJECT_ROOT" ] || die "project-root dir not found: $PROJECT_ROOT"

if [ -z "$OUT" ]; then
  OUT="$(mktemp -t gaia-audit-v2.XXXXXX.csv)"
fi

# ---------- Helpers ----------

stderr_head() {
  # Collapse newlines and keep first 5 lines, quote CSV-safely.
  local text="$1"
  printf '%s' "$text" \
    | head -n 5 \
    | tr '\n' ' ' \
    | sed 's/"/""/g'
}

classify() {
  # Echo bucket based on setup/finalize stderr text.
  local combined="$1"
  if printf '%s' "$combined" | grep -qE 'resolve-config: (no config path|config file not found)'; then
    printf '%s' 'B1'
    return
  fi
  if printf '%s' "$combined" | grep -qE 'checkpoint\.sh: .*write failed|_memory/checkpoints.*(not found|No such file)'; then
    printf '%s' 'B2'
    return
  fi
  if printf '%s' "$combined" | grep -qE '_gaia/_config/.*\.(csv|yaml)|_gaia/_config/.*No such file'; then
    printf '%s' 'B3'
    return
  fi
  if printf '%s' "$combined" | grep -qE 'global\.yaml.*(not found|No such file)'; then
    printf '%s' 'B4'
    return
  fi
  printf '%s' 'B5'
}

run_script() {
  # run_script <absolute-script-path> <skill-dir>
  # Echoes "<exit_code>\t<stderr text>" (tab-separated).
  local script="$1" skill_dir="$2"
  local stderr_txt exit_code
  # CLAUDE_SKILL_DIR emulates Claude Code's plugin harness convention:
  # it points at the skill directory, NOT the project root.
  stderr_txt=$(
    CLAUDE_SKILL_DIR="$skill_dir" \
    CLAUDE_PROJECT_ROOT="$PROJECT_ROOT" \
      bash "$script" 2>&1 1>/dev/null
  )
  exit_code=$?
  printf '%s\t%s' "$exit_code" "$stderr_txt"
}

# ---------- Main loop ----------

printf 'skill_name,has_setup,setup_exit,setup_stderr_head,has_finalize,finalize_exit,finalize_stderr_head,bucket\n' > "$OUT"

total=0
failed=0
b1=0; b2=0; b3=0; b4=0; b5=0

for skill_dir in "$PLUGIN_CACHE"/*/; do
  [ -d "$skill_dir" ] || continue
  skill_name=$(basename "$skill_dir")
  total=$((total + 1))

  setup_sh="$skill_dir/scripts/setup.sh"
  finalize_sh="$skill_dir/scripts/finalize.sh"

  has_setup=0
  setup_exit=""
  setup_err=""
  if [ -f "$setup_sh" ]; then
    has_setup=1
    result=$(run_script "$setup_sh" "$skill_dir")
    setup_exit="${result%%	*}"
    setup_err="${result#*	}"
  fi

  has_finalize=0
  finalize_exit=""
  finalize_err=""
  if [ -f "$finalize_sh" ]; then
    has_finalize=1
    result=$(run_script "$finalize_sh" "$skill_dir")
    finalize_exit="${result%%	*}"
    finalize_err="${result#*	}"
  fi

  combined="${setup_err}"$'\n'"${finalize_err}"
  if [ "$has_setup" -eq 0 ] && [ "$has_finalize" -eq 0 ]; then
    bucket="NO-SCRIPTS"
  elif [ "${setup_exit:-0}" = "0" ] && [ "${finalize_exit:-0}" = "0" ]; then
    bucket="OK"
  else
    bucket=$(classify "$combined")
    failed=$((failed + 1))
    case "$bucket" in
      B1) b1=$((b1 + 1)) ;;
      B2) b2=$((b2 + 1)) ;;
      B3) b3=$((b3 + 1)) ;;
      B4) b4=$((b4 + 1)) ;;
      *)  b5=$((b5 + 1)) ;;
    esac
  fi

  printf '%s,%d,%s,"%s",%d,%s,"%s",%s\n' \
    "$skill_name" \
    "$has_setup" "${setup_exit:-}" "$(stderr_head "$setup_err")" \
    "$has_finalize" "${finalize_exit:-}" "$(stderr_head "$finalize_err")" \
    "$bucket" >> "$OUT"
done

# ---------- Summary ----------
printf '\n=== audit-v2-migration summary ===\n' >&2
printf 'total_skills: %d\n' "$total" >&2
printf 'failed_skills: %d\n' "$failed" >&2
printf 'bucket_B1_path_contract: %d\n' "$b1" >&2
printf 'bucket_B2_checkpoint_deleted: %d\n' "$b2" >&2
printf 'bucket_B3_skill_md_literal_paths: %d\n' "$b3" >&2
printf 'bucket_B4_global_yaml_overlay: %d\n' "$b4" >&2
printf 'bucket_B5_other: %d\n' "$b5" >&2
printf 'output_csv: %s\n' "$OUT" >&2
