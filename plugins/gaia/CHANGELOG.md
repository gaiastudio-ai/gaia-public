# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.130.0] — 2026-04-28

### Added

- (create-story) add YOLO param + non-YOLO [u]/[a] routing prompt (E54-S1) (#311)
- (create-story) restore V1 edge-case pipeline Steps 3b/3c/3d (E54-S4) (#310)
- (create-story) conditional ux-designer routing + parallel spawn (E54-S2) (#309)
- (scripts) unified transition-story-status.sh (E54-S3) (#308)

## [1.129.0] — 2026-04-27

### Added

- (teach-testing) operationalize JIT discipline + progressive gating
- (mobile-testing) add 90% device coverage rule and cloud config
- (scripts) producer-side token_estimate emit for val auto-fix loop (E44-S15)
- (skills) canonical document-rulesets for Phase 1 artifact types (E44-S12) (#289)
- (skills) inline-ask + scan-depth doc in /gaia-index-docs (E50-S4) (#287)
- (skills) inline confirm + slug algorithm in /gaia-merge-docs (E50-S3) (#286)
- (skills) inline-ask on empty arguments in /gaia-shard-doc (E50-S2) (#285)
- (skills) inline-ask + Next-Steps clarification in /gaia-summarize (E50-S1) (#284)
- (skills) per-dimension justification + migration trigger in /gaia-nfr (E49-S4) (#283)
- (skills) empty-context fallback interrogation in /gaia-problem-solving (E49-S3) (#282)
- (skills) severity prompt + rule table + fallback warning in /gaia-fill-test-gaps (E49-S2) (#281)
- (skills) explicit WCAG-level prompt + criterion mapping in /gaia-a11y-testing (E49-S1) (#280)
- (skills) inline AC linkage + pinned schemas in /gaia-test-gap-analysis (E48-S5) (#279)
- (skills) brownfield test-env pause + per-subagent scan diagnostics (E48-S4) (#278)
- (skills) add threat-model linkage to /gaia-review-security (E48-S3) (#277)
- (skills) plumb threat-model context into Zara dispatch (E48-S2) (#276)
- (skills) restore Val gate + assessment-doc in /gaia-add-feature (E48-S1) (#275)
- (skills) add /gaia-innovation native skill (E47-S2) (#274)
- (skills) add /gaia-design-thinking native skill (E47-S1)
- (E46-S10) narrow product-brief INDEX_GUIDED scope to brainstorm
- (E46-S9) add /gaia-product-brief plugin template and analyst assignment
- (E46-S2) restore /gaia-create-ux Import mode + read-only FR-140 audit (#270)
- (E46-S1) restore /gaia-create-ux Generate mode + FR-140 audit
- (E46-S4) readiness-check priority/schedule + compliance + self-contradiction (#268)
- (E46-S8) document /gaia-adversarial Step 4 invocation contract
- (E46-S7) add /gaia-ci-setup schema validation retry loop (#266)
- (E46-S6) add /gaia-create-arch tech-stack pause + ADR sidecar write
- (E46-S5) add /gaia-edit-test-plan orchestrator trigger inheritance
- (E46-S3) add /gaia-atdd batch mode, red-phase, and graceful exit
- (E45-S5) add VCP-MEM-04 ADR-061/ADR-057 scope-boundary regression test
- (E44-S9) add NFR-VCP-2 token-budget verification harness
- (E44-S8) document Val auto-fix iteration log format and witness via VCP-FIX-07
- (E44-S6) wire Val auto-review into 3 Phase 3 Testing artifact skills
- (E44-S5) wire Val auto-review into 6 Phase 3 Solutioning artifact skills
- (E44-S4) wire Val auto-review into 3 Phase 2 + product-brief skills
- (E44-S3) wire Val auto-review into 4 Phase 1 artifact skills (#252)
- (E45-S3) auto-save session memory at finalize for 24 Phase 1-3 skills (#251)
- (E45-S1) static `## Next Steps` sections for 10 lifecycle skills (#250)
- (E45-S4) declare discover-inputs strategy on 6 lifecycle skills
- (E45-S2) quality gates pre_start/post_complete in setup.sh/finalize.sh
- (E41-S1) yolo mode contract helper + framework lint (ADR-057)
- (E44-S7) open-question detection helper + wire into 18 skills
- (E28-S182) add SIGINT/SIGTERM trap handler to gaia-migrate.sh
- (E42-S15) port /gaia-test-framework + /gaia-atdd + /gaia-ci-setup checklists to V2
- (E42-S14) port /gaia-edit-test-plan and /gaia-test-design checklists to V2
- (E42-S13) port /gaia-readiness-check 65-item checklist to V2
- (E42-S12) port /gaia-infra-design 25-item checklist to V2
- (E42-S11) port /gaia-threat-model 25-item checklist to V2 (#235)
- (E42-S10) port /gaia-create-epics 31-item checklist to V2 (#234)
- (E42-S9) port /gaia-edit-arch 25-item checklist to V2
- (E42-S8) port /gaia-create-arch 33-item checklist to V2
- (E42-S7) port /gaia-create-ux 26-item checklist to V2
- (E42-S6) port /gaia-create-prd 36-item checklist to V2
- (E42-S5) port /gaia-product-brief 27-item checklist to V2
- (E42-S4) port /gaia-tech-research 22-item checklist to V2
- (E42-S3) port /gaia-domain-research 22-item checklist to V2
- (E42-S2) port /gaia-market-research 28-item checklist to V2
- (E42-S1) port /gaia-brainstorm 24-item checklist to V2
- (E43-S6) /gaia-resume ADR-059 JSON consumption contract
- (E43-S7) checkpoint failure-mode handling (corruption, partial writes)
- (E43-S5) wire checkpoint writes into 8 Phase 3 Testing skills
- (E43-S4) wire checkpoint writes into 8 Phase 3 Solutioning skills
- (checkpoint) wire write-checkpoint.sh into Phase 2 skills (E43-S3)
- (checkpoint) wire write-checkpoint.sh into Phase 1 skills (E43-S2)
- (checkpoint) add write-checkpoint.sh schema v1 helper (E43-S1)
- (release) automate plugin release on staging-to-main merge

### Changed

- (skills) review-deps runtime-first ordering + tier collapse (E52-S11)
- (skills) perf-testing baseline mandate + CRP techniques (E52-S8)
- (skills) memory-hygiene token recovery + cross-agent matrix (E52-S7)
- (skills) ci-edit cascade targets + failure surfacing (E52-S6)
- (skills) performance-review percentiles + file logging (E52-S5)
- (skills) project-context TRUNCATED marker + inference (E52-S4)
- (skills) document-project manifest entries + counts (E52-S3)
- (skills) changelog version validation + excluded commits (E52-S2)
- (skills) refresh-ground-truth budget check + entry schema (E52-S1)
- (skills) editorial-structure doc-type conventions (E51-S2)
- (skills) document editorial-prose default save behaviour (E51-S1)
- (sprint-state) add wrapper-sync invariant bats test (E38-S6)
- (E29-S7) allowlist V1 checkpoint deletion plan fixture in dead-reference-scan
- (E29-S7) add V1 checkpoint deletion plan + sunset window
- (E45-S8) scrub V1-engine references from ADR-068 fixture for ADR-048 guard
- (E45-S8) pin canonical finalize-checklist.sh contract in ADR-068
- (E45-S6) add bats wall-clock budget-watch invariant
- (E44-S2) implement Val auto-fix loop pattern (ADR-058)
- (E44-S1) formalize /gaia-val-validate upstream integration contract
- (E38-S8) add direct unit tests for canonical_states_hint and assert_canonical_state
- (E43-S6) complete NFR-052 public-function coverage signal
- (E43-S7) add NFR-052 coverage signal for resume-discovery.sh public functions
- (bats-tests) bump job timeout from 2m to 5m for growing bats suite
- (E43-S5) consolidate per-skill step-count tests to fit 2-min CI cap
- (checkpoint) declare NFR-052 coverage signal for helper functions
- (checkpoint) harden AC-EC7 PATH isolation for Linux CI
- (changelog) note ADR-056 pivot to PR-based release model

### Fixed

- (skills) scrub legacy core/engine ref from refresh-ground-truth (E52-S1)
- (tests) stabilize flaky TC-VSP-7 perf test (E34-S3) (#290)
- (skills) align tech-research artifact_type slug with filename (E44-S11) (#288)
- (E46-S8) rename contract heading to avoid Step-N count inflation
- (E46-S6) keep gaia-create-arch checkpoint count at 13 (sub-steps no-emit)
- (E45-S7) replace BSD/mawk-incompatible awk word boundaries with portable form
- (E44-S8) skip test-plan.md row checks when project-root is unavailable
- (E45-S2) seed brainstorm fixture in audit and cluster-4 e2e harnesses
- (E41-S1) mark yolo-lint internal helpers private
- (E44-S7) mark detect-open-questions internal helpers private
- (E38-S8) sprint-state transition emits canonical enum hint and guards writers
- (E38-S7) tighten sprint-state reconcile glob to require story frontmatter
- (E42-S14) scrub legacy-engine path refs from finalize.sh comments
- (E42-S13) make finalize.sh opt-in and tests self-contained
- (checkpoint) scrub workflow.xml reference from write-checkpoint.sh header

## [1.128.0] — 2026-04-23

### Added

- (release) pivot release.yml to PR model + ADR-056 (E40-S1)

## [1.127.2] — 2026-04-23

### Added

- Release automation pipeline (E40-S1 / ADR-056). The first automated release will land in v1.128.0.

### Changed

- **ADR-056 amendment (2026-04-23):** `release.yml` pivoted from direct-bot-push to a PR-based model. Branch protection on `main` requires PR + status checks, which the original direct-push design could not satisfy. The workflow now has two modes — `prepare` (opens a `release/vX.Y.Z` PR on qualifying commits to main) and `publish` (cuts tag + GitHub Release when the release PR merges). Manual work per release: one click to merge the release PR.

Initial changelog seeded by E40-S1. Prior history available via `git log --oneline -- plugins/gaia/`.
