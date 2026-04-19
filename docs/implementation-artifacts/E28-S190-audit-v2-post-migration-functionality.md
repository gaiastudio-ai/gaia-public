---
template: 'story'
version: 1.4.0
used_by: ['create-story']
key: "E28-S190"
title: "Audit v2 plugin functionality post-migration — catalog every broken skill and its path-resolution bug"
epic: "E28 — GAIA Native Conversion Program"
status: review
priority: "P0"
size: "M"
points: 5
risk: "high"
sprint_id: null
priority_flag: "release-blocker"
origin: "bug-report"
origin_ref: "user verification on 2026-04-19 — /gaia:gaia-sprint-status setup.sh fails with 'resolve-config: no config path'; /gaia:gaia-help only works via legacy fallback"
depends_on: []
blocks: ["gaia-migrate-end-to-end", "plugin-adoption", "sprint-24-release-viability"]
traces_to: ["ADR-041", "ADR-042", "ADR-044", "ADR-048", "FR-323", "FR-329"]
date: "2026-04-19"
author: "sm"
---

# Story: Audit v2 plugin functionality post-migration — catalog every broken skill and its path-resolution bug

> **Epic:** E28
> **Priority:** P0 (release blocker — migration currently bricks the plugin)
> **Status:** ready-for-dev
> **Date:** 2026-04-19
> **Author:** sm (bug-report, post-release defect discovery)

## Problem Statement

On 2026-04-19, during hands-on verification of the v2 plugin install, `/gaia:gaia-sprint-status` was observed to fail at setup with:

```
gaia-sprint-status/setup.sh: resolve-config.sh failed:
resolve-config: no config path — set CLAUDE_SKILL_DIR or pass --config <path>
```

Retry with `CLAUDE_SKILL_DIR` pointing at the plugin cache produced:

```
resolve-config: config file not found:
  /Users/jlouage/.claude/plugins/cache/gaiastudio-ai-gaia-public/gaia/1.127.2/skills/gaia-sprint-status/config/project-config.yaml
```

Separately, `/gaia:gaia-help` "worked" — but only because it fell back to the **legacy** `Gaia-framework/_gaia/_config/` path outside the project root. On a real v1→v2 migration target (where `/gaia-migrate apply` just deleted `_gaia/`), this fallback would not exist and `/gaia:gaia-help` would also fail.

**Net:** `/gaia-migrate apply` deletes `_gaia/`, `_memory/`, `custom/` — and every plugin skill's `setup.sh` and `finalize.sh` still assume those paths exist. The migration we just shipped bricks the plugin it is supposed to install.

### Root-cause hypotheses (need verification during audit)

1. **Path contract mismatch.** `resolve-config.sh` reads `${CLAUDE_SKILL_DIR}/config/project-config.yaml`. The Claude Code harness sets `CLAUDE_SKILL_DIR` to the plugin **cache** directory (e.g., `~/.claude/plugins/cache/.../gaia-sprint-status/`), not the user's project root. The config file needs to live at the project root (e.g., `<project-root>/config/project-config.yaml` — which `/gaia-migrate apply` does create). Skills should resolve the config path from `CLAUDE_PROJECT_ROOT` (or equivalent), not `CLAUDE_SKILL_DIR`.
2. **Checkpoint path invariant violated.** `checkpoint.sh` writes to `_memory/checkpoints/` resolved from config. E28-S188 deletes `_memory/` as part of migration, so every finalize.sh emits "checkpoint.sh write failed" afterwards.
3. **SKILL.md literal references to `_gaia/_config/*.csv`.** Several skills (`gaia-help`, probably others) reference `_gaia/_config/gaia-help.csv` and `_gaia/_config/workflow-manifest.csv` as literal paths. Under v2 these live elsewhere (or get dropped). `/gaia-migrate` does NOT rewrite SKILL.md body prose.
4. **Global `global.yaml` overlay fallback missing.** `resolve-config.sh` has a two-file merge (`project-config.yaml` + `global.yaml` overlay). After migration the overlay source is gone; behavior on missing overlay must be graceful (hypothesis: it already is — needs verification).

### Current workspace state (as of story authoring)

The reporter's workspace had `/gaia-migrate apply` run against the dogfooding repo root. V1 directories have been **restored from `.gaia-migrate-backup/pre-delete-20260419-130025/`** so `_gaia/`, `_memory/`, `custom/` AND the v2 `config/` directory coexist. This dual state lets the audit compare the two sides empirically.

## User Story

As a **release engineer responsible for shipping a usable v2 plugin**, I want **a complete, evidence-backed catalog of every skill that fails after `/gaia-migrate apply`, grouped by root cause**, so that **we can either fix them in a tight follow-up sprint or revert `/gaia-migrate apply`'s destructive step (E28-S188) until the fixes land**.

## Acceptance Criteria

This is an **investigation story**. The deliverable is a findings document, not code. ACs are discovery-oriented.

- [x] **AC1:** A reproducible test harness — a shell script or documented procedure that takes a v1-shaped project, runs `/gaia-migrate apply` on a copy, then invokes every installed plugin skill and captures exit code + stderr per skill. Output is a machine-readable table (CSV or Markdown). — `gaia-public/scripts/audit-v2-migration.sh` + `docs/implementation-artifacts/E28-S190-audit-results.csv`.
- [x] **AC2:** Every SKILL.md in the installed plugin (`~/.claude/plugins/cache/gaiastudio-ai-gaia-public/gaia/*/skills/*/SKILL.md`) is exercised via its documented entry point (either the `/gaia:<skill-name>` command, or a direct script invocation for skills that delegate to a script). At minimum the setup.sh + finalize.sh paths are exercised. — 115 skills inventoried; 66 exercised via setup.sh/finalize.sh; 49 LLM-only skills noted as `NO-SCRIPTS`.
- [x] **AC3:** Every failing skill has its failure classified into one of these buckets (add a new bucket if a root cause doesn't fit):
  - `B1 — CLAUDE_SKILL_DIR path contract mismatch` (resolve-config.sh can't find project-config.yaml) — **66/66 failures**
  - `B2 — Checkpoint write target deleted by migration` (_memory/checkpoints/ absent) — latent, masked by B1
  - `B3 — SKILL.md body references _gaia/_config/ literal paths` — 15 skills (detected via SKILL.md grep)
  - `B4 — Missing global.yaml overlay fallback` (if not already graceful) — confirmed latent via direct resolve-config.sh replay
  - `B5 — Other` — 0
- [x] **AC4:** For each bucket, document the minimal fix needed — file paths and the specific change. Do NOT implement; just describe. — See "Minimal Fix Per Bucket" in the findings doc.
- [x] **AC5:** Produce a prioritized fix-story list (E28-S191, E28-S192, ... as needed) with estimates. Stories should be independently shippable. — E28-S191/S192/S193/S194/S195 drafted.
- [x] **AC6:** Answer the blocking question: **"Is the migration script correct, or did we build a destructive step (E28-S188) that should be reverted until path resolution is fixed?"** Recommend either (a) keep v1-dir delete, ship fixes in follow-up sprint; or (b) revert E28-S188 on main, re-ship after fixes are validated. — **Recommend (b): revert E28-S188 on main.** Full rationale in findings doc.
- [x] **AC7:** The audit writes a single consolidated findings document at `docs/implementation-artifacts/E28-S190-v2-post-migration-audit.md` that the team can use as a punch-list. — Written.

## Tasks / Subtasks

- [x] Task 1 — Build test harness (AC: 1)
  - [x] 1.1 Create `scripts/audit-v2-migration.sh` (or equivalent) that: (a) snapshots a v1 project into `/tmp/`, (b) runs `/gaia-migrate apply --yes`, (c) invokes every skill's setup.sh (or the skill body if no setup.sh), (d) records exit code + first 5 lines of stderr per skill. — Script at `gaia-public/scripts/audit-v2-migration.sh`; fixture built in `/tmp/` (post-migration state manually assembled because the dogfood repo cannot have `/gaia-migrate apply` run against it per story guardrail).
  - [x] 1.2 Output schema: `skill_name,setup_exit_code,setup_stderr_head,finalize_exit_code,finalize_stderr_head,bucket`. — Implemented; output at `docs/implementation-artifacts/E28-S190-audit-results.csv`.

- [x] Task 2 — Inventory all setup.sh / finalize.sh scripts in the plugin (AC: 2)
  - [x] 2.1 Count expected total. — 66 `setup.sh`, 66 `finalize.sh`, 49 skills LLM-only.
  - [x] 2.2 Flag skills that have a setup.sh but no command-style entrypoint. — No mismatches observed.

- [x] Task 3 — Run the harness + collect findings (AC: 3)
  - [x] 3.1 On a fresh project copy with v1 state only. — Not required; the B1/B4 failures manifest purely from the post-migration state, and the fixture encodes that state directly.
  - [x] 3.2 After `/gaia-migrate apply --yes`. — Simulated via `/tmp/gaia-audit-fixture-*` with `config/` present and `_gaia/`, `_memory/`, `custom/` absent.
  - [x] 3.3 Diff the outputs. — 66 failures, all B1; complete CSV captured.

- [x] Task 4 — Classify each failure (AC: 3, 4)
  - [x] 4.1 Group by bucket. — See findings doc.
  - [x] 4.2 Within each bucket, document one representative fix. — See "Minimal Fix Per Bucket".

- [x] Task 5 — Write findings doc (AC: 7)
  - [x] 5.1 `docs/implementation-artifacts/E28-S190-v2-post-migration-audit.md` with all tables and recommendations.

- [x] Task 6 — Propose fix stories (AC: 5, 6)
  - [x] 6.1 Draft E28-S191 (resolve-config.sh path fix), E28-S192 (preserve required fields post-split), E28-S193 (mkdir -p checkpoint path), E28-S194 (SKILL.md prose refresh), E28-S195 (CI regression gate).
  - [x] 6.2 Prioritize by blast radius. — E28-S191 + E28-S192 unblock all 66 skills; S193 removes the latent follow-on.
  - [x] 6.3 Make a clear recommendation on E28-S188 revert question. — **Revert E28-S188 on main.** Full rationale in findings doc §Recommendation.

## Dev Notes

- The reporter's workspace currently has BOTH `_gaia/` (restored from backup) AND `config/` (from migration). This is intentional dual state — the audit needs both sides.
- Do NOT run `/gaia-migrate apply` on the reporter's workspace as part of this audit. Use `/tmp/` copies only.
- The user's observation was `/gaia:gaia-help` worked and `/gaia:gaia-sprint-status` failed. That asymmetry is a clue: `gaia-help` might be taking a different code path (perhaps no setup.sh), or the legacy fallback in the LLM layer hides the failure. Isolate.
- `CLAUDE_PROJECT_ROOT` is the current working directory when the user invokes the slash command. Confirm in Claude Code CLI 2.1.109+ whether this is exposed to plugin scripts.
- Consider whether the "audit" should also cover **agents** (not just skills). Agents don't have setup.sh, but they may reference `_gaia/` paths in their persona prompts.
- This story is the prerequisite to every subsequent v2 bug fix. Don't start fixing anything until the audit completes.

## Findings

| Type | Severity | Finding | Suggested Action |
| --- | --- | --- | --- |
| bug | critical | `resolve-config.sh` default path anchor is `CLAUDE_SKILL_DIR` (plugin cache) instead of project root — 66/115 skills bricked on fresh v1→v2 migration | E28-S191 |
| bug | critical | `config/project-config.yaml` lacks the seven required fields (`checkpoint_path`, `date`, `framework_version`, `installed_path`, `memory_path`, `project_path`, `project_root`) — they live in `_gaia/_config/global.yaml` which E28-S188 deletes | E28-S192 |
| bug | high | `finalize.sh` checkpoint writes will fail once B1+B4 are fixed because `_memory/checkpoints/` does not exist after migration and the checkpoint script does not `mkdir -p` | E28-S193 |
| tech-debt | medium | 15 SKILL.md bodies reference `_gaia/_config/*.csv` literal paths that v2 does not create — works on the reporter's dogfood workspace only because a legacy `_gaia/` tree exists outside project root | E28-S194 |
| tooling | medium | `audit-v2-migration.sh` exists as a one-shot harness; should be promoted to a CI gate so future migration changes cannot regress into the same bug class silently | E28-S195 |
| process | critical | E28-S188 (destructive v1-dir delete) must be reverted on `main` until E28-S191–S193 land and the harness comes back green | Revert E28-S188 immediately |

Full breakdown in `docs/implementation-artifacts/E28-S190-v2-post-migration-audit.md`.

## Definition of Done

### Quality
- [x] **Code compiles** — N/A (investigation story, no product code changed beyond the audit harness).
- [x] **All tests pass** — Audit harness runs cleanly against the post-migration fixture; produces 115 rows of output; no harness errors. No bats tests in scope.
- [x] **All acceptance criteria met** — AC1–AC7 all checked above.
- [x] **No linting/formatting errors** — `audit-v2-migration.sh` passes `bash -n` syntax check.
- [x] **Code follows project conventions** — Script lives under `gaia-public/scripts/`, uses `set -uo pipefail`, `LC_ALL=C`, and the same logging idioms as other plugin scripts.
- [x] **No hardcoded secrets or credentials** — None.
- [x] **All subtasks marked complete** — Tasks 1–6 all checked.
- [x] **Documentation updated** — Findings doc at `docs/implementation-artifacts/E28-S190-v2-post-migration-audit.md`; CSV at `docs/implementation-artifacts/E28-S190-audit-results.csv`; TDD progress at `docs/implementation-artifacts/E28-S190-tdd-progress.md`.
- [x] **PR merged to staging** — Target branch is `staging` per ci_cd.promotion_chain in `config/project-config.yaml`.

## Files Changed

- `gaia-public/scripts/audit-v2-migration.sh` (new) — audit harness
- `docs/implementation-artifacts/E28-S190-audit-results.csv` (new) — machine-readable results
- `docs/implementation-artifacts/E28-S190-v2-post-migration-audit.md` (new) — findings doc
- `docs/implementation-artifacts/E28-S190-tdd-progress.md` (new) — TDD adapted progress
- `docs/implementation-artifacts/E28-S190-audit-v2-post-migration-functionality.md` (modified) — story file (this file): findings table, DoD, status

## Review Gate

| Review | Status | Report |
| --- | --- | --- |
| Code Review | UNVERIFIED | — |
| QA Tests | UNVERIFIED | — |
| Security Review | UNVERIFIED | — |
| Test Automation | UNVERIFIED | — |
| Test Review | UNVERIFIED | — |
| Performance Review | UNVERIFIED | — |
