# Cluster 5 Parity Test Fixture

Frozen test inputs for the Cluster 5 planning skill parity test (E28-S44).

## Layout

```
fixture/
  config/project-config.yaml   — GAIA config overrides for deterministic resolution
  product-brief.md              — Seed product brief (input to create-prd)
  prd.md                        — Seed PRD (input to edit-prd, validate-prd)
  ux-design.md                  — Seed UX design (input to edit-ux)
```

## Intent

These files provide the minimum deterministic inputs that each of the five
Cluster 5 planning skills requires to execute. The fixture is treated as
frozen test data — do not modify it unless the skill contracts change.

## Skills Exercised

| Skill              | Input(s) Used                |
|--------------------|------------------------------|
| gaia-create-prd    | product-brief.md             |
| gaia-edit-prd      | prd.md                       |
| gaia-validate-prd  | prd.md                       |
| gaia-create-ux     | product-brief.md, prd.md     |
| gaia-edit-ux       | ux-design.md                 |

## Rules

- No network fetches — all inputs are local files
- No ambient date — the config file pins `date: "2026-04-15"`
- No absolute paths — all paths resolve via `GAIA_*` env overrides
