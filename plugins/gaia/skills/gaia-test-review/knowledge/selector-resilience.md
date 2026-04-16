---
name: selector-resilience
tier: extended
version: '1.0'
---

# Selector Resilience

## Principle

Robust selectors follow a strict hierarchy: data-testid (best) > ARIA roles (good) >
text content (acceptable) > CSS classes/IDs (last resort). Selectors must survive UI
changes (styling, layout, content updates) and remain human-readable for maintenance.

## Rationale

Brittle selectors (CSS classes, nth-child, complex XPath) break when UI styling changes,
elements are reordered, or design updates occur. This causes a test maintenance burden
and false negatives. Semantic selectors that reflect user intent (ARIA roles, accessible
names, test IDs) are resilient, improve accessibility, and self-document what the test
is verifying.

## Pattern Examples

### Selector Hierarchy

```typescript
// LEVEL 1: data-testid (BEST -- survives all UI changes)
await page.getByTestId('email-input').fill('user@example.com');
await page.getByTestId('login-button').click();

// LEVEL 2: ARIA roles (GOOD -- enforces accessibility)
await page.getByRole('textbox', { name: 'Email' }).fill('user@example.com');
await page.getByRole('button', { name: 'Sign In' }).click();

// LEVEL 3: Text content (ACCEPTABLE -- user-centric)
await page.getByText('Create New Order').click();

// LEVEL 4: CSS/ID (LAST RESORT -- brittle)
// await page.locator('.btn-primary').click();  // Breaks with design updates
```

### Dynamic Content Patterns

```typescript
// Regex for variable content (IDs, timestamps)
await expect(page.getByText(/User \d+/)).toBeVisible();
await expect(page.getByText(/Last login: \d{4}-\d{2}-\d{2}/)).toBeVisible();

// Filter instead of nth() -- content-based, not index-based
await page.locator('[data-testid="product-card"]')
  .filter({ hasText: 'Premium Plan' })
  .click();

// Scoped locators for disambiguation
const shippingSection = page.getByTestId('shipping-section');
await shippingSection.getByLabel('City').fill('New York');
```

### Refactoring Guide (Before/After)

```typescript
// CSS class -> data-testid
// BEFORE: await page.locator('.bg-blue-500.px-4.rounded').click()
// AFTER:
await page.getByTestId('add-to-cart-button').click();

// nth() index -> filter()
// BEFORE: await page.locator('.user-row').nth(2).click()
// AFTER:
await page.locator('[data-testid="user-row"]')
  .filter({ hasText: 'john@example.com' }).click();

// Complex XPath -> ARIA role
// BEFORE: await page.locator('xpath=//div[@id="payment"]//form//button').click()
// AFTER:
await page.getByRole('button', { name: 'Complete Payment' }).click();

// Deep nesting -> scoped data-testid
// BEFORE: await page.locator('.container .sidebar .menu .item:nth-child(3) a').click()
// AFTER:
const sidebar = page.getByTestId('sidebar');
await sidebar.getByRole('link', { name: 'Settings' }).click();
```

## Anti-Patterns

1. **CSS class selectors** -- `.btn-primary`, `.form-input-lg` break with every design
   system update or Tailwind class change.

2. **Arbitrary nth() indexes** -- `.product-card:nth(3)` breaks when items are reordered,
   added, or removed. Use `filter({ hasText })` instead.

3. **Complex XPath** -- `//div[@class="container"]//section[2]//button` is unreadable
   and breaks with any HTML restructuring.

4. **HTML ID selectors** -- `#user-settings-form` seems stable but IDs change during
   accessibility improvements or component refactoring.

5. **No scoping** -- Selecting `getByLabel('Name')` without scoping fails when multiple
   forms have a "Name" field. Scope with `getByTestId('shipping-form').getByLabel('Name')`.

## Integration Points

- **Workflows**: `test-automation` (generate tests with robust selectors), `test-review`
  (selector quality audit)
- **Related fragments**: `test-healing` (selector fallback strategies),
  `deterministic-testing` (stable selectors prevent flakiness),
  `fixture-architecture` (fixtures as alternative to page objects)
