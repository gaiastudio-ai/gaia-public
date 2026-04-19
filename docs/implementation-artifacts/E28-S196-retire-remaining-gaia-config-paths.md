---
template: 'story'
version: 1.4.0
used_by: ['create-story']
key: "E28-S196"
title: "Retire remaining _gaia/_config/* paths from 12 SKILL.md files — ship 4 files to plugin knowledge/, drop global.yaml reference"
epic: "E28 — GAIA Native Conversion Program"
status: in-progress
priority: "P1"
size: "M"
points: 5
risk: "medium"
sprint_id: null
priority_flag: "post-release-followup"
origin: "audit-followup"
origin_ref: "E28-S190 findings B3 continuation + E28-S194 Finding F2 + Theo architect review at docs/planning-artifacts/E28-S196-scope-architect-review.md + Derek PM review at docs/planning-artifacts/E28-S196-scope-pm-review.md"
depends_on: ["E28-S190", "E28-S194"]
blocks: ["gaia-migrate-end-to-end", "plugin-adoption"]
traces_to: ["ADR-041", "ADR-042", "ADR-044", "ADR-048", "FR-323", "FR-329"]
date: "2026-04-19"
author: "sm"
---

# Story: Retire remaining `_gaia/_config/*` paths from SKILL.md — ship 4 files to plugin knowledge/, drop global.yaml reference

> **Epic:** E28
> **Priority:** P1 (gates clean v1→v2 migration; not a merge blocker for E28-S191)
> **Status:** ready-for-dev
> **Date:** 2026-04-19
> **Author:** sm (audit-followup, Theo + Derek reviews consolidated)

## Problem Statement

E28-S194 closed the `gaia-help.csv` + `workflow-manifest.csv` subset of bucket B3 from the E28-S190 audit. E28-S194's Finding F2 surfaced that the audit undercounted: 13 additional SKILL.md files reference a **different** set of legacy `_gaia/_config/*` paths that the original grep missed. On a clean v1→v2 migration target, every one of these Read instructions fails because `/gaia-migrate apply` (E28-S188) deletes `_gaia/`.

This story closes out the remaining 5 legacy config files and their 12 SKILL.md consumers (1 file is shared between validate-framework and another).

### The 5 residual files and their disposition (per Theo's architect review)

| File | Decision | Reason |
|---|---|---|
| `global.yaml` | **D — Drop reference** | Project-local / machine-local under ADR-044. Already split into `config/project-config.yaml` + `config/global.yaml`. The 5 SKILL.md consumers just need prose rewritten to target ADR-044 keys — no file ships. |
| `manifest.yaml` | **A — Ship in plugin** at `plugins/gaia/knowledge/manifest.yaml` | Framework knowledge (module inventory). 1 consumer (validate-framework). |
| `adversarial-triggers.yaml` | **A — Ship in plugin** | Policy table, identical for every project. 4 consumers (create-prd, edit-prd, edit-arch, edit-ux). |
| `agent-manifest.csv` | **A — Ship in plugin** (with path-column rewrite) | Agent registry = framework knowledge. 1 consumer (gaia-party). v1 CSV's `path` column points at legacy `_gaia/lifecycle/agents/*.md`; either drop the column or rewrite to `plugins/gaia/agents/{id}.md`. Architect recommends drop — party invokes by id. |
| `lifecycle-sequence.yaml` | **A — Ship in plugin** | Routing table, 19 KB. 2 SKILL.md consumers (brainstorm, product-brief) + 1 script consumer (`next-step.sh`). |

### Consuming SKILL.md files (12 distinct)

- `global.yaml` → bridge-disable, bridge-enable, bridge-toggle, release, validate-framework (rewrite to ADR-044 targets, no new backing file)
- `manifest.yaml` → validate-framework (overlaps with bridge/release; net +1 file = 1)
- `adversarial-triggers.yaml` → create-prd, edit-prd, edit-arch, edit-ux
- `agent-manifest.csv` → party
- `lifecycle-sequence.yaml` → brainstorm, product-brief

Net: 5 + 4 + 1 + 2 = **12 distinct SKILL.md files**, with validate-framework consuming 2 files.

## User Story

As a **user who has run `/gaia:gaia-migrate apply` on a real v1 project**, I want **every plugin skill's body prose to reference paths that actually exist on the post-migration filesystem**, so that **skills like `/gaia:gaia-party`, `/gaia:gaia-create-prd`, `/gaia:gaia-brainstorm`, and the bridge-toggle family produce the same output on a freshly migrated project as they do on the dogfood workspace — no fallback to missing files, no degraded-but-functional responses.**

## Acceptance Criteria

### Plugin knowledge/ bundle

- [x] **AC1:** `plugins/gaia/knowledge/manifest.yaml` exists and is byte-identical to the v1 `_gaia/_config/manifest.yaml` (sha256 captured as evidence).
- [x] **AC2:** `plugins/gaia/knowledge/adversarial-triggers.yaml` exists and is byte-identical to the v1 source.
- [x] **AC3:** `plugins/gaia/knowledge/agent-manifest.csv` exists. Either byte-identical to v1 (if path column kept and rewritten) OR structurally equivalent with the `path` column dropped per architect recommendation. Decision + evidence captured in Findings.
- [x] **AC4:** `plugins/gaia/knowledge/lifecycle-sequence.yaml` exists and is byte-identical to the v1 source.
- [x] **AC5:** Plugin's `dead-reference-scan.sh` allowlist extended to cover the 4 new files in `plugins/gaia/knowledge/` (follows E28-S194 precedent).

### SKILL.md rewrites — option A files (point at plugin knowledge)

- [x] **AC6:** `validate-framework/SKILL.md` resolves manifest.yaml from `${CLAUDE_PLUGIN_ROOT}/knowledge/manifest.yaml`. No `_gaia/_config/manifest.yaml` references remain.
- [x] **AC7:** `create-prd/SKILL.md`, `edit-prd/SKILL.md`, `edit-arch/SKILL.md`, `edit-ux/SKILL.md` all resolve adversarial-triggers.yaml from `${CLAUDE_PLUGIN_ROOT}/knowledge/adversarial-triggers.yaml`.
- [x] **AC8:** `party/SKILL.md` resolves agent-manifest.csv from `${CLAUDE_PLUGIN_ROOT}/knowledge/agent-manifest.csv`.
- [x] **AC9:** `brainstorm/SKILL.md`, `product-brief/SKILL.md` resolve lifecycle-sequence.yaml from `${CLAUDE_PLUGIN_ROOT}/knowledge/lifecycle-sequence.yaml`.

### SKILL.md rewrites — option D file (drop global.yaml reference)

- [x] **AC10:** `bridge-disable/SKILL.md`, `bridge-enable/SKILL.md`, `bridge-toggle/SKILL.md` rewrite prose to target the `test_execution_bridge.bridge_enabled` key in `config/project-config.yaml` (via resolve-config.sh for reads; direct yaml-edit-in-place for writes). No `_gaia/_config/global.yaml` references remain.
- [x] **AC11:** `release/SKILL.md` rewrites prose to target the `framework_version` key via resolve-config.sh output. No `_gaia/_config/global.yaml` reference remains.
- [x] **AC12:** `validate-framework/SKILL.md` (second pass) rewrites any remaining `_gaia/_config/global.yaml` reference to use resolve-config.sh output. Combined with AC6, validate-framework ends this story with zero `_gaia/_config/*` references.

### Script consumer update

- [x] **AC13:** `plugins/gaia/scripts/next-step.sh` (or wherever in the plugin the `lifecycle-sequence.yaml` consumer lives) resolves from `${CLAUDE_PLUGIN_ROOT}/knowledge/lifecycle-sequence.yaml` — not from `_gaia/_config/lifecycle-sequence.yaml`.

### Guard + regression

- [x] **AC14:** `grep -rnE "_gaia/_config/(global|manifest|adversarial-triggers|agent-manifest|lifecycle-sequence)" plugins/gaia/skills/*/SKILL.md` returns 0 matches. Existing exception from E28-S194 still allowed: prose explicitly labeled "legacy v1 location — no longer used" is ignored.
- [x] **AC15:** Extend `plugins/gaia/tests/knowledge-paths-guard.bats` to include existence + non-empty assertions for the 4 new files. Add 1 consistency-guard test: every `agent-id` in `agent-manifest.csv` has a matching `plugins/gaia/agents/{id}.md` file.
- [x] **AC16:** Full plugin bats suite passes (557+ tests from post-E28-S194 baseline, plus new).
- [x] **AC17:** Audit harness (`scripts/audit-v2-migration.sh`) on a fresh v1→v2 fixture shows 0 B3 failures. The 8 B5 residuals from E28-S191 are allowed to remain — they are tracked in a separate triage story.

### ADR amendment

- [x] **AC18:** `architecture.md` ADR-041 (or its plugin-layout subsection) updated to document `knowledge/` as a canonical plugin directory alongside `skills/`, `agents/`, `hooks/`, `scripts/`. Use Theo's draft text from the architect review verbatim or near-verbatim.

## Tasks / Subtasks

- [x] **Task 1 — Inventory + copy (AC: 1, 2, 3, 4, 5)**
  - [x] 1.1 `sha256sum` all 4 v1 source files; capture in Findings.
  - [x] 1.2 Copy into `plugins/gaia/knowledge/`; re-hash; verify byte match.
  - [x] 1.3 For `agent-manifest.csv`: decide keep-path-column vs drop; execute and capture rationale.
  - [x] 1.4 Extend `dead-reference-scan.sh` allowlist.

- [x] **Task 2 — SKILL.md rewrites, option A files (AC: 6, 7, 8, 9)**
  - [x] 2.1 `grep -n "_gaia/_config/<file>"` for each of manifest.yaml, adversarial-triggers.yaml, agent-manifest.csv, lifecycle-sequence.yaml; capture line numbers for each of the 8 consumer SKILL.md files.
  - [x] 2.2 Rewrite each to `${CLAUDE_PLUGIN_ROOT}/knowledge/<file>` preserving surrounding prose.

- [x] **Task 3 — SKILL.md rewrites, option D file (AC: 10, 11, 12)**
  - [x] 3.1 Map each `_gaia/_config/global.yaml` reference in bridge-disable, bridge-enable, bridge-toggle, release, validate-framework to its ADR-044 target.
  - [x] 3.2 Rewrite prose accordingly. Bridge family targets `test_execution_bridge.bridge_enabled`; release targets `framework_version`; validate-framework targets resolve-config.sh output.

- [x] **Task 4 — Script consumer update (AC: 13)**
  - [x] 4.1 Locate any plugin script reading `_gaia/_config/lifecycle-sequence.yaml` (expected: `next-step.sh`).
  - [x] 4.2 Rewrite the path.

- [x] **Task 5 — Guard + bats regression (AC: 14, 15, 16)**
  - [x] 5.1 Extend `knowledge-paths-guard.bats` with existence + agent-id-consistency assertions.
  - [x] 5.2 Run the full bats suite; 557+ pass.

- [x] **Task 6 — Audit harness green gate (AC: 17)**
  - [x] 6.1 Run `scripts/audit-v2-migration.sh` on /tmp/ fixture.
  - [x] 6.2 Verify 0 B3 failures.

- [x] **Task 7 — ADR-041 amendment (AC: 18)**
  - [x] 7.1 Edit `docs/planning-artifacts/architecture.md` to add the `knowledge/` subsection using Theo's drafted text.

## Dev Notes

- **Inherit the E28-S194 pattern exactly** for the 4 option-A files. Same bats guard shape, same dead-reference allowlist shape, same SKILL.md rewrite idiom (`${CLAUDE_PLUGIN_ROOT}/knowledge/<file>`).
- **Option D (drop global.yaml) is new work** — specifically, the prose rewrites in the 5 SKILL.md files that consume it need to target different ADR-044 keys (bridge_enabled, framework_version, etc.). Read each SKILL.md carefully; don't blanket-substitute.
- **`agent-manifest.csv` path column** — architect recommends drop; path is derivable as `plugins/gaia/agents/{id}.md`. Verify no existing script parses the CSV expecting 6 columns before dropping.
- **next-step.sh** — also the consumer referenced in E28-S162 and E28-S194 Finding F4. Its own tests cover path resolution, so the lifecycle-sequence.yaml move must be reflected in its bats file too.
- **Do NOT run /gaia-migrate apply against the reporter's workspace.** Use /tmp/ fixtures only for audit harness runs.
- **PR target: `staging`** on gaiastudio-ai/gaia-public. Standard /gaia-dev-story flow.
- **PM scope cap: 5 pts soft, 8 pts hard.** If option D's rewrites blow up larger than expected, split into an E28-S197 for the global.yaml-dropping subset and ship option A first.

## Findings

| Type | Severity | Finding | Suggested Action |
|------|----------|---------|------------------|
| inventory | INFO | v1 source sha256 captured: manifest.yaml `33b84dde70…ea0b3`, adversarial-triggers.yaml `aa339c3751…ba13bc`, agent-manifest.csv `9c2eeea7da…4b9cf465`, lifecycle-sequence.yaml `f48c8e596c…06ca9c634`. 3 of 4 plugin copies byte-identical; agent-manifest.csv structurally modified (path column dropped per architect recommendation). | None — evidence captured for traceability. |
| decision | INFO | `agent-manifest.csv` path column dropped per Theo's architect review (open question #2). Verified no plugin script parses the CSV expecting 6 columns (only `gaia-party` SKILL.md is the documented consumer and it invokes agents by id). Party SKILL.md prose updated to note the id→plugin-path derivation (`plugins/gaia/agents/{id}.md`). | None. |
| scope-edge | INFO | `gaia-migrate/SKILL.md` lines 60–61 reference `_gaia/_config/global.yaml` in v1-destructive-migration context (describing what `/gaia-migrate apply` does to a v1 install). These are contractual migration-tool descriptions, not active reads on post-migration filesystem. Treated as out-of-scope per architect intent and carved out in the bats guard (matches the dead-reference-scan.sh pre-existing allowlist for gaia-migrate). | None. |
| follow-up | INFO | `scripts/version-bump.js` (in the root `Gaia-framework/` workspace) still targets the v1 path `_gaia/_config/global.yaml` for the `framework_version` bump. The release SKILL.md prose was rewritten to reference the key rather than the v1 path (AC11) and now describes version-bump.js's reported output as the authoritative file list, so the skill is forward-compatible with a future version-bump.js update. The script itself is a separate v1→ADR-044 migration item. | File a follow-up story to re-target `version-bump.js` at `config/project-config.yaml` per ADR-044. Not a blocker for E28-S196 per PM scope cap. |
| verification | INFO | Full plugin bats suite (572 tests) green — up from the 557-test baseline noted in AC16. 15 new S196 guard tests added to `knowledge-paths-guard.bats`. | None. |
| verification | INFO | Audit harness (`scripts/audit-v2-migration.sh`) on /tmp/ fixture: 115 skills scanned, 0 B3 failures (bucket_B3_skill_md_literal_paths: 0). B5 residuals (66) are the separate bucket tracked outside this story. | None — AC17 satisfied. |

## Definition of Done

### Quality

- [x] Code compiles — plugin is documentation + bash scripts; bash files pass `bash -n` implicitly via bats execution.
- [x] All tests pass — 572/572 plugin bats green.
- [x] All acceptance criteria met — 18/18 ACs satisfied (see checklist above).
- [x] No linting/formatting errors — shellcheck-clean on edited scripts; markdown uses existing conventions.
- [x] Code follows project conventions — inherits E28-S194 pattern for file shipping, bats guard shape, dead-reference-scan allowlist shape, and SKILL.md rewrite idiom.
- [x] No hardcoded secrets or credentials — no secrets introduced.
- [x] All subtasks marked complete — Tasks 1–7 executed.
- [x] Documentation updated — ADR-041 amended with `knowledge/` convention (AC18).
- [ ] PR merged to staging

### Story-specific

- [x] `grep -rnE "_gaia/_config/(global|manifest|adversarial-triggers|agent-manifest|lifecycle-sequence)" plugins/gaia/skills/*/SKILL.md` returns 0 matches outside the gaia-migrate v1-context carve-out
- [x] 4 new files present in `plugins/gaia/knowledge/` (sha256/structural verification captured in Findings)
- [x] Audit harness returns 0 B3 failures on fresh fixture (/tmp/gaia-E28-S196-audit.*)
- [x] Full plugin bats suite green (572 tests)
- [x] ADR-041 amended (plugin directory conventions subsection added)

## Files Changed

**New files (4):**
- `plugins/gaia/knowledge/manifest.yaml`
- `plugins/gaia/knowledge/adversarial-triggers.yaml`
- `plugins/gaia/knowledge/agent-manifest.csv`
- `plugins/gaia/knowledge/lifecycle-sequence.yaml`

**Modified SKILL.md (12):**
- `plugins/gaia/skills/gaia-bridge-disable/SKILL.md`
- `plugins/gaia/skills/gaia-bridge-enable/SKILL.md`
- `plugins/gaia/skills/gaia-bridge-toggle/SKILL.md`
- `plugins/gaia/skills/gaia-release/SKILL.md`
- `plugins/gaia/skills/gaia-validate-framework/SKILL.md`
- `plugins/gaia/skills/gaia-create-prd/SKILL.md`
- `plugins/gaia/skills/gaia-edit-prd/SKILL.md`
- `plugins/gaia/skills/gaia-edit-arch/SKILL.md`
- `plugins/gaia/skills/gaia-edit-ux/SKILL.md`
- `plugins/gaia/skills/gaia-party/SKILL.md`
- `plugins/gaia/skills/gaia-brainstorm/SKILL.md`
- `plugins/gaia/skills/gaia-product-brief/SKILL.md`

**Modified scripts + tests (3):**
- `plugins/gaia/scripts/next-step.sh` (plugin knowledge/ candidate prepended)
- `plugins/gaia/scripts/dead-reference-scan.sh` (allowlist comment updated; knowledge/ wildcard already covered new files)
- `plugins/gaia/tests/knowledge-paths-guard.bats` (+15 new tests)

**Modified docs (1):**
- `docs/planning-artifacts/architecture.md` (ADR-041 amendment)

## Review Gate

| Review | Status | Report |
|--------|--------|--------|
| Code Review | UNVERIFIED | — |
| QA Tests | UNVERIFIED | — |
| Security Review | UNVERIFIED | — |
| Test Automation | UNVERIFIED | — |
| Test Review | UNVERIFIED | — |
| Performance Review | UNVERIFIED | — |
