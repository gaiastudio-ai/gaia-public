# Cluster 7 Chain Integration Test Fixture

Test fixture for the Cluster 7 Story Cluster chain integration test (E28-S59).

## Initial State

- **Story key:** E99-S1
- **Story status:** backlog
- **Sprint ID:** sprint-test
- **Sprint status:** E99-S1 seeded in backlog

## Expected State Transitions

The full chain exercises this canonical state machine path:

```
backlog -> validating -> ready-for-dev -> in-progress -> review -> done
```

## Files

| File | Purpose |
|------|---------|
| `config/project-config.yaml` | Resolve-config fixture (all paths via GAIA_* env vars) |
| `epics-and-stories.md` | Seeded epic and story for create-story prereq gate |
| `architecture.md` | Minimal architecture stub |
| `sprint-status.yaml` | Initial sprint status with E99-S1 in backlog |

## Chain Skills (in order)

1. `gaia-create-story` — Creates the story file from epics-and-stories.md
2. `gaia-dev-story` — Implements the story (TDD red/green/refactor, PR, CI, merge). Primary skill for PostToolUse checkpoint hook testing.
3. `gaia-validate-story` — Validates the completed story
4. `gaia-check-dod` — Verifies Definition of Done

## Usage

The fixture is consumed by `tests/e2e/cluster-7-chain.bats` and
`tests/e2e/generate-cluster-7-report.sh`. Each test run copies the fixture
into an isolated temp directory so the source fixture is never modified.
