# Fixture: malformed-ac

QA-tests review-skill bats fixture (E65-S4). The directory is reserved for the
inputs and expected-output anchor files used by the per-EC bats assertions
documented in story E65-S4 Task 10.

This anchor is intentionally minimal — the structural migration in E65-S4 only
requires the directory layout to exist; the per-EC executable bats tests that
consume these fixtures land in the follow-up automation pass alongside the
inline analyzer implementation. See the Findings table in the story file for
the deferred work.
