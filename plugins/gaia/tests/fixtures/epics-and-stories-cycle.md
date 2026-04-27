# Epics and Stories

> Negative fixture — introduces a circular dependency E1-S1 → E1-S2 → E1-S1
> so VCP-CHK-20 asserts that finalize.sh catches the cycle and names the
> V1 anchor "No circular dependencies" in its violation output.

Mode: Greenfield

## Epic 1: Checkout Revamp

**Goal:** Rebuild the checkout flow.
**Success criteria:** FR-101 / FR-102 satisfied.

### Story E1-S1: Guest checkout form
- Epic: Checkout Revamp
- Priority: P0
- Size: M
- Risk: high
- Depends on: E1-S2
- Blocks: none
- Traces to: FR-101
- Acceptance Criteria:
  - AC1: Guest can submit shipping address.

As a guest shopper, I want to check out without creating an account so that
I can complete my purchase faster.

Dev Notes: Risk: HIGH — run /gaia-atdd before /gaia-dev-story.

### Story E1-S2: Express pay
- Epic: Checkout Revamp
- Priority: P0
- Size: L
- Risk: high
- Depends on: E1-S1
- Blocks: none
- Traces to: FR-102
- Acceptance Criteria:
  - AC1: Express-pay completes in under 800 ms p95.

As a shopper, I want to pay with Apple Pay or Google Pay so that I can
check out in one tap.

Dev Notes: Risk: HIGH — run /gaia-atdd before /gaia-dev-story.
