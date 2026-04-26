---
date: 2026-04-25
status: PASS
checks_passed: "8/8"
critical_blockers: 0
contradictions_found: 0
contradictions_blocking: 0
traceability_complete: true
test_plan_exists: true
ci_gates_enforced: true
---

# Readiness Report — Self-Contradiction Fixture

> Fixture for VCP-RC-02 / AC3. Pre-assembled report seeded with a single
> traceability self-contradiction: §6 claims FR-1 is "fully traced" while
> §7 claims FR-1 has "no test coverage". Step 10's inline self-contradiction
> sweep MUST detect the conflict, list both anchors, and downgrade the gate
> from PASS.

## Completeness

- All upstream artifacts exist.

## Consistency

- Stories trace to PRD requirements.

## 6. Traceability Coverage

- FR-1 — fully traced to VCP-FOO-01 and VCP-FOO-02.
- FR-2 — fully traced to VCP-FOO-03.

## 7. Test Coverage Gaps

- FR-1 — no test coverage detected for the high-risk acceptance criterion.
- FR-3 — no test coverage detected.

## Output Verification

- Frontmatter present.
- Section headings present.
