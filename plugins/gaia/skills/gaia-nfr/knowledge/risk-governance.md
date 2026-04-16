---
name: risk-governance
tier: extended
version: '1.0'
---

# Risk Governance

## Principle

Risk governance transforms subjective "should we ship?" debates into objective,
data-driven decisions. Score risk as probability (1-3) times impact (1-3) for a total
of 1-9. Scores of 6 or above demand documented mitigation. A score of 9 blocks the
release. Every acceptance criterion maps to a test, and gaps require explicit waivers.

## Rationale

Without formal risk governance, releases become political -- loud voices win, quiet risks
hide, and teams discover critical issues in production. Risk scoring creates shared
language, removes ambiguity, identifies true blockers early, distributes responsibility
with owners and deadlines, and creates an audit trail for compliance (SOC2, ISO, FDA).

## Pattern Examples

### Risk Scoring Matrix

```typescript
type RiskScore = {
  id: string;
  category: 'TECH' | 'SEC' | 'PERF' | 'DATA' | 'BUS' | 'OPS';
  title: string;
  probability: 1 | 2 | 3;  // 1=Low, 2=Medium, 3=High
  impact: 1 | 2 | 3;        // 1=Low, 2=Medium, 3=High
  score: number;             // probability * impact (1-9)
  owner: string;
  mitigationPlan?: string;
  status: 'OPEN' | 'MITIGATED' | 'WAIVED' | 'ACCEPTED';
};

function classifyRisk(score: number): 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL' {
  if (score === 9) return 'CRITICAL';   // Blocks release
  if (score >= 6) return 'HIGH';         // Requires mitigation plan
  if (score >= 4) return 'MEDIUM';       // Monitor
  return 'LOW';                          // Accept
}
```

### Gate Decision Framework

```typescript
type GateDecision = 'PASS' | 'CONCERNS' | 'FAIL' | 'WAIVED';

function evaluateGate(risks: RiskScore[], coverageGaps: CoverageGap[]): GateDecision {
  const criticalOpen = risks.filter(r => r.score === 9 && r.status === 'OPEN');
  const highOpen = risks.filter(r => r.score >= 6 && r.score < 9 && r.status === 'OPEN');
  const unresolvedGaps = coverageGaps.filter(g => !g.waiverReason);

  // FAIL: Any critical (9) open risk or unresolved coverage gap
  if (criticalOpen.length > 0 || unresolvedGaps.length > 0) return 'FAIL';

  // CONCERNS: High risks (6-8) exist but have mitigation plans and owners
  if (highOpen.length > 0 && highOpen.every(r => r.mitigationPlan && r.owner)) {
    return 'CONCERNS';
  }

  // PASS: No critical issues, all high risks mitigated
  return 'PASS';
}
```

### Coverage Traceability

```typescript
type CoverageGap = {
  acceptanceCriteria: string;
  testMissing: string;
  priority: 'P0' | 'P1' | 'P2' | 'P3';
  waiverReason?: string;
};

function validateCoverage(
  criteria: AcceptanceCriterion[],
  tests: TestCase[]
): { gaps: CoverageGap[]; passRate: number } {
  const gaps = criteria
    .filter(ac => !tests.some(t => t.criteriaIds.includes(ac.id)))
    .map(ac => ({
      acceptanceCriteria: ac.criterion,
      testMissing: `Missing test for: ${ac.criterion}`,
      priority: ac.priority,
    }));

  const passRate = ((criteria.length - gaps.length) / criteria.length) * 100;
  return { gaps, passRate };
}
```

## Anti-Patterns

1. **No scoring system** -- "I think it's fine" is not risk management. Use the
   probability x impact matrix consistently.

2. **Unowned risks** -- Risks without assigned owners never get mitigated. Every risk
   scoring 4 or above needs a named owner and a deadline.

3. **Waivers without expiry** -- Permanent waivers accumulate tech debt silently. Every
   waiver needs an approver, a reason, and an expiry date.

4. **Coverage gaps without waivers** -- Untested acceptance criteria that nobody has
   explicitly accepted as a risk. Make the decision visible.

5. **Gate theater** -- Running gates but always overriding failures. If the gate never
   blocks, it provides no value. Enforce the gate or remove it.

## Integration Points

- **Workflows**: `test-design` (risk identification), `nfr-assessment` (risk scoring)
- **Related fragments**: `test-pyramid` (risk-based level selection),
  `api-testing-patterns` (testing high-risk API paths)
