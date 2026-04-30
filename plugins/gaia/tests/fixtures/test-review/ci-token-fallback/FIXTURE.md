# Fixture: ci-token-fallback

Test-review review-skill bats fixture (E65-S6). The directory is reserved for the
inputs and expected-output anchor files used by the per-EC bats assertions
documented in story E65-S6 Task 10.

EC-14 — missing GITHUB_TOKEN; bats asserts fallback to annotation-only flakiness signal.

This anchor is intentionally minimal — the structural migration in E65-S6 only
requires the directory layout to exist; the per-EC executable bats tests that
consume these fixtures land in the follow-up automation pass alongside the
inline analyzer implementation. See the Findings table in the story file for
the deferred work.
