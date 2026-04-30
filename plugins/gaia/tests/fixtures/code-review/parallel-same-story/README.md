# Fixture: parallel-same-story (EC-5)

Covers same-story parallel-invocation safety: two simultaneous `/gaia-code-review {story}` invocations on the same story key. The cache write path uses a per-PID temp file plus atomic rename, so last-writer-wins without corruption. `mkdir -p` for the cache directory is idempotent and concurrency-safe.

The bats assertion for this case is structural — `gaia-code-review.bats` AC-EC5 verifies the SKILL.md prescribes the per-PID temp + atomic rename pattern. Live concurrent execution is exercised in CI integration tests.

## Expected

- No `analysis-results.json` corruption when two invocations race.
- `.cache/` directory created by either invocation; `mkdir -p` does not error.
- Final `.cache/{cache_key}.json` reflects the last successful writer (atomic rename).
