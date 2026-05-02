#!/usr/bin/env bash
# yolo-mode.sh — YOLO mode detection helper for V2 GAIA skills.
#
# Story: E41-S1 (YOLO Mode Contract + Helper)
# ADR: ADR-057 (YOLO Mode Contract for V2 Phase 4 Commands)
# Architecture: docs/planning-artifacts/architecture/architecture.md §10.30.4
#
# Purpose
# -------
# The retired V1 engine expressed YOLO declaratively via per-step branches
# in its workflow definitions; V2 native skills lost that declarative
# contract. This script centralizes YOLO detection so each skill consults
# a single helper instead of re-implementing env parsing. See ADR-057 and
# architecture.md §10.30 for the full contract.
#
# Activation signals (architecture §10.30.1):
#   --yolo flag at the command boundary  -> caller exports GAIA_YOLO_FLAG=1
#   GAIA_YOLO_MODE=1 inherited from a YOLO-mode parent process
#
# Precedence order (top wins, architecture §10.30.4):
#   1. GAIA_CONTEXT=memory-save  -> exit 1   (E9-S8 invariant; FR-YOLO-2(f))
#   2. GAIA_YOLO_OVERRIDE=no     -> exit 1   (explicit opt-out, e.g. --no-yolo)
#   3. GAIA_YOLO_FLAG=1          -> exit 0   (direct invocation)
#   4. GAIA_YOLO_MODE=1          -> exit 0   (inheritance)
#   5. default                   -> exit 1   (interactive)
#
# Both GAIA_YOLO_FLAG and GAIA_YOLO_MODE accept ONLY the exact string "1".
# Values "0", "false", "no", and the empty string fall through to the
# default exit-1 branch (ECI-500 regression guard).
#
# Usage
# -----
#   # As a sourced library:
#   source plugins/gaia/scripts/yolo-mode.sh
#   if is_yolo; then echo "auto-proceed"; else echo "interactive"; fi
#
#   # As a direct invocation (subcommand form):
#   plugins/gaia/scripts/yolo-mode.sh is_yolo
#   echo "exit: $?"
#
# Shellcheck: clean (no unsupported constructs).

# is_yolo
# -------
# Returns 0 (YOLO active) or 1 (interactive) based on the precedence table
# above. Pure function — reads env, writes nothing, has no side effects.
is_yolo() {
    # Rule 1 — Memory-save context exempt per FR-YOLO-2(f). The E9-S8
    # memory-save prompt MUST remain interactive even when YOLO is active
    # at the session level.
    if [ "${GAIA_CONTEXT:-}" = "memory-save" ]; then
        return 1
    fi

    # Rule 2 — Explicit opt-out wins over both activation signals.
    # Used by --no-yolo flag handlers and by skills that need to break
    # YOLO inheritance for a specific subagent invocation.
    if [ "${GAIA_YOLO_OVERRIDE:-}" = "no" ]; then
        return 1
    fi

    # Rule 3 — Invocation flag (--yolo). Only the exact string "1" activates;
    # any other value (including "0", "true", "false", "") falls through.
    if [ "${GAIA_YOLO_FLAG:-}" = "1" ]; then
        return 0
    fi

    # Rule 4 — Inheritance env. Same exact-"1" semantics as Rule 3.
    if [ "${GAIA_YOLO_MODE:-}" = "1" ]; then
        return 0
    fi

    # Rule 5 — Default: interactive.
    return 1
}

# Direct-invocation entry point — only runs when the script is executed
# directly (not sourced). Allows callers to do `yolo-mode.sh is_yolo` and
# read $? without sourcing.
#
# BASH_SOURCE[0] equals $0 only on direct invocation. When sourced, $0 is
# the parent shell's name and BASH_SOURCE[0] is the path to this file.
if [ "${BASH_SOURCE[0]:-$0}" = "$0" ]; then
    case "${1:-is_yolo}" in
        is_yolo)
            is_yolo
            exit $?
            ;;
        --help|-h)
            cat <<'EOF'
yolo-mode.sh — YOLO mode detection helper (ADR-057, architecture §10.30.4)

Usage:
  source yolo-mode.sh && is_yolo                 # library form
  yolo-mode.sh is_yolo                           # subcommand form
  yolo-mode.sh --help                            # this message

Environment variables (precedence top-down):
  GAIA_CONTEXT=memory-save     forces exit 1 (E9-S8 invariant)
  GAIA_YOLO_OVERRIDE=no        explicit opt-out -> exit 1
  GAIA_YOLO_FLAG=1             --yolo flag      -> exit 0
  GAIA_YOLO_MODE=1             inherited YOLO   -> exit 0
  (none)                       default          -> exit 1
EOF
            exit 0
            ;;
        *)
            echo "yolo-mode.sh: unknown subcommand '$1'. Try '--help'." >&2
            exit 2
            ;;
    esac
fi
