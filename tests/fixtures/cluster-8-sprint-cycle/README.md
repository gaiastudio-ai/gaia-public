# Cluster 8 Sprint-Cycle Integration Test Fixture

Deterministic fixture for the E28-S65 sprint-cycle chain integration test.

## Layout

```
cluster-8-sprint-cycle/
  sprint-status.yaml           # Seed state: 2 epics, 4 stories
  epics-and-stories.md         # Matching epics/stories excerpt
  architecture.md              # Minimal stub
  config/project-config.yaml   # Config resolved via env overrides
  stories/                     # Fixture story files (source of truth)
    E80-S1-login-page-redesign.md
    E80-S2-api-rate-limiting.md
    E81-S1-dashboard-metrics-widget.md
    E81-S2-export-to-csv.md
  expected/                    # Per-hop expected sprint-status.yaml snapshots
    after-plan.yaml
    after-status.yaml
    after-correct-course.yaml
    after-retro.yaml
```

## Chain Under Test

1. **sprint-plan** -- reads epics/stories, produces a sprint plan (no state mutation)
2. **sprint-status** -- reads sprint-status.yaml, renders dashboard (no state mutation)
3. **correct-course** -- reads sprint data, recommends scope changes (no state mutation)
4. **retro** -- reads sprint data, produces retrospective (no state mutation)

None of the four Cluster 8 skills mutate sprint-status.yaml directly. The
`sprint-state.sh` script is the only sanctioned writer (ADR-042, ADR-048).

## Regenerating Expected Snapshots

If the sprint-state.sh contract or Cluster 8 skill behavior changes:

1. Manually run each hop against a fresh copy of the seed fixture
2. Capture the resulting sprint-status.yaml after each hop
3. Strip comment headers and replace expected/ files
4. Run `bats tests/e2e/cluster-8-sprint-cycle.bats` to validate
