# Config Split Migration — ADR-044

> Landing page for the ADR-044 config split: local (`global.yaml`) vs. team-shared (`config/project-config.yaml`).
>
> **ADR:** ADR-044
> **Architecture:** `architecture.md` §10.26.3 (Foundation Scripts), §10.26.6 (Config Split Diagram)
> **Cluster 20 stories:** E28-S141 (schema), E28-S142 (resolver merge), E28-S143 (migration script), **E28-S144 (skill migration)**, E28-S145 (variation tests)

## What changed

Before ADR-044, every consumer (skills, foundation scripts, workflows) read `global.yaml` directly. After ADR-044, configuration is split across two files:

- **`config/project-config.yaml`** — team-shared settings committed to the repo (sizing map, CI config templates, framework version, etc.).
- **`global.yaml`** — machine-local overrides that stay out of git (local project paths, memory paths, env-specific flags).

The `scripts/resolve-config.sh` foundation script merges the two with strict precedence: **env > local > shared**. Consumers call the resolver instead of reading either file, and the split becomes transparent.

## How skills consume config (E28-S144)

Every SKILL.md that needs a config value invokes the resolver via the canonical form:

```bash
!scripts/resolve-config.sh {key}
```

Multiple keys can be fetched in one call by consuming the full `KEY='VALUE'` shell output:

```bash
eval "$(!scripts/resolve-config.sh --format shell)"
echo "$project_path $sizing_map"
```

JSON output is available for skills that need structured parsing:

```bash
!scripts/resolve-config.sh --format json | jq .sizing_map
```

### Skills migrated to resolve-config.sh

| Skill | Config keys resolved |
|-------|----------------------|
| `gaia-sprint-plan` | `sizing_map` |
| `gaia-rollback-plan` | Full config via `--format shell` (deployment + CI) |
| `gaia-deploy-checklist` | `ci_cd.promotion_chain` |
| `gaia-val-validate-plan` | `framework_version` |
| `gaia-validation-patterns` | `project_path` (documentation reference) |

### Skills exempt from the read indirection

Three skill families still reference `global.yaml` directly because they act ON the file rather than READ from it. They are allowlisted in `scripts/verify-no-direct-config-reads.sh`:

- **Config editors** — `gaia-bridge-toggle`, `gaia-bridge-enable`, `gaia-bridge-disable`, `gaia-ci-setup`, `gaia-ci-edit`. These edit `global.yaml` in place, preserving comments and field order. A read-only resolver cannot round-trip YAML with comments, so these must write to the file directly.
- **Meta-validator** — `gaia-validate-framework`. Its job is to verify that `global.yaml` and each module `config.yaml` parse end-to-end; routing it through the resolver would defeat the validation.

Adding a new skill to the allowlist requires a rationale comment in `scripts/verify-no-direct-config-reads.sh` and a CI review pass.

## CI invariant (E28-S144 Task 3 / Task 5)

The CI pipeline runs `scripts/verify-no-direct-config-reads.sh plugins/gaia/skills` on every PR. The script:

1. Scans every `SKILL.md` under the skills tree.
2. Strips single-line HTML comments before grepping.
3. Skips skills in the allowlist.
4. Exits **1** on any direct reference to `global.yaml` or `project-config.yaml` outside the allowlist and outside of comments.

Any PR that introduces a new direct config read without either (a) routing through the resolver or (b) adding the skill to the allowlist with rationale will fail CI.

For ad-hoc inspection, the rerunnable audit lives at `scripts/audit-skill-config-reads.sh` and emits the raw `file:line:text` match list.

## Behavioral parity

The E28-S144 migration is a pure indirection change — the resolver returns the same values the direct reads produced, because (a) the split preserves key names 1:1 (ADR-044 key-rename prohibition), and (b) the resolver applies the "local overrides shared" precedence so pre-split unified `global.yaml` behavior is preserved when only one layer is present.

The per-skill parity table lives in `docs/migration/config-split-skill-audit.md`.

## Testing

The Cluster 20 test gate lives at `scripts/test-config-split.sh` (E28-S145). It drives `plugins/gaia/scripts/resolve-config.sh` across four project-structure fixtures plus an overlap-precedence fixture and a missing-key behavior check:

| Fixture | `project_path` | Exercises |
|---------|----------------|-----------|
| A — root-project | `/fixture/root-project` | Baseline split with `project_path: "."` semantics |
| B — subdir-project | `/fixture/subdir-project/my-app` | Application tree under a subdirectory |
| C — live repo | `$(pwd)/gaia-public` | Production path — zero drift against the pre-split oracle |
| D — no-shared-config | `/fixture/no-shared-config` | Backward-compat fallback — resolver silent, exit 0, `global.yaml` wins unchanged |
| Overlap | `/fixture/local-wins` | "Local overrides shared" per ADR-044 §10.26.3 — sentinel shared values are observably ignored |

The wrapper writes the authoritative test report to `docs/migration/config-split-test-report.md` on every run. The wrapper is shellcheck-clean, idempotent (two back-to-back runs diff only on the `Generated` timestamp), and exits non-zero on any fixture failure so CI can gate on it.

Run locally:

```bash
cd gaia-public
./scripts/test-config-split.sh
```

- `docs/migration/config-split-test-report.md` — authoritative per-fixture results (regenerated on every wrapper run).

## See also

- `docs/migration/config-split-skill-audit.md` — authoritative scope artifact for the skill migration.
- `plugins/gaia/config/MIGRATION-from-global-yaml.md` — migration playbook for splitting an existing `global.yaml`.
- `plugins/gaia/scripts/resolve-config.sh` — canonical resolver implementation.
- `scripts/test-config-split.sh` — Cluster 20 test gate (E28-S145).
- `architecture.md` §10.26.3, §10.26.6, ADR-044.
