---
name: axe-core-patterns
tier: accessibility
version: '1.0'
---

# axe-core Patterns

## Principle

axe-core is the de facto standard for automated accessibility testing. It catches
approximately 30-40% of WCAG violations automatically — the remainder require manual
testing. Integrate axe-core into your test suite and CI pipeline to prevent regressions
while complementing with manual audits.

## Rationale

Manual accessibility testing is essential but slow and inconsistent. axe-core provides
fast, repeatable checks for common violations (missing alt text, insufficient contrast,
missing labels). Running axe-core in CI prevents new violations from being introduced,
creating a ratchet effect that improves accessibility over time.

## Pattern Examples

### Playwright Integration

```typescript
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

test.describe('Accessibility', () => {
  test('homepage has no violations', async ({ page }) => {
    await page.goto('/');

    const results = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21aa'])
      .analyze();

    expect(results.violations).toEqual([]);
  });

  test('login form is accessible', async ({ page }) => {
    await page.goto('/login');

    const results = await new AxeBuilder({ page })
      .include('[data-testid="login-form"]')
      .analyze();

    expect(results.violations).toEqual([]);
  });
});
```

### Cypress Integration

```javascript
// cypress/support/commands.js
import 'cypress-axe';

// cypress/e2e/accessibility.cy.js
describe('Accessibility', () => {
  beforeEach(() => {
    cy.visit('/');
    cy.injectAxe();
  });

  it('has no violations on homepage', () => {
    cy.checkA11y(null, {
      runOnly: {
        type: 'tag',
        values: ['wcag2a', 'wcag2aa'],
      },
    });
  });

  it('has no violations on modal', () => {
    cy.get('[data-testid="open-modal"]').click();
    cy.checkA11y('[data-testid="modal"]');
  });
});
```

### Rule Configuration

```typescript
// Disable specific rules when you have a known exception
const results = await new AxeBuilder({ page })
  .disableRules(['color-contrast']) // only if you have a documented exception
  .analyze();

// Run only specific rules
const results = await new AxeBuilder({ page })
  .withRules(['label', 'image-alt', 'button-name', 'link-name'])
  .analyze();

// Target specific WCAG levels
const results = await new AxeBuilder({ page })
  .withTags(['wcag2a'])       // Level A only
  .withTags(['wcag2aa'])      // Level AA
  .withTags(['wcag21aa'])     // WCAG 2.1 Level AA
  .analyze();
```

### CI Integration

```yaml
# GitHub Actions
- name: Run accessibility tests
  run: npx playwright test tests/accessibility/
  env:
    CI: true

# Custom reporter for CI visibility
- name: Upload axe results
  if: always()
  uses: actions/upload-artifact@v4
  with:
    name: accessibility-report
    path: test-results/accessibility/
```

### Custom Result Handling

```typescript
function formatViolations(violations: axe.Result[]): string {
  return violations
    .map((v) => {
      const nodes = v.nodes.map((n) => `  - ${n.html} (${n.failureSummary})`).join('\n');
      return `${v.id} (${v.impact}): ${v.description}\n${nodes}`;
    })
    .join('\n\n');
}

test('check and report violations', async ({ page }) => {
  await page.goto('/dashboard');
  const results = await new AxeBuilder({ page }).analyze();

  if (results.violations.length > 0) {
    console.log('Accessibility violations found:\n' + formatViolations(results.violations));
  }
  expect(results.violations).toEqual([]);
});
```

### Common Violations and Fixes

| Violation | Impact | Fix |
|-----------|--------|-----|
| `image-alt` | Critical | Add `alt` attribute to all `<img>` tags |
| `button-name` | Critical | Add text content or `aria-label` to buttons |
| `link-name` | Serious | Add descriptive text to all links |
| `color-contrast` | Serious | Ensure 4.5:1 ratio for normal text, 3:1 for large |
| `label` | Critical | Associate `<label>` with form inputs via `for`/`id` |
| `region` | Moderate | Wrap content in landmark regions |

## Anti-Patterns

1. **Disabling rules without justification** — Every disabled rule should have a
   documented exception with a plan to fix.

2. **Running axe-core only in development** — Accessibility checks belong in CI.
   New code should never introduce violations.

3. **Testing only the homepage** — Run axe-core on every page and every state
   (modals open, forms with errors, loading states).

4. **Treating axe-core as complete** — axe-core catches 30-40% of issues. Manual
   testing for keyboard nav, screen readers, and focus management is still required.

5. **Ignoring incomplete results** — axe-core reports "incomplete" for checks that
   need human review. These are not passes — review them.

## Integration Points

- **Tools**: axe-core, @axe-core/playwright, cypress-axe, pa11y
- **Workflows**: `accessibility-testing` (test plan), `ci-setup` (pipeline integration)
- **Related fragments**: `wcag-checks` (manual testing checklist)
