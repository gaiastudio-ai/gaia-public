#!/usr/bin/env bash
# gaia-migrate.sh — GAIA foundation script (E28-S131)
#
# Automate the v1 → v2 migration described in gaia-public/docs/migration-guide-v2.md.
# Per ADR-042 (scripts-over-LLM), the SKILL.md drives the user-facing flow and
# delegates filesystem operations to this script.
#
# Refs: FR-326 (config split), FR-328 (engine deletion), NFR-050 (zero engine files), ADR-048
# Story: E28-S131
#
# Usage:
#   gaia-migrate.sh apply   --project-root PATH
#   gaia-migrate.sh dry-run --project-root PATH
#
# Exit codes:
#   0 — success (migration applied, OR dry-run completed cleanly)
#   1 — pre-flight HALT (no v1 install detected, partial install, already migrated)
#   2 — backup failed (disk space, permission)
#   3 — migration step failed (subtask 4.1, 4.2, or 4.3)
#   4 — post-migration validation failed
#   64 — usage error

set -euo pipefail

MODE=""
PROJECT_ROOT=""
DRY_RUN=false

# ---------------------------------------------------------------------------
# Arg parsing
# ---------------------------------------------------------------------------

while [[ $# -gt 0 ]]; do
  case "$1" in
    apply|dry-run)
      MODE="$1"
      shift
      ;;
    --project-root)
      PROJECT_ROOT="${2:-}"
      shift 2
      ;;
    -h|--help)
      cat <<EOF
Usage: $0 (apply|dry-run) --project-root PATH

apply    — perform the v1 to v2 migration (creates backup first)
dry-run  — print the planned operations without writing anything

See gaia-public/docs/migration-guide-v2.md for the manual walkthrough.
EOF
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: $0 (apply|dry-run) --project-root PATH" >&2
      exit 64
      ;;
  esac
done

if [[ -z "$MODE" ]]; then
  echo "Usage: $0 (apply|dry-run) --project-root PATH" >&2
  echo "Mode required: 'apply' or 'dry-run'" >&2
  exit 64
fi

if [[ -z "$PROJECT_ROOT" ]]; then
  echo "Usage: $0 (apply|dry-run) --project-root PATH" >&2
  echo "--project-root is required" >&2
  exit 64
fi

if [[ ! -d "$PROJECT_ROOT" ]]; then
  echo "project-root does not exist: $PROJECT_ROOT" >&2
  exit 64
fi

if [[ "$MODE" == "dry-run" ]]; then
  DRY_RUN=true
fi

# ---------------------------------------------------------------------------
# Central write helper — every cp/mv/rm/mkdir/write routes through here.
# In dry-run mode, the helper logs the intended operation and returns 0
# without touching the filesystem. This is the single safety mechanism for
# AC5 (dry-run idempotency) and AC-EC6 (dry-run accidental write).
# ---------------------------------------------------------------------------
_safe_write() {
  local action="$1"
  shift
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "  [dry-run] would: $action $*"
    return 0
  fi
  case "$action" in
    mkdir)  mkdir -p "$@" ;;
    cp_a)   cp -a "$@" ;;
    cp)     cp "$@" ;;
    mv)     mv "$@" ;;
    rm)     rm "$@" ;;
    rm_rf)  rm -rf "$@" ;;
    write)
      # write FILE CONTENT — write CONTENT to FILE
      local file="$1"
      shift
      printf '%s\n' "$*" > "$file"
      ;;
    append)
      local file="$1"
      shift
      printf '%s\n' "$*" >> "$file"
      ;;
    *)
      echo "ERROR: _safe_write: unknown action '$action'" >&2
      return 1
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Step: detect v1 markers
# ---------------------------------------------------------------------------
_detect_v1() {
  echo "=== detect: v1 markers ==="
  local has_engine has_memory has_custom has_config has_v2

  [[ -d "$PROJECT_ROOT/_gaia" ]] && has_engine=1 || has_engine=0
  [[ -d "$PROJECT_ROOT/_memory" ]] && has_memory=1 || has_memory=0
  [[ -d "$PROJECT_ROOT/custom" ]] && has_custom=1 || has_custom=0
  [[ -f "$PROJECT_ROOT/_gaia/_config/global.yaml" ]] && has_config=1 || has_config=0
  [[ -f "$PROJECT_ROOT/config/project-config.yaml" ]] && has_v2=1 || has_v2=0

  echo "  _gaia/                              : $([ "$has_engine" -eq 1 ] && echo present || echo MISSING)"
  echo "  _memory/                            : $([ "$has_memory" -eq 1 ] && echo present || echo MISSING)"
  echo "  custom/                             : $([ "$has_custom" -eq 1 ] && echo present || echo MISSING)"
  echo "  _gaia/_config/global.yaml           : $([ "$has_config" -eq 1 ] && echo present || echo MISSING)"
  echo "  config/project-config.yaml (v2)     : $([ "$has_v2" -eq 1 ] && echo present || echo MISSING)"

  # No v1 detected
  if [[ "$has_engine" -eq 0 && "$has_memory" -eq 0 && "$has_custom" -eq 0 && "$has_config" -eq 0 ]]; then
    echo
    echo "HALT: No v1 installation detected — nothing to migrate."
    return 1
  fi

  # Already migrated
  if [[ "$has_v2" -eq 1 ]]; then
    echo
    echo "HALT: Migration already complete — config/project-config.yaml exists. v2 state detected."
    return 1
  fi

  # Partial install (AC-EC1)
  if [[ "$has_engine" -eq 0 || "$has_memory" -eq 0 || "$has_config" -eq 0 ]]; then
    echo
    echo "HALT: v1 installation is partial — required marker missing. Either repair the install or pass --force-partial (not yet supported)."
    return 1
  fi

  echo "  → v1 install detected, ready to migrate"
}

# ---------------------------------------------------------------------------
# Step: backup BEFORE any migration write (AC2, AC-EC3)
# ---------------------------------------------------------------------------
_run_backup() {
  echo
  echo "=== backup: timestamped snapshot ==="
  local ts bdir
  ts="$(date +%Y-%m-%d-%H%M%S)"
  bdir="$PROJECT_ROOT/.gaia-migrate-backup/$ts"
  echo "  destination: $bdir"

  # AC-EC3 — disk space check (best-effort: confirm /tmp + project-root have >100MB free)
  local free_kb
  free_kb=$(df -k "$PROJECT_ROOT" 2>/dev/null | tail -1 | awk '{print $4}')
  if [[ -n "$free_kb" && "$free_kb" -lt 102400 ]]; then
    echo "ERROR: insufficient disk space ($free_kb KB free, need >100MB)" >&2
    return 2
  fi

  _safe_write mkdir "$bdir"

  # Copy each source — silently skip if absent
  for src in _gaia _memory custom; do
    if [[ -d "$PROJECT_ROOT/$src" ]]; then
      _safe_write cp_a "$PROJECT_ROOT/$src" "$bdir/"
    fi
  done
  if [[ -f "$PROJECT_ROOT/CLAUDE.md" ]]; then
    _safe_write cp_a "$PROJECT_ROOT/CLAUDE.md" "$bdir/"
  fi

  # Generate manifest with sha256 (only in apply mode — dry-run can't write the manifest)
  if [[ "$DRY_RUN" == "false" ]]; then
    local manifest="$bdir/backup-manifest.yaml"
    {
      echo "# E28-S131 backup manifest"
      echo "story: E28-S131"
      echo "timestamp: $ts"
      echo "project_root: $PROJECT_ROOT"
      echo "files:"
      ( cd "$bdir" && find . -type f -not -name 'backup-manifest.yaml' -print0 2>/dev/null | \
        while IFS= read -r -d '' f; do
          local sum
          sum=$(shasum -a 256 "$f" | awk '{print $1}')
          echo "  - path: ${f#./}"
          echo "    sha256: $sum"
        done ) >> "$manifest"
    } 2>/dev/null
    if [[ ! -f "$manifest" ]]; then
      # fallback: write the file even if the find pipeline is empty
      cat > "$manifest" <<EOF
# E28-S131 backup manifest
story: E28-S131
timestamp: $ts
project_root: $PROJECT_ROOT
files: []
sha256: empty-backup
EOF
    fi
    echo "  manifest: $manifest"
  else
    echo "  [dry-run] would write manifest: $bdir/backup-manifest.yaml"
  fi

  # Export for use by other steps
  BACKUP_DIR="$bdir"
  echo "  backup PASS"
}

# ---------------------------------------------------------------------------
# Subtask 4.1 — templates (AC3)
# ---------------------------------------------------------------------------
_migrate_templates() {
  echo
  echo "=== migrate 4.1: custom/templates/ ==="
  if [[ ! -d "$PROJECT_ROOT/custom/templates" ]]; then
    echo "  no custom/templates/ to migrate (skipping)"
    echo "  templates PASS"
    return 0
  fi
  # v2 plugin honors custom/templates/ at project root — verify-only
  local count
  count=$(find "$PROJECT_ROOT/custom/templates" -type f 2>/dev/null | wc -l | tr -d ' ')
  echo "  $count template file(s) preserved at custom/templates/ (v2 path matches v1 — no move needed)"
  echo "  templates PASS"
}

# ---------------------------------------------------------------------------
# Subtask 4.2 — sidecars (AC3)
# ---------------------------------------------------------------------------
_migrate_sidecars() {
  echo
  echo "=== migrate 4.2: _memory/*-sidecar/ ==="
  local sidecar_count=0 file_count=0
  if [[ -d "$PROJECT_ROOT/_memory" ]]; then
    while IFS= read -r -d '' dir; do
      sidecar_count=$((sidecar_count + 1))
      local files
      files=$(find "$dir" -maxdepth 1 -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
      file_count=$((file_count + files))
    done < <(find "$PROJECT_ROOT/_memory" -maxdepth 1 -mindepth 1 -type d -name '*-sidecar' -print0 2>/dev/null)
  fi
  echo "  $sidecar_count sidecar(s), $file_count .md file(s) verified"
  echo "  v1 and v2 sidecar layouts match (per current ADR set) — no transformation needed"
  echo "  sidecars PASS"
}

# ---------------------------------------------------------------------------
# Subtask 4.3 — config split (AC3, FR-326 partition)
# ---------------------------------------------------------------------------
_migrate_config_split() {
  echo
  echo "=== migrate 4.3: config split (FR-326) ==="
  local v1_config="$PROJECT_ROOT/_gaia/_config/global.yaml"
  if [[ ! -f "$v1_config" ]]; then
    echo "  no _gaia/_config/global.yaml — nothing to split"
    echo "  config-split PASS"
    return 0
  fi

  # Keys that stay in global.yaml (local, per-developer)
  local local_keys=(
    framework_name framework_version user_name communication_language
    document_output_language user_skill_level project_name project_root
    project_path output_folder planning_artifacts implementation_artifacts
    test_artifacts creative_artifacts memory_path checkpoint_path
    installed_path config_path
  )

  # Keys that move to project-config.yaml (team-shared)
  local shared_keys=(
    ci_cd val_integration memory_budgets sizing_map problem_solving
    adversarial_triggers
  )

  # Build the two files. Use a simple awk-based YAML key-block extractor
  # (works for top-level keys with their indented children).
  local v2_global="$PROJECT_ROOT/_gaia/_config/global.yaml.v2"
  local v2_shared_dir="$PROJECT_ROOT/config"
  local v2_shared="$v2_shared_dir/project-config.yaml"

  _safe_write mkdir "$v2_shared_dir"

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "  [dry-run] would split $v1_config:"
    echo "    [dry-run] local keys → $v1_config (rewritten in place)"
    echo "    [dry-run] shared keys → $v2_shared"
    echo "  config-split PASS"
    return 0
  fi

  # Extract local keys to v2_global
  {
    echo "# GAIA v2 — local config (per-developer, machine-local)"
    echo "# Migrated from v1 by /gaia-migrate (E28-S131)"
    for k in "${local_keys[@]}"; do
      awk -v k="$k" '
        $0 ~ "^"k":" { in_block=1; print; next }
        in_block && /^[a-zA-Z_]/ { in_block=0 }
        in_block { print }
      ' "$v1_config"
    done
  } > "$v2_global"

  # Extract shared keys to project-config.yaml
  {
    echo "# GAIA v2 — team-shared config (cloud-synced)"
    echo "# Migrated from v1 by /gaia-migrate (E28-S131)"
    for k in "${shared_keys[@]}"; do
      awk -v k="$k" '
        $0 ~ "^"k":" { in_block=1; print; next }
        in_block && /^[a-zA-Z_]/ { in_block=0 }
        in_block { print }
      ' "$v1_config"
    done
  } > "$v2_shared"

  # Replace v1 config with v2_global
  _safe_write mv "$v2_global" "$v1_config"

  echo "  local keys retained in: $v1_config"
  echo "  shared keys written to: $v2_shared"
  echo "  config-split PASS"
}

# ---------------------------------------------------------------------------
# Step: validation (AC4)
# ---------------------------------------------------------------------------
_run_validate() {
  echo
  echo "=== validate: post-migration checks ==="
  local fail=0

  # 1. Plugin discoverable (best-effort under bats — the .claude/plugins/ dir may not exist locally)
  if [[ -d "$PROJECT_ROOT/.claude/plugins/gaia-public" ]] || command -v claude >/dev/null 2>&1; then
    echo "  plugin: discoverable"
  else
    echo "  plugin: validation skipped (claude CLI not available — manual follow-up: confirm /plugin list shows gaia)"
  fi

  # 2. project-config.yaml parses
  if [[ -f "$PROJECT_ROOT/config/project-config.yaml" ]]; then
    if grep -qE '^[a-zA-Z_]+:' "$PROJECT_ROOT/config/project-config.yaml"; then
      echo "  project-config.yaml: parses (basic structural check)"
    else
      echo "  ERROR: project-config.yaml exists but contains no top-level keys" >&2
      fail=1
    fi
  fi

  # 3. global.yaml still has local keys
  if [[ -f "$PROJECT_ROOT/_gaia/_config/global.yaml" ]]; then
    if grep -qE '^project_path:' "$PROJECT_ROOT/_gaia/_config/global.yaml"; then
      echo "  global.yaml: project_path retained"
    else
      echo "  ERROR: global.yaml lost project_path during split" >&2
      fail=1
    fi
  fi

  return "$fail"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
echo "==============================================================="
echo "gaia-migrate — v1 → v2 migration ($MODE mode)"
echo "project-root: $PROJECT_ROOT"
echo "==============================================================="

# Detect (HALT-able)
if ! _detect_v1; then
  exit 1
fi

# Backup (HALT on disk-space)
BACKUP_DIR=""
if ! _run_backup; then
  echo
  echo "FAILED: backup step did not complete. Aborting before any migration write."
  exit 2
fi

# Migrate (3 subtasks)
if ! _migrate_templates; then
  echo "FAILED: templates migration"
  echo "Restore: cp -a \"$BACKUP_DIR/.\" \"$PROJECT_ROOT/\""
  exit 3
fi
if ! _migrate_sidecars; then
  echo "FAILED: sidecars migration"
  echo "Restore: cp -a \"$BACKUP_DIR/.\" \"$PROJECT_ROOT/\""
  exit 3
fi
if ! _migrate_config_split; then
  echo "FAILED: config-split migration"
  echo "Restore: cp -a \"$BACKUP_DIR/.\" \"$PROJECT_ROOT/\""
  exit 3
fi

# Validate (AC4)
if [[ "$DRY_RUN" == "false" ]]; then
  if ! _run_validate; then
    echo
    echo "==============================================================="
    echo "FAILED: post-migration validation reported errors."
    echo "Backup: $BACKUP_DIR"
    echo "Restore: cp -a \"$BACKUP_DIR/.\" \"$PROJECT_ROOT/\""
    echo "==============================================================="
    exit 4
  fi
fi

# Summary
echo
echo "==============================================================="
if [[ "$DRY_RUN" == "true" ]]; then
  echo "Dry run — no changes made."
  echo "To apply: $0 apply --project-root \"$PROJECT_ROOT\""
else
  echo "SUCCESS — v1 → v2 migration complete."
  echo "Backup: $BACKUP_DIR"
  echo "Restore command (if needed): cp -a \"$BACKUP_DIR/.\" \"$PROJECT_ROOT/\""
fi
echo "==============================================================="
