# Migration — `_gaia/_config/global.yaml` → `project-config.yaml`

**Stories:** E28-S18 (initial draft), E28-S141 (finalization)
**ADR:** ADR-044 (Config Split)
**Status:** Active — split in progress, legacy `global.yaml` remains in place until Cluster 18 cleanup.

This document enumerates every field currently declared in `_gaia/_config/global.yaml` and assigns each a migration disposition:

- **moved-to-project-config** — relocates to `gaia-public/plugins/gaia/config/project-config.yaml`. Per-project, team-shared, committed to git.
- **stays-in-global** — remains in `_gaia/_config/global.yaml` as a machine-local or user-scoped setting. Gitignored under the new plugin layout.
- **deprecated** — no longer used by GAIA Native; scheduled for removal in the Cluster 18 cleanup pass.

The legacy `_gaia/_config/global.yaml` is NOT modified or deleted by the config-split stories. Deletion is scheduled for Cluster 18 after all consumers are migrated.

## Precedence (ADR-044 invariant)

When the same key appears in both `global.yaml` (local) and `config/project-config.yaml` (shared), the local value wins.

This sentence appears verbatim in `project-config.schema.yaml` — identical wording across both artifacts prevents drift. The rule is enforced by `resolve-config.sh` (E28-S9 / E28-S142) as a generic two-file merge: the resolver reads the shared file first, then overlays the machine-local file. No schema-specific code is required in the resolver.

### Worked example — shared default with local override

A team commits `gaia-public/plugins/gaia/config/project-config.yaml` so every developer on the project inherits the same default `project_path`:

```yaml
# gaia-public/plugins/gaia/config/project-config.yaml (team-shared, committed)
project_path: /srv/ci/gaia-framework/gaia-public
framework_version: 1.127.2-rc.1
date: 2026-04-17
```

An individual operator working on a fork points their local clone at a different tree by setting the same key in their machine-local file:

```yaml
# _gaia/_config/global.yaml (machine-local, gitignored)
project_path: /Users/alex/Dev/gaia-enterprise
```

`resolve-config.sh` reads both files, applies the local-overrides-shared rule, and emits:

```
project_path='/Users/alex/Dev/gaia-enterprise'
framework_version='1.127.2-rc.1'
date='2026-04-17'
```

The shared default (`framework_version`, `date`) passes through unchanged; the overridden key (`project_path`) carries the local value. Teammates who do not override keep the committed shared default.

## Field disposition table

| # | Field | Disposition | Rationale |
|---|-------|-------------|-----------|
| 1 | `framework_name` | stays-in-global | Framework identity — constant across all projects. |
| 2 | `framework_version` | moved-to-project-config | Projects pin the framework version they target. |
| 3 | `user_name` | moved-to-project-config | Team display name is shared per P20-S1; per-operator override stays in machine-local `global.yaml` per the precedence rule. |
| 4 | `communication_language` | moved-to-project-config | Team default is shared per P20-S1; per-operator override stays in machine-local `global.yaml` per the precedence rule. |
| 5 | `document_output_language` | stays-in-global | User preference — varies per operator, not a project setting. |
| 6 | `user_skill_level` | stays-in-global | User preference — varies per operator, not a project setting. |
| 7 | `project_name` | deprecated | Redundant with directory name; no consumer in GAIA Native. |
| 8 | `project_root` | moved-to-project-config | Per-project absolute path to the framework root. Machine-local override via `global.yaml` wins. |
| 9 | `project_path` | moved-to-project-config | Core per-project setting per ADR-044. Machine-local override via `global.yaml` wins. |
| 10 | `output_folder` | deprecated | Replaced by per-artifact paths; no GAIA Native consumer. |
| 11 | `planning_artifacts` | deprecated | Canonical path `{project-root}/docs/planning-artifacts` is hard-wired in GAIA Native; override was never used. |
| 12 | `implementation_artifacts` | deprecated | Same as above — canonical path is hard-wired. |
| 13 | `test_artifacts` | deprecated | Same as above. |
| 14 | `creative_artifacts` | deprecated | Same as above. |
| 15 | `sizing_map` | stays-in-global | Framework-wide Fibonacci sizing map — shared by all projects. |
| 16 | `problem_solving` | stays-in-global | Framework-wide knob (context budget); not per-project. |
| 17 | `installed_path` | stays-in-global | Machine-local absolute path to `_gaia/` — encodes operator filesystem and cannot be meaningfully shared. Declared in schema so CI fixtures can set it deterministically; in practice the machine-local value always wins. |
| 18 | `config_path` | deprecated | Derivable from `installed_path`; no explicit consumer. |
| 19 | `memory_path` | stays-in-global | Machine-local absolute path to `_memory/` — encodes operator filesystem. Declared in schema for fixture determinism; machine-local override wins in practice. |
| 20 | `checkpoint_path` | stays-in-global | Machine-local absolute path to checkpoint directory. Same rationale as `memory_path`. |
| 21 | `val_integration` | moved-to-project-config | Per-project Val agent knobs (ADR-042). |
| 22 | `ci_cd` | moved-to-project-config | Per-project CI/CD promotion chain (ADR-048). |
| 23 | `test_execution_bridge` | moved-to-project-config | Team-wide test bridge enablement (FR-194/FR-197/NFR-034/ADR-028). Same enablement across all teammates so CI and local runs behave identically. |

## Fields new to `project-config.yaml` (no predecessor in `global.yaml`)

| Field | Rationale |
|-------|-----------|
| `date` | ISO-8601 revision stamp — enforced for audit by resolve-config.sh. |
| `testing` | Testing integration config (framework, bridge, coverage) — new in GAIA Native per feature brief P2-S10. |
| `sprint` | Sprint configuration (active sprint, sizing overrides) — shared team config per feature brief P20-S1. |
| `review_gate` | Review Gate configuration — shared team config per feature brief P20-S1. |
| `team_conventions` | Team-wide naming / commit / code-style conventions — shared team config per feature brief P20-S1. |
| `agent_customizations` | Project-wide agent `.customize.yaml` overrides — shared team config per feature brief P20-S1. |

## Disposition summary

- **moved-to-project-config:** 11 fields
- **stays-in-global:** 8 fields
- **deprecated:** 7 fields
- **new (no predecessor):** 6 fields

Total legacy fields accounted for: 23 (every top-level key currently in `_gaia/_config/global.yaml`).

## Schema enforcement

`resolve-config.sh` reads `project-config.schema.yaml` and rejects any key in `project-config.yaml` not declared in the schema with exit code 2. This is the AC5 contract and the hard guarantee that the split is clean — legacy fields cannot silently leak into the new surface.

## Reconciliation with E28-S18

E28-S18 shipped the initial disposition map. E28-S141 finalizes it with three changes:

1. **`user_name` and `communication_language`** moved from stays-in-global to moved-to-project-config per feature brief P20-S1 — both are shared team defaults; per-operator overrides stay in machine-local `global.yaml` under the precedence rule.
2. **`installed_path`, `memory_path`, `checkpoint_path`** re-classified as stays-in-global. E28-S18 marked these moved-to-project-config; in practice they encode the operator's filesystem and always win via the machine-local override. They remain declared in the schema so CI fixtures and test harnesses can set them deterministically, but the committed shared file should not hardcode operator paths.
3. **`test_execution_bridge`** newly enumerated — it was present in `global.yaml` after E28-S18 shipped and required a disposition row to satisfy AC1 (full coverage).

The precedence rule and worked example are net-new in E28-S141 (AC4).
