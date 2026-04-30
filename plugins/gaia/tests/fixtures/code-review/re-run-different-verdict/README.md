# Fixture: re-run-different-verdict (EC-8)

Covers the re-run-with-different-verdict overwrite case: first run produces verdict=PASSED, second run produces verdict=FAILED — the parent overwrites the existing review file (no append, no version-suffix). The bats coverage for this case is structural (SKILL.md prescribes overwrite semantics) and is exercised by the `AC-EC8` SKILL.md regex assertion in `gaia-code-review.bats`. Live overwrite behavior is exercised end-to-end in CI integration tests.

## Inputs

- `first-run/analysis-results.json` — passing run (status=passed across all checks)
- `second-run/analysis-results.json` — failing run (status=failed for tsc with blocking finding)

## Expected

- Parent writes to `docs/implementation-artifacts/code-review-E<NN>-S<NNN>.md` on first run with verdict=APPROVE.
- Parent OVERWRITES the same path on second run with verdict=REQUEST_CHANGES.
- review-gate.sh row reflects latest verdict only (FAILED).
