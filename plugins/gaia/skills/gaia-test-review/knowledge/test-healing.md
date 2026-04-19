---
name: test-healing
tier: specialized
version: '1.0'
---

# Test Healing

## Principle

Common test failures follow predictable patterns: stale selectors, race conditions,
dynamic data assertions, network errors, and hard waits. Catalog these failure signatures
and apply pattern-based fixes. Automated healing identifies the failure type and suggests
or applies the corresponding fix. Retries mask bugs -- fix the root cause instead.

## Rationale

Test failures waste developer time on repetitive debugging. Teams manually fix the same
selector issues, timing bugs, and data mismatches across test suites. By cataloging
common failure patterns with diagnostic signatures and fixes, maintenance shifts from
reactive debugging to proactive pattern application, reducing repair time by 60-80%.

## Pattern Examples

### Failure Pattern Catalog

| Failure Type   | Diagnostic Signature                        | Fix Strategy                          |
|----------------|---------------------------------------------|---------------------------------------|
| Stale selector | "locator resolved to 0 elements"            | Replace with data-testid or ARIA role |
| Race condition | "timeout waiting for element"               | Add network-first interception        |
| Dynamic data   | "Expected 'User 123' got 'User 456'"        | Use regex or capture dynamic values   |
| Network error  | "API call failed", "500 error"              | Add route mocking                     |
| Hard wait      | Code contains `waitForTimeout()` / `wait(n)`| Replace with event-based waits        |

### Selector Fallback Strategy

```typescript
// Detect stale selector failure
function isSelectorFailure(error: Error): boolean {
  return /locator.*resolved to 0 elements|element not found/i.test(error.message);
}

// Suggest better selector based on what failed
function suggestFix(badSelector: string): string {
  if (badSelector.startsWith('.') || badSelector.includes('class=')) {
    return `page.getByTestId('...') // Replace CSS class with data-testid`;
  }
  if (badSelector.includes('.nth(')) {
    return `page.locator('...').filter({ hasText: '...' }) // Replace nth with filter`;
  }
  if (badSelector.includes('>') || badSelector.includes('+')) {
    return `page.getByRole('button', { name: '...' }) // Replace complex CSS with ARIA`;
  }
  return `page.getByTestId('...') // Add data-testid attribute to element`;
}
```

### Auto-Wait Pattern (Replacing Hard Waits)

```typescript
// BEFORE: Flaky hard wait
// await page.waitForTimeout(3000);

// AFTER: Deterministic event-based wait
// Option A: Wait for network response
await page.waitForResponse(resp =>
  resp.url().includes('/api/dashboard') && resp.ok()
);

// Option B: Wait for element state change
await page.getByTestId('loading-spinner').waitFor({ state: 'detached' });

// Option C: Network-first pattern (intercept before navigate)
const dataPromise = page.waitForResponse('**/api/data');
await page.goto('/page');
await dataPromise;
```

### When Healing Hides Real Issues

```typescript
// DANGEROUS: Auto-retry on any failure
test('dashboard loads', async ({ page }) => {
  // retries: 3 in config -- masks the actual race condition
  await page.goto('/dashboard');
  await expect(page.getByText('Welcome')).toBeVisible();
});

// CORRECT: Fix the root cause
test('dashboard loads', async ({ page }) => {
  const dataPromise = page.waitForResponse('**/api/dashboard');
  await page.goto('/dashboard');
  await dataPromise; // Wait for actual data, not a timer
  await expect(page.getByText('Welcome')).toBeVisible();
});
```

### Healing Workflow

1. **Run test** -- capture failure message and stack trace
2. **Identify pattern** -- match error against diagnostic signatures
3. **Apply fix** -- use pattern-based healing strategy
4. **Re-run test** -- validate fix works (max 3 iterations)
5. **Mark unfixable** -- use `test.fixme()` if healing fails after 3 attempts

## Anti-Patterns

1. **Retry as healing** -- Adding `retries: 3` to flaky tests hides bugs. Retries are
   for CI infrastructure glitches, not test design problems.

2. **Silent selector fallback** -- Auto-switching selectors without logging makes
   debugging harder. Always log what was healed and why.

3. **Healing without root cause analysis** -- Applying a fix without understanding why
   the test broke means it will break again. Document the root cause.

4. **Over-healing** -- Some test failures indicate real bugs. If a test fails because the
   feature is broken, do not heal the test -- fix the feature.

5. **No iteration limit** -- Healing loops without a max attempt count can run forever.
   Cap at 3 attempts, then mark as `test.fixme()` for human review.

## Integration Points

- **Workflows**: `test-review` (healing recommendations), `test-automation` (auto-healing
  after generation)
- **Related fragments**: `selector-resilience` (resilient selector patterns),
  `deterministic-testing` (preventing failures that need healing),
  `fixture-architecture` (clean fixtures prevent state-related failures)
