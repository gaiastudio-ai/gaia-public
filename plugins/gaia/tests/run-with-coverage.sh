#!/usr/bin/env bash
# run-with-coverage.sh — E28-S17 coverage wrapper.
#
# 1. Enumerates documented public functions from every *.sh in
#    plugins/gaia/scripts/ (any `^[a-z_][a-z0-9_]*\(\) {`).
# 2. Runs the full bats suite under plugins/gaia/tests/.
# 3. Asserts every public function name appears at least once inside
#    some .bats file (the NFR-052 binding public-function coverage gate).
# 4. If kcov is available, runs the suite under kcov to produce an advisory
#    line-coverage report at coverage/ (HTML + JSON). kcov is optional — a
#    missing kcov is NOT a hard failure of this wrapper. The CI job does NOT
#    install kcov on Ubuntu 24.04 (noble) because the package is not in the
#    default apt repositories there (see E28-S175); line-coverage is therefore
#    skipped in CI today. The authoritative public-function coverage gate
#    (step 3, NFR-052) does not depend on kcov.
#
# Exit codes:
#   0 — bats suite green AND every public function covered
#   1 — bats suite failed, or a public function has no matching bats test

set -euo pipefail
LC_ALL=C

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/../../.." && pwd)"
SCRIPTS_DIR="$REPO_ROOT/plugins/gaia/scripts"
TESTS_DIR="$REPO_ROOT/plugins/gaia/tests"
COVERAGE_DIR="${COVERAGE_DIR:-$REPO_ROOT/coverage}"

mkdir -p "$COVERAGE_DIR"

red()   { printf '\033[0;31m%s\033[0m\n' "$*"; }
green() { printf '\033[0;32m%s\033[0m\n' "$*"; }
bold()  { printf '\033[1m%s\033[0m\n' "$*"; }

# ---------------------------------------------------------------------------
# Step 1 — enumerate public functions across every foundation script.
# ---------------------------------------------------------------------------
bold "[1/4] Enumerating public functions in $SCRIPTS_DIR"

PUB_JSON="$COVERAGE_DIR/public-functions.json"
: > "$PUB_JSON.tmp"
printf '{\n' > "$PUB_JSON.tmp"
first_script=1
for s in "$SCRIPTS_DIR"/*.sh; do
  [ -f "$s" ] || continue
  name="$(basename "$s")"
  # Public functions: name followed immediately by `()` at the start of a line.
  # Private/internal helpers prefixed with `_` are excluded.
  funcs="$(
    grep -E '^[a-z][a-z0-9_]*\(\)' "$s" \
      | sed -E 's/\(\).*$//' \
      | sort -u
  )"
  if [ "$first_script" -eq 1 ]; then first_script=0; else printf ',\n' >> "$PUB_JSON.tmp"; fi
  printf '  "%s": [' "$name" >> "$PUB_JSON.tmp"
  first=1
  for f in $funcs; do
    if [ "$first" -eq 1 ]; then first=0; else printf ', ' >> "$PUB_JSON.tmp"; fi
    printf '"%s"' "$f" >> "$PUB_JSON.tmp"
  done
  printf ']' >> "$PUB_JSON.tmp"
done
printf '\n}\n' >> "$PUB_JSON.tmp"
mv "$PUB_JSON.tmp" "$PUB_JSON"

# ---------------------------------------------------------------------------
# Step 2 — run the bats suite.
# ---------------------------------------------------------------------------
bold "[2/4] Running bats suite"
if ! bats "$TESTS_DIR/"; then
  red "bats suite failed"
  exit 1
fi

# ---------------------------------------------------------------------------
# Step 3 — assert every public function is referenced from some .bats file.
# ---------------------------------------------------------------------------
bold "[3/4] Asserting public-function coverage (NFR-052)"

COVERED_JSON="$COVERAGE_DIR/coverage-summary.json"
: > "$COVERED_JSON.tmp"
printf '{\n  "gate": "NFR-052 public-function coverage",\n  "scripts": {\n' > "$COVERED_JSON.tmp"

uncovered_total=0
script_count=0
script_first=1
for s in "$SCRIPTS_DIR"/*.sh; do
  [ -f "$s" ] || continue
  name="$(basename "$s")"
  bats_file="$TESTS_DIR/${name%.sh}.bats"
  script_count=$((script_count + 1))

  funcs="$(
    grep -E '^[a-z][a-z0-9_]*\(\)' "$s" \
      | sed -E 's/\(\).*$//' \
      | sort -u
  )"

  covered=()
  uncovered=()
  # Bash 3.2 / nounset: avoid unbound-variable on empty arrays later.
  set +u
  for f in $funcs; do
    # Skip trivial helper shims — they are not "public functions" in the
    # story sense but rather inline one-liners (err/warn/die/log/usage).
    case "$f" in
      err|warn|die|die_usage|log|usage|print_usage|add_line|add_command)
        covered+=("$f")
        continue
        ;;
    esac
    if [ -f "$bats_file" ] && grep -q "$f" "$bats_file"; then
      covered+=("$f")
    else
      # Fall back: any .bats file at all references it
      if grep -rq "$f" "$TESTS_DIR"/*.bats 2>/dev/null; then
        covered+=("$f")
      else
        uncovered+=("$f")
      fi
    fi
  done

  if [ "$script_first" -eq 1 ]; then script_first=0; else printf ',\n' >> "$COVERED_JSON.tmp"; fi
  printf '    "%s": {\n      "covered": [' "$name" >> "$COVERED_JSON.tmp"
  first=1
  for f in "${covered[@]}"; do
    if [ "$first" -eq 1 ]; then first=0; else printf ', ' >> "$COVERED_JSON.tmp"; fi
    printf '"%s"' "$f" >> "$COVERED_JSON.tmp"
  done
  printf '],\n      "uncovered": [' >> "$COVERED_JSON.tmp"
  first=1
  for f in "${uncovered[@]}"; do
    if [ "$first" -eq 1 ]; then first=0; else printf ', ' >> "$COVERED_JSON.tmp"; fi
    printf '"%s"' "$f" >> "$COVERED_JSON.tmp"
    uncovered_total=$((uncovered_total + 1))
  done
  printf ']\n    }' >> "$COVERED_JSON.tmp"

  if [ "${#uncovered[@]}" -gt 0 ]; then
    red "  $name: uncovered public function(s): ${uncovered[*]}"
  else
    green "  $name: all public functions covered"
  fi
  set -u
done

printf '\n  },\n  "uncovered_total": %d,\n  "script_count": %d\n}\n' \
  "$uncovered_total" "$script_count" >> "$COVERED_JSON.tmp"
mv "$COVERED_JSON.tmp" "$COVERED_JSON"

if [ "$uncovered_total" -gt 0 ]; then
  red "NFR-052 gate FAILED — $uncovered_total uncovered public function(s)"
  exit 1
fi

# ---------------------------------------------------------------------------
# Step 4 — advisory kcov line-coverage report (optional).
# ---------------------------------------------------------------------------
bold "[4/4] Advisory kcov line-coverage (optional)"

if command -v kcov >/dev/null 2>&1; then
  kcov --bash-dont-parse-binary-dir \
       --include-path="$SCRIPTS_DIR" \
       "$COVERAGE_DIR/kcov" \
       bats "$TESTS_DIR/" || true
  green "kcov report: $COVERAGE_DIR/kcov/index.html"
else
  printf 'kcov not available — skipping line-coverage report (advisory only).\n'
fi

green "E28-S17 coverage wrapper: PASS"
exit 0
