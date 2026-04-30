# Fixture: end-to-end-real-story

Test-review review-skill bats fixture (E65-S6). The directory is reserved for the
inputs and expected-output anchor files used by the per-EC bats assertions
documented in story E65-S6 Task 10.

AC5 — verifies test-review-E<NN>-S<NNN>.md persists at FR-402 path; allowlist scan asserts read-only fork.

This anchor is intentionally minimal — the structural migration in E65-S6 only
requires the directory layout to exist; the per-EC executable bats tests that
consume these fixtures land in the follow-up automation pass alongside the
inline analyzer implementation. See the Findings table in the story file for
the deferred work.
