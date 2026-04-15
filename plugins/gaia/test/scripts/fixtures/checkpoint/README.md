# checkpoint.sh fixtures

Fixture checkpoint files for `plugins/gaia/scripts/checkpoint.sh` (E28-S10). These
are consumed by the pure-bash smoke tests in `../test_checkpoint.sh` and will be
consumed by the bats-core unit tests landing in E28-S17.

- `sample-clean.yaml` — minimal checkpoint with one tracked file and variables.
- `sample-empty.yaml` — checkpoint with no variables and empty `files_touched`.

The canonical schema (field order is stable and part of the contract):

```yaml
workflow: <string>
step: <int>
timestamp: <ISO 8601 UTC, second precision>
variables:        # or `variables: {}` when empty
  <key>: <val>
files_touched:    # or `files_touched: []` when empty
  - path: <string>
    sha256: "sha256:<hex>"
    last_modified: <ISO 8601 UTC>
```
