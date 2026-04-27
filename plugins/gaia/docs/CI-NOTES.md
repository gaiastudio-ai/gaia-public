# CI Notes — bats Wall-Clock Budget

> **Why this file exists.** The `bats-tests` job in `plugin-ci.yml` is the
> framework's primary integration gate. Wall-clock has crept from ~150 s
> (sprint-23, ~1300 tests) to ~270 s (sprint-28, 2085 tests) — see
> `docs/planning-artifacts/E45-S6-adr-memo-bats-scaling.md` for the full
> trajectory. This runbook tells contributors how to add new tests
> without pushing the suite into another timeout escalation.

## TL;DR

- **Soft budget:** 240 s (4 min) of bats wall-clock, watched by
  `plugins/gaia/scripts/bats-budget-watch.sh`.
- **Hard budget:** 300 s (5 min) `timeout-minutes` on the `bats-tests` job.
- **Escalation triggers:** see `ADR-062` Appendix B.

## How to add new bats fixtures

1. **Reuse `test_helper.bash`.** Source it from every new `.bats` file
   (`load 'test_helper.bash'`) and use `common_setup` / `common_teardown`.
   That alone saves 50–100 ms per test by avoiding redundant `mktemp`
   and `mkdir -p` calls. Most importantly, never `cd` into the working
   tree — write everything under `$BATS_TEST_TMPDIR`.
2. **Prefer pure-shell assertions over subprocess calls.** Each
   `bash -c` or `git` invocation costs 5–20 ms. A `@test` that runs 10
   of them costs you 100 ms; 50 such tests cost 5 s. Use bash builtins
   (`[[ ... ]]`, `printf`, parameter expansion) where possible.
3. **Avoid `apt-get` and other network calls inside `@test` blocks.**
   Anything network-touching belongs in the workflow's `Install <foo>`
   step or behind a `skip "not in CI"` guard.
4. **Don't `sleep`.** A `sleep 1` in 30 tests is 30 s of pure dead
   time. If you need to test timing-sensitive logic, mock the clock or
   use a much smaller increment (`sleep 0.05`).
5. **Co-locate cluster tests under `tests/cluster-N/`** when the test
   targets a specific skill cluster. The cluster-{4,5,6,7,8,9} jobs
   pick those up directly and run them in their own 5-minute budget,
   keeping the main `bats-tests` job lean.

## How to interpret the budget warning

When the bats-tests step runs longer than 240 s, the GitHub Actions step
summary will include a yellow warning block:

```
> [!WARNING]
> bats budget exceeded — bats-tests
>
> - threshold: 240s
> - elapsed: 248s
> - over by: 8s
>
> The bats CI step is approaching its wall-clock budget. ...
```

This is **advisory only** — the build still passes. It means:

- If your PR added new tests: consider whether the additions truly
  belong in the foundation suite or whether they should live under a
  cluster-specific path with its own job.
- If your PR didn't add tests: the warning is a leading indicator that
  the suite is drifting toward the hard wall. Flag in the PR
  description so the next planner sees it.

## When to escalate

Open a sprint-29-or-later story (or extend `ADR-062`) when **any** of
these fire:

- The warning posts on >25 % of staging-bound PRs in a sprint.
- A single PR's bats wall-clock exceeds 270 s (90 % of the hard wall).
- A second `timeout-minutes` escalation is proposed in any PR review.

The likely next step is parallelisation via `bats --jobs N` — see
`ADR-062` Option A. Don't bump `timeout-minutes` past 5 minutes
without first running the parallelisation prototype.

## Local repro

```bash
# Run the budget-watched bats suite locally — same wrapper as CI.
bash plugins/gaia/scripts/bats-budget-watch.sh \
  --threshold-seconds 240 \
  --label bats-tests \
  -- bash plugins/gaia/tests/run-with-coverage.sh
```

If your local box is slow, drop `--threshold-seconds` to a value that
matches your hardware so you see the warning during development rather
than on the PR.

## Related artifacts

- `docs/planning-artifacts/E45-S6-adr-memo-bats-scaling.md` — ADR-062.
- `gaia-public/.github/workflows/plugin-ci.yml` — the wired-in
  `bats-tests` job (lines around the "Run bats suite with coverage
  wrapper (budget-watched)" step).
- `plugins/gaia/scripts/bats-budget-watch.sh` — the wrapper script.
- `plugins/gaia/tests/e45-s6-bats-budget-watch.bats` — the unit /
  black-box suite for the wrapper.
