---
name: responsive-testing
tier: mobile-testing
version: '1.0'
---

# Responsive Testing

## Principle

Responsive testing validates that applications adapt correctly across viewport sizes,
orientations, and input methods. It bridges the gap between mobile and desktop testing
by ensuring CSS breakpoints, touch interactions, and dynamic layouts work as designed.

## Rationale

Users access applications on devices ranging from 320px to 2560px wide. Responsive
design failures — overlapping elements, hidden content, broken navigation — are among
the most common UI bugs. Automated viewport testing catches layout regressions that
manual testing misses.

## Pattern Examples

### Viewport Testing Matrix

```typescript
const viewports = [
  { name: 'mobile-small', width: 320, height: 568 },   // iPhone SE
  { name: 'mobile', width: 375, height: 812 },          // iPhone 13
  { name: 'mobile-large', width: 428, height: 926 },    // iPhone 14 Pro Max
  { name: 'tablet-portrait', width: 768, height: 1024 },// iPad
  { name: 'tablet-landscape', width: 1024, height: 768 },
  { name: 'laptop', width: 1366, height: 768 },
  { name: 'desktop', width: 1920, height: 1080 },
];

for (const vp of viewports) {
  test(`renders correctly at ${vp.name} (${vp.width}x${vp.height})`, async ({ page }) => {
    await page.setViewportSize({ width: vp.width, height: vp.height });
    await page.goto('/dashboard');
    await expect(page.locator('[data-testid="main-content"]')).toBeVisible();
  });
}
```

### CSS Breakpoint Coverage

```typescript
describe('Navigation', () => {
  test('shows hamburger menu on mobile', async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 812 });
    await page.goto('/');
    await expect(page.locator('[data-testid="hamburger-menu"]')).toBeVisible();
    await expect(page.locator('[data-testid="desktop-nav"]')).toBeHidden();
  });

  test('shows full nav on desktop', async ({ page }) => {
    await page.setViewportSize({ width: 1920, height: 1080 });
    await page.goto('/');
    await expect(page.locator('[data-testid="desktop-nav"]')).toBeVisible();
    await expect(page.locator('[data-testid="hamburger-menu"]')).toBeHidden();
  });

  test('collapses sidebar on tablet', async ({ page }) => {
    await page.setViewportSize({ width: 768, height: 1024 });
    await page.goto('/dashboard');
    await expect(page.locator('[data-testid="sidebar"]')).toHaveCSS('width', '64px');
  });
});
```

### Visual Regression with Percy/Chromatic

```typescript
// Percy integration with Playwright
import percySnapshot from '@percy/playwright';

test('homepage visual regression', async ({ page }) => {
  await page.goto('/');

  // Capture at multiple widths
  await percySnapshot(page, 'Homepage - Mobile', { widths: [375] });
  await percySnapshot(page, 'Homepage - Tablet', { widths: [768] });
  await percySnapshot(page, 'Homepage - Desktop', { widths: [1920] });
});

// Chromatic integration (Storybook)
// stories/Button.stories.tsx
export default {
  title: 'Components/Button',
  component: Button,
  parameters: {
    chromatic: {
      viewports: [320, 768, 1200],
    },
  },
};
```

### Touch vs Click Interaction Testing

```typescript
describe('Touch interactions', () => {
  test('swipe to delete on mobile', async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 812 });
    await page.goto('/list');

    const item = page.locator('[data-testid="list-item-1"]');
    const box = await item.boundingBox();

    await page.mouse.move(box!.x + box!.width - 10, box!.y + box!.height / 2);
    await page.mouse.down();
    await page.mouse.move(box!.x + 10, box!.y + box!.height / 2, { steps: 10 });
    await page.mouse.up();

    await expect(page.locator('[data-testid="delete-action"]')).toBeVisible();
  });

  test('hover tooltip on desktop', async ({ page }) => {
    await page.setViewportSize({ width: 1920, height: 1080 });
    await page.goto('/');

    await page.hover('[data-testid="info-icon"]');
    await expect(page.locator('[role="tooltip"]')).toBeVisible();
  });

  test('long press context menu on mobile', async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 812 });
    await page.goto('/list');

    const item = page.locator('[data-testid="list-item-1"]');
    await item.click({ delay: 1000 }); // simulate long press

    await expect(page.locator('[data-testid="context-menu"]')).toBeVisible();
  });
});
```

### Orientation Testing

```typescript
describe('Orientation changes', () => {
  test('landscape mode adjusts layout', async ({ page }) => {
    // Portrait
    await page.setViewportSize({ width: 375, height: 812 });
    await page.goto('/video-player');
    await expect(page.locator('[data-testid="controls"]')).toBeVisible();

    // Landscape
    await page.setViewportSize({ width: 812, height: 375 });
    await expect(page.locator('[data-testid="fullscreen-controls"]')).toBeVisible();
  });
});
```

## Anti-Patterns

1. **Testing only desktop** — Most traffic is mobile. Include at least 320px, 375px,
   and 768px viewports in every visual regression suite.

2. **Hardcoded pixel assertions** — Asserting `element.width === 375` is fragile.
   Test visibility, layout behavior, and CSS properties instead.

3. **Ignoring touch targets** — Buttons under 44x44px fail mobile usability. Validate
   minimum touch target sizes in responsive tests.

4. **Single breakpoint testing** — Testing only at exact breakpoints misses issues
   at in-between sizes. Include non-standard widths like 360px, 414px, 834px.

5. **Skipping orientation** — Many layouts break in landscape. Test both orientations
   for tablet and mobile viewports.

## Integration Points

- **Tools**: Playwright, Percy, Chromatic, Storybook
- **Workflows**: `mobile-testing` (test plan), `test-automation` (coverage expansion)
- **Related fragments**: `visual-testing` (screenshot comparison), `selector-resilience` (locators)
