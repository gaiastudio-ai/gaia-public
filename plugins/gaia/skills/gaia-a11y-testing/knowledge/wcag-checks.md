---
name: wcag-checks
tier: accessibility
version: '1.0'
---

# WCAG 2.1 Checks

## Principle

WCAG 2.1 Level AA is the baseline standard for web accessibility. The four principles
— Perceivable, Operable, Understandable, Robust (POUR) — provide a framework for
evaluating accessibility. Each principle contains guidelines with specific, testable
success criteria.

## Rationale

Legal requirements (ADA, EAA, Section 508) increasingly mandate WCAG 2.1 AA compliance.
Beyond compliance, accessible design improves usability for all users — keyboard
navigation helps power users, captions help users in noisy environments, and clear
structure helps everyone. Testing against POUR ensures comprehensive coverage.

## Pattern Examples

### Perceivable

**1.1 Text Alternatives**
```html
<!-- Good: Informative alt text -->
<img src="chart.png" alt="Q3 revenue increased 15% to $2.3M" />

<!-- Good: Decorative image -->
<img src="divider.png" alt="" role="presentation" />

<!-- Bad: Missing or meaningless alt -->
<img src="chart.png" />
<img src="chart.png" alt="image" />
```

**1.3 Adaptable — Correct heading hierarchy**
```html
<!-- Good: Logical hierarchy -->
<h1>Dashboard</h1>
  <h2>Sales Overview</h2>
    <h3>Monthly Trends</h3>
  <h2>Customer Metrics</h2>

<!-- Bad: Skipped levels -->
<h1>Dashboard</h1>
  <h3>Sales Overview</h3>  <!-- skipped h2 -->
```

**1.4 Distinguishable — Color contrast**
```css
/* Good: 4.5:1 ratio for normal text */
.body-text { color: #333333; background: #ffffff; } /* 12.6:1 */

/* Good: 3:1 ratio for large text (18px+ or 14px+ bold) */
.heading { color: #767676; background: #ffffff; font-size: 24px; } /* 4.5:1 */

/* Bad: Insufficient contrast */
.light-text { color: #aaaaaa; background: #ffffff; } /* 2.3:1 */
```

### Operable

**2.1 Keyboard Accessible**
```typescript
// Test: All interactive elements reachable by Tab
test('keyboard navigation covers all actions', async ({ page }) => {
  await page.goto('/form');
  const tabbableElements = await page.evaluate(() => {
    const elements: string[] = [];
    let el = document.body;
    while (el = document.activeElement as HTMLElement) {
      elements.push(el.tagName + (el.id ? '#' + el.id : ''));
      (el as HTMLElement).dispatchEvent(new KeyboardEvent('keydown', { key: 'Tab' }));
      if (elements.length > 50) break;
    }
    return elements;
  });
  expect(tabbableElements).toContain('BUTTON#submit');
});

// Test: No keyboard trap
test('escape closes modal', async ({ page }) => {
  await page.click('[data-testid="open-modal"]');
  await page.keyboard.press('Escape');
  await expect(page.locator('[data-testid="modal"]')).toBeHidden();
});
```

**2.4 Navigable — Focus indicators**
```css
/* Good: Visible focus indicator */
:focus-visible {
  outline: 2px solid #0066cc;
  outline-offset: 2px;
}

/* Bad: Removing focus indicator */
:focus { outline: none; } /* NEVER do this without a replacement */
```

### Understandable

**3.1 Readable — Language declared**
```html
<html lang="en">
<!-- For multilingual content -->
<p>The French word <span lang="fr">bonjour</span> means hello.</p>
```

**3.2 Predictable — Consistent navigation**
```html
<!-- Navigation must be consistent across pages -->
<nav aria-label="Main navigation">
  <ul>
    <li><a href="/" aria-current="page">Home</a></li>
    <li><a href="/about">About</a></li>
    <li><a href="/contact">Contact</a></li>
  </ul>
</nav>
```

**3.3 Input Assistance — Error handling**
```html
<!-- Good: Error identified and described -->
<label for="email">Email</label>
<input id="email" type="email" aria-describedby="email-error" aria-invalid="true" />
<p id="email-error" role="alert">Please enter a valid email address (e.g., user@example.com)</p>
```

### Robust

**4.1 Compatible — Valid ARIA**
```html
<!-- Good: Correct ARIA usage -->
<button aria-expanded="false" aria-controls="menu-dropdown">Menu</button>
<ul id="menu-dropdown" role="menu" hidden>
  <li role="menuitem"><a href="/profile">Profile</a></li>
</ul>

<!-- Bad: Conflicting roles -->
<div role="button" role="link">Click me</div>
```

### Testing Tools Quick Reference

| Tool | Purpose | Automated? |
|------|---------|-----------|
| axe-core | Rule-based WCAG scanning | Yes |
| Lighthouse | Accessibility score + audit | Yes |
| WAVE | Visual overlay of issues | Semi |
| VoiceOver (macOS/iOS) | Screen reader testing | Manual |
| NVDA (Windows) | Screen reader testing | Manual |
| Colour Contrast Analyser | Contrast ratio checking | Manual |
| Keyboard only | Tab/Enter/Space navigation | Manual |

### Screen Reader Testing Procedure

1. Turn on screen reader (VoiceOver: Cmd+F5, NVDA: Ctrl+Alt+N)
2. Navigate page with Tab key — verify all interactive elements announced
3. Read through headings (VO: Ctrl+Alt+Cmd+H) — verify logical order
4. Complete primary user flow using only keyboard
5. Verify form labels read correctly when fields focused
6. Check dynamic content updates announced via live regions
7. Verify modal focus trap works correctly

## Anti-Patterns

1. **ARIA overuse** — Adding ARIA to elements that already have semantic meaning.
   `<button>` does not need `role="button"`. Use semantic HTML first.

2. **Color as sole indicator** — Using only color to convey information (red for error,
   green for success). Add icons, text, or patterns alongside color.

3. **Removing focus indicators** — `outline: none` without a visible replacement makes
   keyboard navigation impossible.

4. **Auto-playing media** — Audio or video that plays automatically without user control
   violates WCAG 1.4.2.

5. **Non-descriptive links** — "Click here" and "Read more" links provide no context
   to screen reader users. Use descriptive link text.

## Integration Points

- **Tools**: axe-core, VoiceOver, NVDA, Lighthouse, WAVE
- **Workflows**: `accessibility-testing` (test plan), `test-review` (quality checks)
- **Related fragments**: `axe-core-patterns` (automated testing)
