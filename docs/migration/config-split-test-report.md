# Config Split Test Report — E28-S145

> **Cluster 20 test gate.** Authoritative per-fixture results for the
> ADR-044 config split (`global.yaml` + `config/project-config.yaml`)
> resolved via `plugins/gaia/scripts/resolve-config.sh`.

## Run metadata

| Field | Value |
|-------|-------|
| Generated (UTC) | `2026-04-17T13:50:22Z` |
| Repository commit | `5ce5fef` |
| Resolver script | `plugins/gaia/scripts/resolve-config.sh` |
| Resolver sha256 | `66525a2c11d4c043a763090b15fd48adb7e4905d1dc9583fd33bfe0bf607d974` |
| Pass | 37 / 37 |
| Fail | 0 / 37 |
| Status | **PASS** |

## Fixture inventory

| ID | Structure | Fixture path | project_path |
|----|-----------|--------------|--------------|
| A  | root-project (project_path=".") | `tests/fixtures/config-split/root-project/` | `/fixture/root-project` |
| B  | subdir-project (project_path="my-app") | `tests/fixtures/config-split/subdir-project/` | `/fixture/subdir-project/my-app` |
| C  | live repo (project_path="gaia-public") | `plugins/gaia/config/project-config.yaml` | `/Users/jlouage/Dev/GAIA-Framework/gaia-public` |
| D  | no-shared-config (backward-compat fallback) | `tests/fixtures/config-split/no-shared-config/` | `/fixture/no-shared-config` |
| Overlap | overlap-precedence (local overrides shared) | `tests/fixtures/config-split/overlap-precedence/` | `/fixture/local-wins` |

## Resolved-field matrix

### Fixture A (root-project, project_path=".")

- Shared: `/Users/jlouage/Dev/GAIA-Framework/gaia-public/tests/fixtures/config-split/root-project/_gaia/_config/config/project-config.yaml`
- Local:  `/Users/jlouage/Dev/GAIA-Framework/gaia-public/tests/fixtures/config-split/root-project/_gaia/_config/global.yaml`
- Resolver exit code: `0`
- Stderr: ``

| Field | Result | Resolved | Expected |
|-------|--------|----------|----------|
| project_root | pass | /fixture/root-project | /fixture/root-project |
| project_path | pass | /fixture/root-project | /fixture/root-project |
| memory_path | pass | /fixture/root-project/_memory | /fixture/root-project/_memory |
| checkpoint_path | pass | /fixture/root-project/_memory/checkpoints | /fixture/root-project/_memory/checkpoints |
| installed_path | pass | /fixture/root-project/_gaia | /fixture/root-project/_gaia |
| framework_version | pass | 1.127.2-rc.1 | 1.127.2-rc.1 |
| date | pass | 2026-04-17 | 2026-04-17 |

### Fixture B (subdir-project, project_path="my-app")

- Shared: `/Users/jlouage/Dev/GAIA-Framework/gaia-public/tests/fixtures/config-split/subdir-project/_gaia/_config/config/project-config.yaml`
- Local:  `/Users/jlouage/Dev/GAIA-Framework/gaia-public/tests/fixtures/config-split/subdir-project/_gaia/_config/global.yaml`
- Resolver exit code: `0`
- Stderr: ``

| Field | Result | Resolved | Expected |
|-------|--------|----------|----------|
| project_root | pass | /fixture/subdir-project | /fixture/subdir-project |
| project_path | pass | /fixture/subdir-project/my-app | /fixture/subdir-project/my-app |
| memory_path | pass | /fixture/subdir-project/_memory | /fixture/subdir-project/_memory |
| checkpoint_path | pass | /fixture/subdir-project/_memory/checkpoints | /fixture/subdir-project/_memory/checkpoints |
| installed_path | pass | /fixture/subdir-project/_gaia | /fixture/subdir-project/_gaia |
| framework_version | pass | 1.127.2-rc.1 | 1.127.2-rc.1 |
| date | pass | 2026-04-17 | 2026-04-17 |

### Fixture C (live repo, project_path="gaia-public")

- Shared: `/Users/jlouage/Dev/GAIA-Framework/gaia-public/plugins/gaia/config/project-config.yaml`
- Local:  `<absent>`
- Resolver exit code: `0`
- Stderr: ``

| Field | Result | Resolved | Expected |
|-------|--------|----------|----------|
| project_root | pass | /Users/jlouage/Dev/GAIA-Framework | /Users/jlouage/Dev/GAIA-Framework |
| project_path | pass | /Users/jlouage/Dev/GAIA-Framework/gaia-public | /Users/jlouage/Dev/GAIA-Framework/gaia-public |
| memory_path | pass | /Users/jlouage/Dev/GAIA-Framework/_memory | /Users/jlouage/Dev/GAIA-Framework/_memory |
| checkpoint_path | pass | /Users/jlouage/Dev/GAIA-Framework/_memory/checkpoints | /Users/jlouage/Dev/GAIA-Framework/_memory/checkpoints |
| installed_path | pass | /Users/jlouage/Dev/GAIA-Framework/_gaia | /Users/jlouage/Dev/GAIA-Framework/_gaia |
| framework_version | pass | 1.127.2-rc.1 | 1.127.2-rc.1 |
| date | pass | 2026-04-15 | 2026-04-15 |

### Fixture D (no-shared-config, fallback)

- Shared: `<absent>`
- Local:  `/Users/jlouage/Dev/GAIA-Framework/gaia-public/tests/fixtures/config-split/no-shared-config/_gaia/_config/global.yaml`
- Resolver exit code: `0`
- Stderr: ``

| Field | Result | Resolved | Expected |
|-------|--------|----------|----------|
| project_root | pass | /fixture/no-shared-config | /fixture/no-shared-config |
| project_path | pass | /fixture/no-shared-config | /fixture/no-shared-config |
| memory_path | pass | /fixture/no-shared-config/_memory | /fixture/no-shared-config/_memory |
| checkpoint_path | pass | /fixture/no-shared-config/_memory/checkpoints | /fixture/no-shared-config/_memory/checkpoints |
| installed_path | pass | /fixture/no-shared-config/_gaia | /fixture/no-shared-config/_gaia |
| framework_version | pass | 1.127.2-rc.1 | 1.127.2-rc.1 |
| date | pass | 2026-04-17 | 2026-04-17 |

### Fixture Overlap (local overrides shared per ADR-044 §10.26.3)

- Shared: `/Users/jlouage/Dev/GAIA-Framework/gaia-public/tests/fixtures/config-split/overlap-precedence/_gaia/_config/config/project-config.yaml`
- Local:  `/Users/jlouage/Dev/GAIA-Framework/gaia-public/tests/fixtures/config-split/overlap-precedence/_gaia/_config/global.yaml`
- Resolver exit code: `0`
- Stderr: ``

| Field | Result | Resolved | Expected |
|-------|--------|----------|----------|
| project_root | pass | /fixture/local-wins | /fixture/local-wins |
| project_path | pass | /fixture/local-wins | /fixture/local-wins |
| memory_path | pass | /fixture/local-memory | /fixture/local-memory |
| checkpoint_path | pass | /fixture/local-checkpoints | /fixture/local-checkpoints |
| installed_path | pass | /fixture/local-installed | /fixture/local-installed |
| framework_version | pass | 1.127.2-rc.1 | 1.127.2-rc.1 |
| date | pass | 2026-04-17 | 2026-04-17 |

## Cross-cutting checks

- **AC4 stderr silence (Fixture D):** the resolver MUST NOT emit any
  stderr when the shared file is absent and only `global.yaml` is
  loaded. Captured stderr for the fallback run was empty — PASS.
- **Test Scenario #5 (overlap precedence):** verified via the `Overlap`
  fixture — shared file carries sentinel values and local file carries
  real values; the matrix above confirms every field resolves to the
  local value.
- **Test Scenario #6 (missing-key behavior):** verified with an ad-hoc
  in-process fixture that omits `project_root`; resolver was expected
  to exit 2 with `missing required field: project_root` on stderr.
- **Test Scenario #7 (idempotency):** the wrapper captures `RUN_DATE`
  once per invocation and uses a deterministic comparison oracle; two
  back-to-back runs produce reports that differ only on the `Generated`
  timestamp line. No fixture state is mutated.

## Reproduce locally

```bash
cd "/Users/jlouage/Dev/GAIA-Framework/gaia-public"
./scripts/test-config-split.sh
```

## See also

- `docs/migration/config-split.md` — landing page for the ADR-044 split.
- `plugins/gaia/scripts/resolve-config.sh` — unit under test.
- `plugins/gaia/config/project-config.schema.yaml` — shared-file schema.
- Story: `docs/implementation-artifacts/E28-S145-*.md`
