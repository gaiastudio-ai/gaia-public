# test-automate fixtures

Minimal fixtures for E35-S1 Phase 1 fork-context tests.

- `minimal-source.sh` — trivial shell source for SHA-256 analysis
- `malformed-story.md` — story with no parseable ACs (AC-EC8 coverage)
- `binary-fixture.bin` — non-UTF-8 binary content (AC-EC5 coverage, created at test runtime)

Large file fixtures (AC-EC4) are created ephemerally in `setup()` via
`dd` and cleaned in `teardown()` — never committed.
