#!/usr/bin/env bats
# knowledge-paths-guard.bats — E28-S194 regression guard for plugin-shipped CSVs.
#
# Story: E28-S194 — Retire `_gaia/_config/*.csv` literal paths from 15 SKILL.md
# files and ship CSVs inside the plugin's knowledge/ tree.
#
# After E28-S190 audit bucket B3, the two CSVs (gaia-help.csv,
# workflow-manifest.csv) MUST live inside plugins/gaia/knowledge/ so the
# affected skills resolve them via ${CLAUDE_PLUGIN_ROOT}/knowledge/<csv>
# instead of the legacy v1 path _gaia/_config/<csv> — which disappears after
# /gaia-migrate apply deletes _gaia/.
#
# These tests fail RED until both CSVs are placed and all 15 SKILL.md files
# are rewritten to drop the legacy literal paths.

load test_helper

setup() {
  common_setup
  PLUGIN_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  KNOWLEDGE_DIR="$PLUGIN_ROOT/knowledge"
  SKILLS_DIR="$PLUGIN_ROOT/skills"
  export PLUGIN_ROOT KNOWLEDGE_DIR SKILLS_DIR
}

teardown() { common_teardown; }

# ---------- AC1, AC2: CSVs ship inside the plugin ----------

@test "AC1: plugins/gaia/knowledge/gaia-help.csv exists" {
  [ -f "$KNOWLEDGE_DIR/gaia-help.csv" ]
}

@test "AC2: plugins/gaia/knowledge/workflow-manifest.csv exists" {
  [ -f "$KNOWLEDGE_DIR/workflow-manifest.csv" ]
}

@test "AC9a: gaia-help.csv is non-empty" {
  [ -s "$KNOWLEDGE_DIR/gaia-help.csv" ]
}

@test "AC9b: workflow-manifest.csv is non-empty" {
  [ -s "$KNOWLEDGE_DIR/workflow-manifest.csv" ]
}

# ---------- AC6: SKILL.md prose drops legacy CSV literal paths ----------
#
# Scope note: the story (E28-S194) targets the two CSVs that bucket B3 of the
# E28-S190 audit flagged — gaia-help.csv and workflow-manifest.csv. AC6's
# "grep returns 0 matches" reads broadly, but its intent (per the story title
# "Retire _gaia/_config/*.csv literal paths") and the AC4/AC5 specificity
# constrain the scope to CSV references. Non-CSV references (global.yaml,
# manifest.yaml, adversarial-triggers.yaml, lifecycle-sequence.yaml,
# agent-manifest.csv) remain out of scope for this story and are flagged in
# Findings for a follow-up cleanup pass.

@test "AC6: no SKILL.md contains an unprefixed _gaia/_config/<csv> path for the two B3 CSVs" {
  # The two B3 CSVs MUST NOT appear under the legacy _gaia/_config/ path.
  # Any other _gaia/_config/* reference is deliberately out of scope here.
  local hits remaining
  hits="$(grep -rn -E '_gaia/_config/(gaia-help|workflow-manifest)\.csv' "$SKILLS_DIR"/*/SKILL.md 2>/dev/null || true)"
  if [ -z "$hits" ]; then
    return 0
  fi
  remaining="$(printf '%s\n' "$hits" | grep -viE 'legacy v1|no longer used|historical|legacy location|pre-migration' || true)"
  if [ -n "$remaining" ]; then
    echo "SKILL.md still references the legacy v1 path _gaia/_config/<csv> outside a 'legacy' qualifier:"
    printf '  %s\n' "$remaining"
    return 1
  fi
}

@test "AC4/AC5: every PATH reference to gaia-help.csv or workflow-manifest.csv inside SKILL.md uses the plugin knowledge path" {
  # Scope: only LITERAL PATH references — i.e., the CSV filename appears with
  # a directory prefix like `_gaia/_config/<csv>` or `${CLAUDE_PLUGIN_ROOT}/knowledge/<csv>`.
  # Bare filename mentions ("see workflow-manifest.csv", "the gaia-help.csv columns")
  # are conceptual references — the LLM does not Read them. They are NOT path
  # references and so are out of scope for AC4/AC5.
  #
  # A "path reference" is a match where the CSV filename is preceded by a `/`
  # in the same word (i.e., the filename has at least one path segment to its left).
  local bad
  bad="$(grep -rnE '[A-Za-z_/\$\{\}]+/(gaia-help|workflow-manifest)\.csv' "$SKILLS_DIR"/*/SKILL.md 2>/dev/null \
         | grep -v 'knowledge/' \
         | grep -viE 'legacy v1|no longer used|historical|legacy location|pre-migration' \
         || true)"
  if [ -n "$bad" ]; then
    echo "SKILL.md path reference to one of the two CSVs without the plugin knowledge/ path:"
    printf '  %s\n' "$bad"
    return 1
  fi
}
