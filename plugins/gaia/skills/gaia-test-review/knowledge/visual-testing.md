---
name: visual-testing
tier: specialized
version: '1.0'
---

# Visual Testing

## Principle

Visual regression testing catches unintended UI changes by comparing screenshots against
approved baselines. Test at the component level for speed and precision, at the page
level for critical journeys. Configure thresholds carefully -- too strict causes noise,
too loose misses real regressions.

## Rationale

CSS changes, font loading failures, layout shifts, and design system updates can break
visual appearance without triggering any functional test failure. Visual tests fill this
gap by asserting on what users actually see, not just what the DOM contains. They are
the only reliable way to catch visual regressions across browsers and viewports.

## Pattern Examples

### Component-Level Visual Tests

```typescript
// tests/visual/button.visual.spec.ts
import { test, expect } from '@playwright/test';

test.describe('Button visual regression', () => {
  for (const variant of ['primary', 'secondary', 'danger']) {
    test(`${variant} button matches baseline`, async ({ page }) => {
      await page.goto(`/storybook/button--${variant}`);
      await expect(page.getByTestId('button')).toHaveScreenshot(
        `button-${variant}.png`,
        { maxDiffPixelRatio: 0.01 }
      );
    });
  }
});
```

### Page-Level Visual Tests

```typescript
test('dashboard layout matches baseline', async ({ page }) => {
  // Mock dynamic content for determinism
  await page.route('**/api/dashboard', (route) => {
    route.fulfill({
      body: JSON.stringify({
        user: { name: 'Test User' },
        stats: { orders: 42, revenue: 1234.56 },
      }),
    });
  });

  await page.goto('/dashboard');
  await page.waitForLoadState('networkidle');

  await expect(page).toHaveScreenshot('dashboard-full.png', {
    fullPage: true,
    maxDiffPixelRatio: 0.02,
  });
});
```

### Handling Dynamic Content

```typescript
test('profile page visual (with masked dynamic areas)', async ({ page }) => {
  await page.goto('/profile');

  // Mask elements with dynamic content (timestamps, avatars)
  await expect(page).toHaveScreenshot('profile.png', {
    mask: [
      page.getByTestId('last-login-timestamp'),
      page.getByTestId('user-avatar'),
      page.getByTestId('notification-count'),
    ],
    maxDiffPixelRatio: 0.01,
  });
});
```

### Threshold Configuration

```typescript
// playwright.config.ts
export default defineConfig({
  expect: {
    toHaveScreenshot: {
      maxDiffPixelRatio: 0.01,  // 1% pixel difference allowed
      threshold: 0.2,           // Per-pixel color threshold (0-1)
      animations: 'disabled',   // Disable CSS animations for stability
    },
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    { name: 'mobile', use: { ...devices['iPhone 14'] } },
  ],
});
```

## Anti-Patterns

1. **Full-page screenshots with dynamic data** -- Timestamps, notification counts, and
   random avatars cause every comparison to fail. Mask dynamic areas or mock the data.

2. **Zero threshold** -- Requiring pixel-perfect matches causes failures from font
   rendering differences across OS versions. Use `maxDiffPixelRatio: 0.01` minimum.

3. **Only page-level tests** -- Full-page visual tests are slow and noisy. Prefer
   component-level tests for design system elements. Reserve page-level for critical
   layouts.

4. **No cross-browser baselines** -- Chrome and Firefox render differently. Generate
   separate baselines per browser/viewport combination.

5. **Stale baselines** -- Baselines that are months old accumulate false positives. Update
   baselines as part of the design change PR, not separately.

## Integration Points

- **Workflows**: `test-automation` (visual test generation), `test-review` (visual
  regression audit)
- **Related fragments**: `selector-resilience` (stable selectors for screenshot targets),
  `deterministic-testing` (mocking dynamic content for stable screenshots),
  `test-pyramid` (visual tests are E2E level)
