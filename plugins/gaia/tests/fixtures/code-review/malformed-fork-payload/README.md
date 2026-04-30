# Fixture: malformed-fork-payload (EC-9)

Covers the malformed fork output case: fork returns a report missing the `**Verdict:**` final line OR missing one of the required top-level sections (`## Deterministic Analysis`, `## LLM Semantic Review`). The parent context validates the payload before persisting; on malformed input it persists what it received with an `[INCOMPLETE]` marker prepended and emits verdict=BLOCKED via `review-gate.sh`.

## Files

- `report-missing-verdict.md` — synthetic fork output with both sections present but missing the verdict line at the bottom.
- `report-missing-section.md` — synthetic fork output with the verdict line present but missing `## LLM Semantic Review`.

## Expected

For each malformed fixture:
- Parent persists the file with `[INCOMPLETE]` marker prepended.
- `review-gate.sh` row updated to FAILED (BLOCKED → FAILED mapping).
- Bats coverage is structural in `gaia-code-review.bats` AC-EC9 (SKILL.md prescribes the validation + INCOMPLETE marker contract).
