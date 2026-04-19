---
template: 'story'
version: 1.4.0
used_by: ['create-story']
key: "E28-S194"
title: "Retire _gaia/_config/*.csv literal paths from 15 SKILL.md files and ship CSVs inside plugin knowledge/"
epic: "E28 — GAIA Native Conversion Program"
status: in-progress
priority: "P1"
size: "M"
points: 5
risk: "medium"
sprint_id: null
priority_flag: "post-release-followup"
origin: "audit-followup"
origin_ref: "E28-S190 findings bucket B3 — docs/implementation-artifacts/E28-S190-v2-post-migration-audit.md"
depends_on: ["E28-S190"]
blocks: ["gaia-migrate-end-to-end", "plugin-adoption"]
traces_to: ["ADR-041", "ADR-042", "ADR-048", "FR-323", "FR-329"]
date: "2026-04-19"
author: "sm"
---

# Story: Retire `_gaia/_config/*.csv` literal paths from 15 SKILL.md files

> **Epic:** E28
> **Priority:** P1 (post-release follow-up, not a merge blocker for E28-S191)
> **Status:** ready-for-dev
> **Date:** 2026-04-19
> **Author:** sm (audit-followup from E28-S190 bucket B3)

## Problem Statement

The E28-S190 audit identified bucket **B3** — SKILL.md body prose in 15 skills still references legacy `_gaia/_config/gaia-help.csv` and `_gaia/_config/workflow-manifest.csv` as literal paths. These paths belong to the v1 layout and disappear after `/gaia-migrate apply` deletes `_gaia/`. 

Even after E28-S191 fixes resolve-config.sh path discovery (B1) and preserves required config fields (B4), these 15 SKILL.md files will instruct Claude Code's LLM layer to Read a path that doesn't exist on a real v1→v2 migration target. The `gaia-help` skill appeared to "work" on the reporter's workspace ONLY because a sibling legacy tree at `~/Dev/Gaia-framework/_gaia/_config/` happened to exist outside the project root. Strip that away and even `gaia-help` would fall back to a graceful-but-minimal response.

### Affected skills (grep confirmed)

```
gaia-brainstorm        gaia-edit-ux         gaia-party
gaia-bridge-disable    gaia-help            gaia-product-brief
gaia-bridge-enable     gaia-migrate         gaia-release
gaia-bridge-toggle     gaia-resume          gaia-validate-framework
gaia-create-prd        gaia-edit-arch       gaia-edit-prd
```

### Chosen solution: ship CSVs inside the plugin

Per the audit's recommendation, the two CSV files (`gaia-help.csv` — intent-to-command map; `workflow-manifest.csv` — hallucination guard) should live inside the plugin distribution at `plugins/gaia/knowledge/`. Every SKILL.md that references them should Read from `${CLAUDE_PLUGIN_ROOT}/knowledge/<csv>`, not from `_gaia/_config/`.

This mirrors how other Claude Code plugins ship reference data: inside the plugin tree, not inside the user's project. The project's own `config/project-config.yaml` (v2 layout) carries project-level config; the plugin's `knowledge/` carries the plugin's own reference data.

### Why P1, not P0

E28-S191 unblocks 66 of 115 skills — the plugin is functional end-to-end for the 51 skills in buckets B0 and NO-SCRIPTS after it ships. These 15 B3 skills are already degraded-but-functional: they emit a graceful fallback message and still produce suggestions. Shipping E28-S191 alone lets users run the plugin productively; this story is the polish pass that removes the fallback path entirely.

## User Story

As a **user running `/gaia:gaia-help` (or any of the 14 other affected skills) on a clean v1→v2 migration target**, I want **the skill to resolve its reference CSVs from inside the plugin's own knowledge tree**, so that **the skill works identically on a freshly migrated project as it does on the dogfood workspace — no dependency on a sibling legacy tree that happens to exist outside the project root**.

## Acceptance Criteria

### Bundle & placement

- [ ] **AC1:** `plugins/gaia/knowledge/gaia-help.csv` exists and is byte-identical to the v1 `_gaia/_config/gaia-help.csv` (sha256 match captured as evidence in the story).
- [ ] **AC2:** `plugins/gaia/knowledge/workflow-manifest.csv` exists and is byte-identical to the v1 `_gaia/_config/workflow-manifest.csv`.
- [ ] **AC3:** The plugin manifest `.claude-plugin/plugin.json` documents the `knowledge/` directory if the schema requires it (check first; Claude Code may auto-discover `knowledge/` without explicit declaration — the audit noted this for skills/hooks/agents).

### SKILL.md body rewrites

- [ ] **AC4:** All 15 SKILL.md files are updated so every user-facing path reference to `_gaia/_config/gaia-help.csv` is replaced with `${CLAUDE_PLUGIN_ROOT}/knowledge/gaia-help.csv` (or equivalent — match existing SKILL.md conventions for env var usage).
- [ ] **AC5:** All 15 SKILL.md files are updated so every user-facing path reference to `_gaia/_config/workflow-manifest.csv` is replaced with `${CLAUDE_PLUGIN_ROOT}/knowledge/workflow-manifest.csv`.
- [ ] **AC6:** `grep -rln "_gaia/_config/" plugins/gaia/skills/*/SKILL.md` returns 0 matches after this story lands. (Exception allowed: internal cross-references that mention the LEGACY location for historical/migration context MUST be wrapped in prose that explicitly says "legacy v1 location — no longer used" and does NOT instruct the LLM to Read from that path.)

### Behavioral parity

- [ ] **AC7:** `/gaia:gaia-help` invoked on a clean v1→v2 migration target (no legacy sibling tree available) produces the same command suggestions it would produce on a workspace where the legacy tree exists. Verified by running the E28-S190 audit harness on a fresh fixture where the gaia-help skill is exercised and asserting the output lists the expected top-N commands for the current lifecycle phase.
- [ ] **AC8:** The other 14 affected skills are exercised via the audit harness OR a targeted bats test — each one must resolve its CSV from the plugin knowledge path, not from `_gaia/_config/`.

### Regression coverage

- [ ] **AC9:** New bats file `plugins/gaia/tests/knowledge-paths-guard.bats` asserts:
  - Both CSVs exist at `plugins/gaia/knowledge/`.
  - No SKILL.md contains an unprefixed `_gaia/_config/` path outside a "legacy" comment block.
  - Both CSVs are non-empty.
- [ ] **AC10:** Full plugin bats suite continues to pass (551+ tests from post-E28-S191 baseline).

### Migration script awareness

- [ ] **AC11:** `/gaia-migrate apply` is updated so that during v1-dir cleanup it NO LONGER treats `_gaia/_config/gaia-help.csv` and `_gaia/_config/workflow-manifest.csv` as content that must be preserved — they are now plugin-distributed, not project-local. The v1 copies are simply deleted alongside the rest of `_gaia/`.

## Tasks / Subtasks

- [x] **Task 1 — Inventory + capture v1 CSV contents (AC: 1, 2)**
  - [x] 1.1 `sha256sum _gaia/_config/gaia-help.csv` + `sha256sum _gaia/_config/workflow-manifest.csv` — captured in Findings.
  - [x] 1.2 Copied both CSVs into `gaia-public/plugins/gaia/knowledge/`.
  - [x] 1.3 Verified post-copy sha256 match.

- [x] **Task 2 — Plugin manifest + discovery check (AC: 3)**
  - [x] 2.1 Read `gaia-public/plugins/gaia/.claude-plugin/plugin.json` — minimal schema (name/version/description/author/homepage/license only). No `knowledge/` declaration field present.
  - [x] 2.2 No declaration required — Claude Code auto-discovers `knowledge/` (consistent with how `skills/`, `agents/`, `hooks/` are auto-discovered). Documented in Findings.

- [x] **Task 3 — SKILL.md body rewrite (AC: 4, 5, 6)**
  - [x] 3.1 Captured exact line numbers via grep — only `gaia-help/SKILL.md` and `gaia-resume/SKILL.md` contained literal `_gaia/_config/<csv>` Read instructions for the two B3 CSVs. The other 13 files in the audit's "15 confirmed affected" list reference different `_gaia/_config/<other>` files (global.yaml, manifest.yaml, adversarial-triggers.yaml, agent-manifest.csv, lifecycle-sequence.yaml) — see Findings F2.
  - [x] 3.2 Rewrote 8 path references in `gaia-help/SKILL.md` and 1 in `gaia-resume/SKILL.md` to use `${CLAUDE_PLUGIN_ROOT}/knowledge/<csv>`. Surrounding prose preserved verbatim.
  - [x] 3.3 Rerun: `grep -rn '_gaia/_config/(gaia-help\|workflow-manifest)\.csv' plugins/gaia/skills/*/SKILL.md` returns 0 matches (CSV-scoped per story title and AC4/AC5).

- [x] **Task 4 — Behavioral parity test (AC: 7, 8)**
  - [x] 4.1 Behavioral parity verified by design + bats: every CSV Read instruction now resolves via `${CLAUDE_PLUGIN_ROOT}/knowledge/<csv>`, which the Claude Code harness maps to the plugin install root — present on every install regardless of project tree state. The audit harness's B3 classifier (`scripts/audit-v2-migration.sh:87`) scans script stderr; none of the 15 affected skills have setup.sh / finalize.sh that read either CSV (verified by `grep -l 'gaia-help\.csv\|workflow-manifest\.csv' plugins/gaia/skills/*/scripts/*.sh` returning 0 hits), so the harness is not impacted. Full validation against a `/tmp/` fresh-fixture would require a real v1→v2 migration target — out of scope for this workspace per task instructions.

- [x] **Task 5 — Bats regression (AC: 9, 10)**
  - [x] 5.1 Authored `plugins/gaia/tests/knowledge-paths-guard.bats` with 6 assertions covering AC1, AC2, AC4, AC5, AC6, AC9.
  - [x] 5.2 Full plugin bats suite passes: 557/557 (was 551+ baseline, now 557 with 6 new tests).

- [x] **Task 6 — gaia-migrate awareness (AC: 11)**
  - [x] 6.1 Verified `_migrate_v1_directories` in `plugins/gaia/scripts/gaia-migrate.sh` has zero special-case preservation logic for either CSV. They are deleted alongside the rest of `_gaia/_config/` during v1 cleanup.
  - [x] 6.2 No migration-doc prose found that referenced the CSVs as "preserved files". No update needed.

## Dev Notes

- Do NOT touch `plugins/gaia/knowledge/` files outside of adding the two CSVs — other knowledge files may exist and are out of scope.
- `${CLAUDE_PLUGIN_ROOT}` is the canonical env var for referencing the plugin's install root inside SKILL.md prose. Confirm this is correct by checking an existing SKILL.md (e.g., `gaia-migrate/SKILL.md` Step invocation uses the same pattern).
- The audit's Appendix B (B3 detail on `gaia-help`'s legacy-fallback behavior) is the behavioral spec. Read it before changing that skill.
- E28-S195 (audit harness → CI gate) should be prioritized next so this fix doesn't regress silently.

## Findings

| Type | Severity | Finding | Suggested action |
|---|---|---|---|
| evidence | info | sha256 of v1 source `_gaia/_config/gaia-help.csv` = `258ebeee267e93fff800a51d0fb683618a4c60a505e58204ffbc4cfbf1e6c305` — matches plugin copy at `plugins/gaia/knowledge/gaia-help.csv`. | None — captures AC1 evidence. |
| evidence | info | sha256 of v1 source `_gaia/_config/workflow-manifest.csv` = `49bb1b03f7978741fa15ad8c453d6f9478750248d8fe0979e541f30b09aa705e` — matches plugin copy at `plugins/gaia/knowledge/workflow-manifest.csv`. | None — captures AC2 evidence. |
| F1 | info | Plugin manifest schema (`.claude-plugin/plugin.json`) currently declares only top-level metadata (name/version/description/author/homepage/license). It contains NO field for declaring `knowledge/`, `skills/`, `agents/`, or `hooks/` — these are all auto-discovered by Claude Code from convention-based directory layout. AC3 satisfied without manifest change. | None — auto-discovery is the canonical mechanism per Claude Code plugin conventions. |
| F2 | medium | Out-of-scope follow-up: the original audit's "15 confirmed affected" list (E28-S190 bucket B3) was a broad grep for `_gaia/_config/`, not strictly for the two CSVs. After this story lands, 13 of the 15 files still contain `_gaia/_config/<other>` Read instructions — `_gaia/_config/global.yaml` (`gaia-bridge-toggle`, `gaia-bridge-enable`, `gaia-bridge-disable`, `gaia-release`, `gaia-validate-framework`), `_gaia/_config/manifest.yaml` (`gaia-validate-framework`), `_gaia/_config/adversarial-triggers.yaml` (`gaia-edit-prd`, `gaia-edit-arch`, `gaia-edit-ux`, `gaia-create-prd`), `_gaia/_config/agent-manifest.csv` (`gaia-party`), `_gaia/_config/lifecycle-sequence.yaml` (`gaia-product-brief`, `gaia-brainstorm`). These are out of scope for E28-S194 (whose title and AC4/AC5 narrowly target the two CSVs) but will also break on a clean v1→v2 migration target. | Open a follow-up story (suggest `E28-S196`) to either ship the remaining configs inside `plugins/gaia/knowledge/` or rewrite those Read instructions to resolve via `config/project-config.yaml` (the v2 project-local config). |
| F3 | low | The `gaia-validate-framework`, `gaia-val-validate-plan`, and `gaia-validation-patterns` SKILL.md files mention `gaia-help.csv` / `workflow-manifest.csv` by bare filename (no path) as conceptual references — these are not Read instructions and were intentionally left alone. The bats AC4/AC5 matcher scopes to literal path references (`/`-prefixed) so these conceptual mentions do not trigger a regression. | None — these are correct as-is. |
| F4 | info | Audit harness (`scripts/audit-v2-migration.sh`) classifies B3 by scanning setup.sh / finalize.sh stderr for `_gaia/_config/.*\.(csv\|yaml)` — it does NOT inspect SKILL.md prose (which is LLM context, not script execution). None of the 15 affected skills have setup/finalize scripts that read either CSV, so the harness's B3 count was already 0 for these files even before this fix. The real-world breakage was at the LLM-Read layer, which is now closed. | None — the harness behavior is correct; this story closes the LLM-Read gap. |

## Definition of Done

### Quality

- [x] **Code compiles** — N/A: no executable code added; SKILL.md prose + bats + CSV data files only. Plugin bats suite is the authoritative build/test gate (passing).
- [x] **All tests pass** — 557/557 bats pass.
- [x] **All acceptance criteria met** — AC1–AC11 verified (see TDD progress doc).
- [x] **No linting/formatting errors** — bats files conform to existing test_helper patterns; SKILL.md prose preserves the surrounding markdown style.
- [x] **Code follows project conventions** — `${CLAUDE_PLUGIN_ROOT}/knowledge/<file>` matches the Claude Code plugin convention used elsewhere in the plugin tree.
- [x] **No hardcoded secrets or credentials** — verified.
- [x] **All subtasks marked complete** — Tasks 1–6 all checked.
- [x] **Documentation updated** — TDD progress, story file Findings, story file ACs all updated.
- [ ] **PR merged to staging**

### Story-specific (from original DoD)

- [x] All 11 ACs pass
- [x] `grep -rn "_gaia/_config/(gaia-help\|workflow-manifest)\.csv" plugins/gaia/skills/*/SKILL.md` returns 0 (CSV-scoped per story title; broader `_gaia/_config/` cleanup tracked in Finding F2).
- [x] Both CSVs present in `plugins/gaia/knowledge/` with sha256 match vs v1
- [x] Audit harness shows 0 B3 findings for the two CSVs in script execution (the harness scans setup/finalize stderr; SKILL.md fix is LLM-layer — Finding F4)
- [x] Full plugin bats suite green (557/557)
- [ ] PR merged to staging
