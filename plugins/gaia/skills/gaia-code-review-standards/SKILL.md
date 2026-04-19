---
name: gaia-code-review-standards
description: Universal review checklist, SOLID violation detection, cyclomatic and cognitive complexity thresholds, and the review-gate-completion hard gate enforced before a story moves to done. Shared dev skill JIT-loaded by dev-story, code-review, and stack dev agents.
allowed-tools: [Read, Grep]
---

## About

Native Claude Code conversion of the legacy `_gaia/dev/skills/code-review-standards.md` skill. Preserves the four sectioned-loading IDs (`review-checklist`, `solid-principles`, `complexity-metrics`, `review-gate-completion`) verbatim. The `review-gate-completion` section documents the hard gate enforced by the `review-gate-check` protocol before a story transitions from `review` to `done`.

- ADR-041 — Native execution model via Claude Code Skills + Subagents + Plugins + Hooks.
- ADR-042 — Scripts-over-LLM. Prose and pattern guidance only.
- ADR-046 — Hybrid memory. Shared content skill; no sidecar loading.

> **Applicable to:** all 6 stack dev agents (typescript, angular, flutter, java, python, mobile) and the code-review skill. The legacy `applicable_agents` frontmatter field is dropped per the E28-S19 schema.

<!-- SECTION: review-checklist -->
## Review Checklist

### Correctness
- [ ] Code does what the PR description claims
- [ ] Edge cases are handled (null, empty, boundary values)
- [ ] Error paths are handled gracefully (no swallowed exceptions)
- [ ] No off-by-one errors in loops or slicing
- [ ] Concurrent access is safe (if applicable)

### Security
- [ ] No secrets, credentials, or API keys in code
- [ ] User input is validated and sanitized
- [ ] SQL queries use parameterized statements
- [ ] Authentication and authorization are enforced
- [ ] Sensitive data is not logged

### Performance
- [ ] No N+1 query patterns
- [ ] No unnecessary re-renders in UI components
- [ ] Large collections use pagination
- [ ] Expensive operations are cached or deferred
- [ ] Database queries have appropriate indexes

### Maintainability
- [ ] Functions and methods are under 30 lines
- [ ] Classes have a single responsibility
- [ ] Variable and function names are descriptive
- [ ] No commented-out code
- [ ] No magic numbers (use named constants)
- [ ] DRY: no copy-pasted logic blocks

### Testing
- [ ] New code has corresponding tests
- [ ] Tests cover happy path and error cases
- [ ] Tests are independent and repeatable
- [ ] No test code in production builds
- [ ] Mocks are reset between tests

### Review Etiquette
- Comment on the code, not the person
- Suggest, do not demand: "Consider using X because..."
- Distinguish blocking issues from suggestions
- Approve with minor comments when appropriate
- Respond to reviews within one business day

<!-- SECTION: solid-principles -->
## SOLID Principles

### Single Responsibility (SRP)
A class should have only one reason to change.

**Violation signal**: Class has methods for unrelated concerns.
```typescript
// BAD: UserService handles auth, email, and data access
class UserService {
  authenticate(credentials) { ... }
  sendWelcomeEmail(user) { ... }
  saveToDatabase(user) { ... }
}

// GOOD: Separated responsibilities
class AuthService { authenticate(credentials) { ... } }
class EmailService { sendWelcome(user) { ... } }
class UserRepository { save(user) { ... } }
```

### Open/Closed (OCP)
Open for extension, closed for modification.

**Violation signal**: Adding a feature requires modifying existing switch/if chains.
```typescript
// BAD: Must modify function for each new type
function calculateArea(shape) {
  if (shape.type === 'circle') return Math.PI * shape.radius ** 2;
  if (shape.type === 'rect') return shape.width * shape.height;
  // Must add more conditions for new shapes
}

// GOOD: Extend via polymorphism
interface Shape { area(): number; }
class Circle implements Shape { area() { return Math.PI * this.radius ** 2; } }
class Rectangle implements Shape { area() { return this.width * this.height; } }
```

### Liskov Substitution (LSP)
Subtypes must be substitutable for their base types.

**Violation signal**: Subclass overrides a method to throw or do nothing.

### Interface Segregation (ISP)
No client should depend on methods it does not use.

**Violation signal**: Interface has many methods and implementations leave some as no-ops.

### Dependency Inversion (DIP)
Depend on abstractions, not concretions.

**Violation signal**: Classes instantiate their own dependencies with `new`.
```typescript
// BAD: Tightly coupled to concrete class
class OrderService {
  private repo = new PostgresOrderRepository();
}

// GOOD: Depend on abstraction, inject at construction
class OrderService {
  constructor(private repo: OrderRepository) {}
}
```

### Review Flags
When reviewing, flag SOLID violations with a prefix tag:
```
[SRP] This class handles both X and Y -- consider splitting.
[OCP] Adding new types requires modifying this switch -- consider strategy pattern.
[DIP] Direct dependency on concrete class -- inject via interface.
```

<!-- SECTION: complexity-metrics -->
## Complexity Metrics

### Cyclomatic Complexity
Measures the number of independent paths through a function.

**Calculation**: Count decision points + 1
- Each `if`, `else if`, `case`, `while`, `for`, `&&`, `||`, `catch` adds 1

| Score | Risk Level | Action |
|-------|------------|--------|
| 1-5 | Low | Acceptable |
| 6-10 | Moderate | Review for simplification |
| 11-20 | High | Refactor required |
| 21+ | Critical | Must be broken apart |

### Cognitive Complexity
Measures how hard code is to understand (more nuanced than cyclomatic).

Increases with:
- Nesting depth (penalty compounds with each level)
- Breaks in linear flow (else, catch, continue, break)
- Recursion

```typescript
// Cognitive complexity: 7 (nested conditions compound)
function getLabel(user, order) {       // +0
  if (user.isAdmin) {                  // +1
    if (order.isPriority) {            // +2 (nesting)
      return 'admin-priority';
    } else {                           // +1
      return 'admin-standard';
    }
  } else if (user.isVip) {            // +1
    return 'vip';
  } else {                            // +1
    if (order.total > 100) {           // +2 (nesting)
      return 'high-value';
    }
    return 'standard';
  }
}
```

### Refactoring High-Complexity Code
**Extract method**: Pull branches into well-named functions.
```typescript
// Before: one long function with nested conditions
function processOrder(order) {
  // 40 lines with nested if/else
}

// After: decomposed into focused functions
function processOrder(order) {
  const pricing = calculatePricing(order);
  const shipping = determineShipping(order);
  return finalizeOrder(order, pricing, shipping);
}
```

**Replace conditionals with polymorphism**: When branching on type, use strategy pattern.

**Use early returns**: Flatten nested conditions with guard clauses.
```typescript
// Before: deeply nested
function validate(input) {
  if (input) {
    if (input.name) {
      if (input.name.length > 0) {
        return true;
      }
    }
  }
  return false;
}

// After: guard clauses
function validate(input) {
  if (!input) return false;
  if (!input.name) return false;
  if (input.name.length === 0) return false;
  return true;
}
```

### Thresholds for Code Review
| Metric | Threshold | Action |
|--------|-----------|--------|
| Function length | > 30 lines | Suggest extraction |
| Cyclomatic complexity | > 10 | Require refactoring |
| Cognitive complexity | > 15 | Require refactoring |
| Parameter count | > 4 | Suggest object parameter |
| Nesting depth | > 3 levels | Require flattening |
| Class methods | > 10 public | Suggest decomposition |

<!-- SECTION: review-gate-completion -->
## Review Gate Completion Requirements

Before a story transitions from `review` to `done`, all 6 individual review reports AND the consolidated review-summary.md must exist in the filesystem. This is a **hard gate** — it is enforced structurally by the `review-gate-check` protocol and is not advisory.

### Required Review Artifacts

| Artifact | Path | Required When |
|---|---|---|
| Code review | `docs/implementation-artifacts/{story_key}-review.md` | Always |
| Security review | `docs/implementation-artifacts/{story_key}-security-review.md` | Always |
| QA tests | `docs/test-artifacts/{story_key}-qa-tests.md` | Always |
| Test automation | `docs/test-artifacts/{story_key}-test-automation.md` | Always |
| Test review | `docs/test-artifacts/{story_key}-test-review.md` | Always |
| Performance review | `docs/implementation-artifacts/{story_key}-performance-review.md` | Always |
| **Review summary** | `docs/implementation-artifacts/{story_key}-review-summary.md` | **Always — enforced hard gate** |

### Enforcement Mechanism (Live)

The hard gate is enforced by `plugins/gaia/scripts/review-gate.sh` (foundation script, ADR-042/ADR-048). Before invoking `status-sync` to move a story from `review` to `done`, the script:

1. Builds the summary file path `{implementation_artifacts}/{story_key}-review-summary.md`
2. Checks whether the file exists
3. If missing AND any of the 6 individual review reports exist → HALT with: `Review summary missing for {story_key}. Run /gaia-run-all-reviews {story_key} to generate the summary, or create it manually via /gaia-create-review-summary {story_key}.`
4. If missing AND all 6 individual review reports are also missing → skip the check (story never entered review)
5. If present → gate passes, transition proceeds

**This is a live hard gate, not a guidance note.** Stories with missing summaries physically cannot transition to `done` — the protocol will halt.

### Auto-Generation via run-all-reviews

`/gaia-run-all-reviews` auto-generates the review-summary.md as the final step of its 6-review pipeline (see `_gaia/lifecycle/workflows/4-implementation/run-all-reviews/instructions.xml` step 8). The summary aggregates the 6 review verdicts (read from the Review Gate table in the story file and from each review's report) — it does not re-run the reviews.

### Manual Generation

If auto-generation fails or is skipped, create the summary manually by copying the schema in `run-all-reviews/instructions.xml` step 8 and filling in the verdicts from the individual reports.

### Review Summary Schema

```yaml
---
story_key: {story_key}
date: {YYYY-MM-DD}
overall_status: PASSED | FAILED | INCOMPLETE
reviewers: [code-review, qa-tests, security-review, test-automate, test-review, review-perf]
---
```

Followed by 6 sections (one per review) with verdict + report link + one-line synopsis, then a final aggregate Gate Status table.

## Test Scenarios

Migrated from the legacy `test_scenarios` frontmatter array (per E28-S19 schema).

| Scenario | Expected |
|----------|----------|
| Review checklist application | All checklist items are evaluated and blocking issues are flagged |
| SOLID violation detection | Reviewer identifies specific SOLID principle violations with remediation suggestions |
| Complexity assessment | Functions exceeding complexity thresholds are flagged with refactoring recommendations |
