# VCP-FIX-05 — User chooses "accept as-is"

> Covers AC2 and AC-EC6 of E44-S2. LLM-checkable.

## Setup

Continue from the post-iteration-3 prompt state of VCP-FIX-03. Two sub-cases for the artifact state.

## Sub-case A: artifact already has `## Open Questions`

1. User inputs `a` (or `accept`).
2. Skill appends each unresolved finding under the existing `## Open Questions` section using the row template:
   ```
   - **[{severity}]** {description} — Location: {location}. _Unresolved after 3 Val iterations; accepted by user on {YYYY-MM-DD}._
   ```
3. Skill records `user_decision = accept-as-is` in the most-recent iteration record.
4. Skill proceeds.

### Assertions A

- Existing `## Open Questions` content preserved; new rows appended at the end.
- Each unresolved finding produces exactly one row.
- Checkpoint records the acceptance decision.

## Sub-case B: artifact has NO `## Open Questions` section (AC-EC6)

1. User inputs `a`.
2. Skill **creates** the `## Open Questions` section at the end of the artifact and appends the unresolved findings using the same row template.
3. No silent dropping of findings.

### Assertions B

- Artifact now contains a new `## Open Questions` section.
- All unresolved CRITICAL/WARNING findings appear under it.
- The acceptance decision is recorded in the checkpoint so `/gaia-resume` can surface it.
