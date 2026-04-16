---
name: test-pyramid
tier: core
version: '1.0'
---

# Test Pyramid

## Principle

Test at the lowest effective level. The pyramid is a risk allocation model, not a rigid
ratio. Unit tests (70%) cover business logic fast. Integration tests (20%) validate
component boundaries. E2E tests (10%) guard critical user journeys. Push tests down
the pyramid whenever possible.

## Rationale

Over-reliance on E2E tests creates slow, brittle, expensive suites. Under-investment in
unit tests means business logic bugs hide behind UI layers. The pyramid ensures fast
feedback for logic, focused validation for boundaries, and high-confidence checks for
critical paths -- without redundant coverage at multiple levels.

## Pattern Examples

### Unit Tests -- Pure Business Logic

```typescript
// src/utils/price-calculator.test.ts
import { calculateDiscount, applyTaxes } from './price-calculator';

describe('PriceCalculator', () => {
  it('applies percentage discount', () => {
    expect(calculateDiscount(100, { type: 'percentage', value: 20 })).toBe(80);
  });

  it('floors discount at zero', () => {
    expect(calculateDiscount(10, { type: 'fixed', value: 20 })).toBe(0);
  });

  it('calculates tax correctly', () => {
    expect(applyTaxes(100, { country: 'US', rate: 0.08 })).toBe(108);
  });
});
```

**When to use**: Pure functions, algorithms, input validation, complex calculations,
state machines. No external dependencies. Fast (milliseconds).

### Integration Tests -- Service Boundaries

```typescript
// tests/integration/user-service.spec.ts
test('creates user with role assignment via API', async ({ request }) => {
  const response = await request.post('/api/users', {
    data: { name: 'Jane', email: 'jane@example.com', role: 'admin' },
  });

  expect(response.status()).toBe(201);
  const user = await response.json();
  expect(user.role).toBe('admin');
  expect(user.permissions).toContain('user:delete');
});

test('rejects duplicate email', async ({ request }) => {
  await request.post('/api/users', { data: { email: 'dup@example.com' } });
  const dup = await request.post('/api/users', { data: { email: 'dup@example.com' } });
  expect(dup.status()).toBe(409);
});
```

**When to use**: Database operations, API contracts, service-to-service communication,
middleware behavior. Moderate speed.

### E2E Tests -- Critical User Journeys

```typescript
// tests/e2e/checkout.spec.ts
test('user completes purchase', async ({ page }) => {
  const loginPromise = page.waitForResponse('**/api/auth/login');
  await page.goto('/login');
  await page.fill('[data-testid="email"]', 'buyer@example.com');
  await page.fill('[data-testid="password"]', 'password123');
  await page.click('[data-testid="login-button"]');
  await loginPromise;

  await page.goto('/checkout');
  await page.click('[data-testid="place-order"]');
  await expect(page.getByText('Order Confirmed')).toBeVisible();
});
```

**When to use**: Revenue-critical paths, cross-system workflows, visual regression,
compliance requirements. Slowest -- reserve for what matters most.

### Decision Matrix

| Scenario               | Unit         | Integration   | E2E          |
|------------------------|--------------|---------------|--------------|
| Pure business logic    | Primary      | Overkill      | Overkill     |
| Database operations    | Cannot test  | Primary       | Overkill     |
| API contracts          | Cannot test  | Primary       | Supplement   |
| User journeys          | Cannot test  | Cannot test   | Primary      |
| Component props/events | Partial      | Component test| Overkill     |
| Visual regression      | Cannot test  | Component test| Primary      |

## Anti-Patterns

1. **E2E testing business logic** -- Testing a discount calculation through the UI is
   slow and brittle. Use a unit test. The UI is for validation, not computation.

2. **Unit testing framework behavior** -- Testing that React renders a component or
   Express routes a request validates the framework, not your code.

3. **Duplicate coverage across levels** -- If a unit test covers discount math, do not
   also write an integration test for the same math. Each level should test different
   aspects.

4. **Inverted pyramid** -- More E2E than unit tests means slow CI, flaky suites, and
   developers avoiding the test suite entirely.

5. **Skipping the duplicate coverage guard** -- Before adding any test, ask: is this
   already tested at a lower level? Can a unit test cover this instead of integration?

## Integration Points

- **Workflows**: `test-design` (level selection), `teach-me-testing` (pyramid education)
- **Related fragments**: `fixture-architecture` (test helpers per level),
  `test-isolation` (isolation strategies per level), `api-testing-patterns` (integration
  layer patterns)
