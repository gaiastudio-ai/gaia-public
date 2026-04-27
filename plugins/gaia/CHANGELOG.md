# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.128.0] — 2026-04-23

### Added

- (release) pivot release.yml to PR model + ADR-056 (E40-S1)

## [1.127.2] — 2026-04-23

### Added

- Release automation pipeline (E40-S1 / ADR-056). The first automated release will land in v1.128.0.

### Changed

- **ADR-056 amendment (2026-04-23):** `release.yml` pivoted from direct-bot-push to a PR-based model. Branch protection on `main` requires PR + status checks, which the original direct-push design could not satisfy. The workflow now has two modes — `prepare` (opens a `release/vX.Y.Z` PR on qualifying commits to main) and `publish` (cuts tag + GitHub Release when the release PR merges). Manual work per release: one click to merge the release PR.

Initial changelog seeded by E40-S1. Prior history available via `git log --oneline -- plugins/gaia/`.
