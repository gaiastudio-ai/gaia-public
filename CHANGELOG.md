# Changelog

All notable changes to the `gaia-public` marketplace and the `gaia` plugin are recorded here.
This file tracks sprint-level resolutions and decisions — for commit-level history, see `git log`.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) loosely, and the
project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html) for the `gaia` plugin
(tracked in `plugins/gaia/.claude-plugin/plugin.json`).

## [Unreleased]

### Sprint 19 (E28 — GAIA Native Conversion Program)

#### Documentation

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
