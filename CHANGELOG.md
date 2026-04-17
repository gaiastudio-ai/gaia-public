# Changelog

All notable changes to the `gaia-public` marketplace and the `gaia` plugin are recorded here.
This file tracks sprint-level resolutions and decisions — for commit-level history, see `git log`.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) loosely, and the
project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html) for the `gaia` plugin
(tracked in `plugins/gaia/.claude-plugin/plugin.json`).

## [Unreleased]

### Sprint 19 (E28 — GAIA Native Conversion Program)

#### Added

- **E28-S135** Cluster 19 sprint-state-machine parity test. Added
  `tests/cluster-19-e2e/sprint-state-machine.bats` (9 bats cases covering all 7
  canonical states, every documented valid transition including the blocked
  branch and the `review → in-progress` rollback, and 5 canonical invalid
  transitions that must be rejected). Added the canonical exercise fixture
  under `plugins/gaia/test/fixtures/cluster-19/sprint-state-machine/seed/`
  (story + seed `sprint-status.yaml` + seed `story-index.yaml`, all registered
  with sha256 in `fixture-manifest.yaml`) and the parity oracle at
  `plugins/gaia/test/fixtures/parity-baseline/traces/sprint-state-machine.jsonl`.
  First clean run recorded in
  `docs/test-artifacts/cluster-19/sprint-state-machine-results.md` with
  all 14 per-transition verdicts PASS and timestamp-projected parity diff = 0.
  `cluster-19-e2e-test-plan.md` matrix row 3 now points at the results artifact.

- **E28-S133** Cluster 19 full-lifecycle test runner. Added
  `plugins/gaia/test/runners/full-lifecycle.sh` — a script-driven (ADR-042)
  runner that drives the 10 canonical lifecycle stages (brainstorm →
  product-brief → PRD → UX → architecture → epics-stories → sprint-plan →
  dev-story → all-reviews → deploy-checklist) against the Cluster 19
  fixture at `plugins/gaia/test/fixtures/cluster-19/`. The runner produces
  per-stage artifacts, parity diff metadata under `runs/{run-id}/parity/`,
  and a dated evidence artifact at
  `docs/test-artifacts/cluster-19-full-lifecycle-results-{YYYY-MM-DD}.md`
  with the AC4 schema (run metadata + stages table with
  `stage | skill | exit | artifact_path | sha256 | parity_verdict` +
  summary + regressions). Non-tolerated parity deltas append to
  `docs/implementation-artifacts/e28-s133-defects.yaml` and transition the
  story back to `in-progress` (AC5) pending E28-S140. Memory isolation
  (AC-EC7) is enforced via `GAIA_MEMORY_ROOT`; run-dir collision (AC-EC6)
  is guarded; secret-leak guard runs pre-write against the results artifact
  (AC-EC8). ATDD at
  `plugins/gaia/test/e28-s133-full-lifecycle-atdd.bats` exercises all 5
  acceptance criteria (AC1..AC5) including the `--seed-regression ordering`
  path that drives the defect-logging branch. First clean full-lifecycle
  run recorded 2026-04-17.

- **E28-S132** Authored the Cluster 19 integrated end-to-end test plan at
  `docs/test-artifacts/cluster-19-e2e-test-plan.md`. Defines the greenfield
  TypeScript/pnpm test project specification, the 7-category test matrix
  (full lifecycle, review gate, sprint state machine, checkpoint resume,
  quality gates, enterprise plugin, token measurement per NFR-048 40–55%
  reduction), binary pass/fail criteria with evidence artifacts and
  escalation rules per category, the full fixture inventory with
  sha256 immutability guarantees, and the review/approval workflow for
  AC5 gating. Scaffolded the fixture directory at
  `gaia-public/plugins/gaia/test/fixtures/cluster-19/` with a
  `fixture-manifest.yaml` stub listing every required fixture (placeholders
  populated by E28-S133..E28-S139). Added a pointer from test-plan.md
  §11.37 to the Cluster 19 plan (plan is the superset; §11.37 is the
  unit-of-parity subset). Plan unblocks the seven execution stories once
  Sable + Vera sign (AC5).

- **E28-S145** Cluster 20 test gate. Added `scripts/test-config-split.sh`, a
  shellcheck-clean, idempotent wrapper that drives
  `plugins/gaia/scripts/resolve-config.sh` across four project-structure
  fixtures (`root-project`, `subdir-project`, `no-shared-config`, live repo)
  plus an overlap-precedence fixture and a missing-key behavior check, then
  writes an authoritative test report to
  `docs/migration/config-split-test-report.md`. Exercises every acceptance
  criterion from the story: AC1 (project_path="."), AC2 (project_path="my-app"),
  AC3 (live repo zero drift), AC4 (backward-compat fallback with stderr
  silence), AC5 (report artifact cross-linked from
  `docs/migration/config-split.md`). 37 / 37 assertions pass on the current
  resolver. Non-zero exit on any fixture failure so CI can gate. Cluster 20
  green signal — Clusters 19 and 21 now have the config split as a verified
  foundation.

- **E28-S144** Migrated every SKILL.md that previously read `global.yaml` or
  `config/project-config.yaml` directly to use the canonical
  `!scripts/resolve-config.sh {key}` invocation from ADR-044 §10.26.3. Migrated
  skills: `gaia-sprint-plan` (sizing_map), `gaia-rollback-plan` (full config),
  `gaia-deploy-checklist` (ci_cd.promotion_chain), `gaia-val-validate-plan`
  (framework_version), `gaia-validation-patterns` (project_path doc reference).
  Config-editor skills (`gaia-bridge-toggle`, `gaia-bridge-enable`,
  `gaia-bridge-disable`, `gaia-ci-setup`, `gaia-ci-edit`) and the meta-validator
  (`gaia-validate-framework`) are allowlisted because they act ON the file
  rather than READ from it. Added two helper scripts:
  `plugins/gaia/scripts/audit-skill-config-reads.sh` (rerunnable audit) and
  `plugins/gaia/scripts/verify-no-direct-config-reads.sh` (CI invariant guard).
  Audit artifact checked in at `docs/migration/config-split-skill-audit.md`;
  skill migration section added to `docs/migration/config-split.md`. Zero
  behavioral drift — the resolver returns the same values the direct reads
  produced because the split preserves key names 1:1.

- **E28-S143** Added `plugins/gaia/scripts/migrate-config-split.sh`, a one-shot
  POSIX bash + `yq` helper that splits an existing `_gaia/_config/global.yaml`
  into the two-file layout from ADR-044 (`config/project-config.yaml` for
  team-shared fields + a rewritten machine-local `global.yaml`). Ships with
  backup-before-write (`.bak.YYYYMMDD-HHMMSS`), refusal on pre-existing shared
  file unless `--force`, `--dry-run` plan preview, and round-trip equivalence
  verification via `resolve-config.sh`. Classification mirrors the E28-S141
  disposition table. 14 bats tests across 6 fixtures (mixed / local-only /
  shared-only inputs, missing-yq guard, overwrite refusal, round-trip). See
  `docs/migration/config-split.md` for operator instructions and the rollback
  procedure.

#### Changed

- **E28-S142** `resolve-config.sh` now implements the two-file config split from ADR-044.
  The resolver reads the team-shared `config/project-config.yaml` first as a base layer,
  then overlays the machine-local `global.yaml` (via `--local <path>`), and finally applies
  `GAIA_*` environment overrides — final precedence is `env > local > shared`. Missing local
  or shared files degrade gracefully: the pre-split single-file invocation pattern is
  preserved via the `--config <path>` alias (equivalent to `--shared`) with an empty local
  layer. Required-field validation and the `project_path` traversal guard now run on the
  post-merge map, so security checks apply identically regardless of which layer contributed
  the value. Flattened-key merge (e.g., `val_integration.template_output_review`) uses
  last-writer-wins at the dotted-key level. Smoke harness extended with eight new TC cases
  and two AC-EC cases covering disjoint-key merges, overlapping-key overrides, local-only
  and shared-only fallbacks, env-wins precedence, malformed-YAML file naming, and
  shared-sourced traversal rejection. `scripts/tests/smoke-resolve-config.sh` now runs 24
  assertions, all green.

#### Documentation

- **E28-S32** Flipped orchestrator `project_path` from `Gaia-framework` to `gaia-public`,
  closing the final deferred step of E28-S4 (AC4 / Task 8). The flip was verified against
  the running `_gaia/_config/global.yaml`, stale resolved-config entries were regenerated,
  and a sample workflow resolution confirmed `{project-path}` now maps to
  `{project-root}/gaia-public`. Sprint 19 is now fully anchored on the `gaia-public` repo
  as the canonical GAIA product source.

- **E28-S28** Fix architecture version drift. Realigned downstream E28 story copy in
  `E28-S3-refresh-gaia-ground-truth.md` to reference `Architecture v1.20.0`, matching the
  authoritative on-disk frontmatter in `docs/planning-artifacts/architecture.md`. Resolution
  direction: Option B (revert story copy) — rejected Option A (bump arch to v1.21.0) because
  no real ADR delta justified a version bump. Ground-truth planning-baseline entry updated to
  record the resolution. This change is framework-internal (no public marketplace impact) but
  is logged here for sprint traceability.

- **E28-S27** Documented empirical Claude Code plugin component discovery rules in README —
  eight scanned subdirectories, strict lowercase casing, frontmatter requirements, kebab-case
  conventions, and seven observed edge cases.

- **E28-S26** Clarified in README that private marketplace authentication uses existing
  `gh auth` credentials — no Claude Code-specific auth layer is needed or planned.

- **E28-S24** Documented `/reload-plugins` requirement and marketplace cache recovery steps
  in README.

#### Features

- **E28-S25** Added `plugins/gaia/scripts/plugin-cache-recovery.sh` — guarded alternative to
  raw `rm -rf` of polluted marketplace cache entries. Validates slug, classifies cache state
  (absent / healthy / polluted), and refuses to remove a healthy clone without `--force`.

#### Foundation scripts (plugins/gaia/scripts/)

- **E28-S9** `resolve-config.sh` — deterministic config resolution replacing LLM-driven
  inheritance chains.
- **E28-S10** `checkpoint.sh` — atomic checkpoint writer with sha256 manifest.
- **E28-S12** `lifecycle-event.sh` — lifecycle event emitter.
- **E28-S13** `memory-loader.sh` — tier-aware agent sidecar loader.
- **E28-S14** `review-gate.sh` — canonical gate status reader/writer.
- **E28-S15** `validate-gate.sh` — composite gate validator.
- **E28-S16** `template-header.sh`, `next-step.sh`, `init-project.sh` — scaffold helpers.
- **E28-S18** `project-config.yaml` schema published under `plugins/gaia/config/`.
- **E28-S19** Subagent frontmatter schema enforced in `plugins/gaia/agents/`.

---

*Entries older than sprint 19 are not yet backfilled.*
