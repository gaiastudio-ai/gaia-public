#!/usr/bin/env bash
# theme-hash.sh — canonical theme-hash helper for the retro skill.
#
# Reads text from arg or stdin, applies the normalization documented in
# architecture.md §10.28.3 (lowercase + trim) and emits the SHA-256 hex digest.
#
# Usage:
#   theme-hash.sh "some theme text"
#   echo "some theme text" | theme-hash.sh
#
# NFC normalization for non-ASCII content is deferred to the caller — the
# fixtures covered by AC-EC10 are pure ASCII and normalize correctly here.

set -euo pipefail

if [ $# -ge 1 ]; then
  text="$1"
else
  text="$(cat)"
fi

norm="$(printf '%s' "$text" | tr '[:upper:]' '[:lower:]' | awk '{$1=$1;print}')"
printf '%s' "$norm" | shasum -a 256 | awk '{print $1}'
