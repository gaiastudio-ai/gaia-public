# GAIA Plugin — bats-core Unit Test Suite (E28-S17)

This directory contains the bats-core unit test suite for every foundation
script in `plugins/gaia/scripts/`. It is the binding NFR-052 enforcement
point — 100% of documented public functions in every foundation script are
covered by at least one bats test.

## Running the suite

```bash
# Full suite
bats plugins/gaia/tests/

# Single file
bats plugins/gaia/tests/resolve-config.bats

# With filter
BATS_TEST_FILTER="happy path" bats plugins/gaia/tests/resolve-config.bats
```

## Coverage wrapper

```bash
bash plugins/gaia/tests/run-with-coverage.sh
```

The wrapper:

1. Enumerates public functions from every `plugins/gaia/scripts/*.sh`.
2. Runs the bats suite.
3. Asserts every public function is referenced from at least one `.bats`
   file (the NFR-052 binding gate). Uncovered public functions fail the
   wrapper with exit 1 and are named in stderr.
4. If `kcov` is available on PATH, produces an advisory HTML + JSON line
   coverage report under `coverage/kcov/`. kcov is advisory only — the
   binding gate is public-function coverage.

Outputs:

- `coverage/public-functions.json` — enumerated public functions per script.
- `coverage/coverage-summary.json` — per-script covered / uncovered lists
  plus the NFR-052 gate verdict.
- `coverage/kcov/index.html` — advisory line coverage (if kcov is present).

## Test isolation rules

- Every `.bats` file sources `test_helper.bash` and calls `common_setup` /
  `common_teardown` to namespace a per-test temp dir under `$BATS_TMPDIR`.
- Tests never write to the working tree or any shared global path.
- `LC_ALL=C` and `TZ=UTC` are pinned for deterministic output.
- Fixtures are generated inside `setup()` — never checked in as binary
  blobs that could drift silently.

## CI integration

The `bats-tests` job in `.github/workflows/plugin-ci.yml` runs
`plugins/gaia/tests/run-with-coverage.sh`, enforces the 2-minute budget via
a job-level `timeout-minutes: 2`, uploads the `coverage/` directory as an
artifact, and fails the PR if the NFR-052 gate is not green.
