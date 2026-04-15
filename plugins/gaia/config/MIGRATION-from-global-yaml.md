# Migration — `_gaia/_config/global.yaml` → `project-config.yaml`

**Story:** E28-S18
**ADR:** ADR-044 (Config Split)
**Status:** Active — split in progress, legacy `global.yaml` remains in place until Cluster 18 cleanup.

This document enumerates every field currently declared in `_gaia/_config/global.yaml` and assigns each a migration disposition:

- **moved-to-project-config** — relocates to `gaia-public/plugins/gaia/config/project-config.yaml`. Per-project.
- **stays-in-global** — remains in `_gaia/_config/global.yaml` as a framework-wide default or user-scoped setting.
- **deprecated** — no longer used by GAIA Native; scheduled for removal in the Cluster 18 cleanup pass.

The legacy `_gaia/_config/global.yaml` is NOT modified or deleted by E28-S18. Deletion is scheduled for Cluster 18 after all consumers are migrated.

## Field disposition table

| # | Field | Disposition | Rationale |
|---|-------|-------------|-----------|
| 1 | `framework_name` | stays-in-global | Framework identity — constant across all projects. |
| 2 | `framework_version` | moved-to-project-config | Projects pin the framework version they target. |
| 3 | `user_name` | stays-in-global | User-scoped — not a project setting. |
| 4 | `communication_language` | stays-in-global | User preference — not a project setting. |
| 5 | `document_output_language` | stays-in-global | User preference — not a project setting. |
| 6 | `user_skill_level` | stays-in-global | User preference — not a project setting. |
| 7 | `project_name` | deprecated | Redundant with directory name; no consumer in GAIA Native. |
| 8 | `project_root` | moved-to-project-config | Per-project absolute path to the framework root. |
| 9 | `project_path` | moved-to-project-config | Core per-project setting per ADR-044. |
| 10 | `output_folder` | deprecated | Replaced by per-artifact paths; no GAIA Native consumer. |
| 11 | `planning_artifacts` | deprecated | Canonical path `{project-root}/docs/planning-artifacts` is hard-wired in GAIA Native; override was never used. |
| 12 | `implementation_artifacts` | deprecated | Same as above — canonical path is hard-wired. |
| 13 | `test_artifacts` | deprecated | Same as above. |
| 14 | `creative_artifacts` | deprecated | Same as above. |
| 15 | `sizing_map` | stays-in-global | Framework-wide Fibonacci sizing map — shared by all projects. |
| 16 | `problem_solving` | stays-in-global | Framework-wide knob (context budget); not per-project. |
| 17 | `installed_path` | moved-to-project-config | Per-project absolute path to `_gaia/`. |
| 18 | `config_path` | deprecated | Derivable from `installed_path`; no explicit consumer. |
| 19 | `memory_path` | moved-to-project-config | Per-project absolute path to `_memory/`. |
| 20 | `checkpoint_path` | moved-to-project-config | Per-project absolute path to checkpoint directory. |
| 21 | `val_integration` | moved-to-project-config | Per-project Val agent knobs (ADR-042). |
| 22 | `ci_cd` | moved-to-project-config | Per-project CI/CD promotion chain (ADR-048). |

## Fields new to `project-config.yaml` (no predecessor in `global.yaml`)

| Field | Rationale |
|-------|-----------|
| `date` | ISO-8601 revision stamp — enforced for audit by resolve-config.sh. |
| `testing` | Testing integration config (framework, bridge, coverage) — new in GAIA Native per feature brief P2-S10. |

## Disposition summary

- **moved-to-project-config:** 9 fields
- **stays-in-global:** 6 fields
- **deprecated:** 7 fields
- **new (no predecessor):** 2 fields

Total legacy fields accounted for: 22 (every top-level key currently in `_gaia/_config/global.yaml`).

## Schema enforcement

`resolve-config.sh` reads `project-config.schema.yaml` and rejects any key in `project-config.yaml` not declared in the schema with exit code 2. This is the AC5 contract and the hard guarantee that the split is clean — legacy fields cannot silently leak into the new surface.
