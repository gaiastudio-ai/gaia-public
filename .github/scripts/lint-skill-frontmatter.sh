#!/usr/bin/env bash
# lint-skill-frontmatter.sh
# Lints YAML frontmatter of every plugins/gaia/skills/**/SKILL.md file.
# Required fields: name, description (per E28-S7 AC2).
# Empty tree is a valid, passing state.
#
# Pure bash — no yq/jq dependency. Extracts frontmatter between the leading
# `---` delimiters using awk, then greps for each required field.

set -euo pipefail

REQUIRED_FIELDS=("name" "description")

count=0
errors=0

while IFS= read -r -d '' file; do
  count=$((count + 1))

  # Extract frontmatter: everything between the first two `---` lines.
  frontmatter=$(awk '
    BEGIN { in_fm = 0; seen = 0 }
    /^---[[:space:]]*$/ {
      if (seen == 0) { in_fm = 1; seen = 1; next }
      else if (in_fm == 1) { in_fm = 0; exit }
    }
    in_fm == 1 { print }
  ' "$file")

  if [ -z "$frontmatter" ]; then
    echo "ERROR: $file missing required field: name"
    echo "ERROR: $file missing required field: description"
    errors=$((errors + 2))
    continue
  fi

  for field in "${REQUIRED_FIELDS[@]}"; do
    # Match `field:` at line start, with a non-empty value after the colon.
    if ! awk -v f="$field" '
      $0 ~ "^"f"[[:space:]]*:" {
        # Strip "field:" prefix
        sub("^"f"[[:space:]]*:[[:space:]]*", "", $0)
        # Strip surrounding quotes
        gsub(/^["'\'']|["'\'']$/, "", $0)
        if (length($0) > 0) { found = 1 }
      }
      END { exit (found ? 0 : 1) }
    ' <<< "$frontmatter"; then
      echo "ERROR: $file missing required field: $field"
      errors=$((errors + 1))
    fi
  done
done < <(find plugins/gaia/skills -type f -name 'SKILL.md' -print0 2>/dev/null)

if [ "$count" -eq 0 ]; then
  echo "0 SKILL.md files scanned — OK (empty tree)"
  exit 0
fi

if [ "$errors" -gt 0 ]; then
  exit 1
fi

echo "$count SKILL.md files scanned — OK"
