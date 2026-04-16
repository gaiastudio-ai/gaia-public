---
name: deterministic-testing
tier: core
version: '1.0'
---

# Deterministic Testing

## Principle

A flaky test is worse than no test -- it erodes trust in the entire suite. Every test
must produce the same result regardless of time, environment, execution order, or
network state. Control time, intercept networks, disable animations, seed randomness,
and fix root causes instead of adding retries.

## Rationale

Flaky tests train developers to ignore failures. Once the team starts dismissing red
builds as "probably just flaky," real bugs slip through. Deterministic tests require
more upfront effort but pay for themselves by maintaining trust in the CI pipeline --
the single most important quality signal a team has.

## Pattern Examples

### Time Control

```typescript
// BAD: Test depends on system clock
test('shows expiry warning', () => {
  const token = createToken({ expiresAt: new Date('2025-12-31') });
  expect(isExpiringSoon(token)).toBe(true); // Fails after 2025-12-31
});

// GOOD: Mock the clock
test('shows expiry warning', () => {
  vi.useFakeTimers();
  vi.setSystemTime(new Date('2025-12-25'));

  const token = createToken({ expiresAt: new Date('2025-12-31') });
  expect(isExpiringSoon(token)).toBe(true); // Always passes

  vi.useRealTimers();
});

// Playwright: control browser time
test('countdown displays correctly', async ({ page }) => {
  await page.clock.install({ time: new Date('2025-06-01T12:00:00') });
  await page.goto('/countdown');
  await expect(page.getByTestId('timer')).toHaveText('30 days remaining');
});
```

### Network Determinism

```typescript
// BAD: Navigate then hope the API responds in time
await page.goto('/dashboard');
await expect(page.getByText('Welcome')).toBeVisible(); // Race condition

// GOOD: Intercept BEFORE navigate, wait for response
const responsePromise = page.waitForResponse('**/api/dashboard');
await page.goto('/dashboard');
await responsePromise; // Deterministic -- waits for actual response
await expect(page.getByText('Welcome')).toBeVisible();

// BETTER: Mock for full control
await page.route('**/api/dashboard', (route) => {
  route.fulfill({
    status: 200,
    body: JSON.stringify({ user: { name: 'Alice' }, notifications: 3 }),
  });
});
await page.goto('/dashboard');
await expect(page.getByText('Welcome, Alice')).toBeVisible();
```

### Animation and Transition Handling

```typescript
// Disable animations globally in Playwright config
// playwright.config.ts
export default defineConfig({
  use: {
    // Disable CSS animations and transitions
    contextOptions: {
      reducedMotion: 'reduce',
    },
  },
});

// Or wait for animations to complete
await page.getByTestId('modal').waitFor({ state: 'visible' });
await page.waitForFunction(() => {
  const el = document.querySelector('[data-testid="modal"]');
  return getComputedStyle(el!).opacity === '1';
});
```

### Seeded Random Data

```typescript
// BAD: Random data changes every run
test('processes order', () => {
  const order = { id: Math.random().toString(), total: Math.random() * 100 };
  // Fails intermittently when random values hit edge cases
});

// GOOD: Seeded faker for reproducible randomness
import { faker } from '@faker-js/faker';

beforeEach(() => {
  faker.seed(12345); // Same "random" data every run
});

test('processes order', () => {
  const order = {
    id: faker.string.uuid(),       // Always the same UUID
    total: faker.number.float({ min: 1, max: 100, fractionDigits: 2 }),
  };
  expect(processOrder(order)).toEqual(expect.objectContaining({ status: 'pending' }));
});
```

### Retry vs Fix

```typescript
// BAD: Retries mask the root cause
test('load dashboard', async ({ page }) => {
  // Setting retries: 3 in config because this test is "flaky"
  await page.goto('/dashboard');
  await expect(page.getByText('Welcome')).toBeVisible();
  // Root cause: race condition with API call. Fix the race, not the retry.
});

// GOOD: Fix the root cause
test('load dashboard', async ({ page }) => {
  const dataPromise = page.waitForResponse('**/api/dashboard');
  await page.goto('/dashboard');
  await dataPromise; // Wait for data, not a timeout
  await expect(page.getByText('Welcome')).toBeVisible();
});
```

## Anti-Patterns

1. **Hard waits** -- `page.waitForTimeout(3000)` or `cy.wait(3000)` are never
   deterministic. Use network waits, element state waits, or response promises.

2. **Retries as a fix** -- Adding `retries: 3` to a flaky test hides the bug. Retries
   are for CI resilience on infrastructure glitches, not for masking test design problems.

3. **Uncontrolled randomness** -- `Math.random()` or unseeded faker produces different
   data every run. Seed generators or use fixed values for determinism.

4. **System clock dependency** -- Tests that use `new Date()` or `Date.now()` without
   mocking will behave differently tomorrow. Always mock time.

5. **Ignoring animation timing** -- Clicking elements mid-animation causes intermittent
   failures. Disable animations in test config or wait for animation completion.

## Integration Points

- **Workflows**: `test-review` (flakiness audit), `test-automation` (deterministic
  patterns in generated tests)
- **Related fragments**: `test-isolation` (preventing state leaks),
  `fixture-architecture` (cleanup patterns), `selector-resilience` (stable selectors
  prevent false failures)
