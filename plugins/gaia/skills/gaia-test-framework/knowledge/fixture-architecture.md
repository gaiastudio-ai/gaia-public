---
name: fixture-architecture
tier: core
version: '1.0'
---

# Fixture Architecture

## Principle

Build test helpers as pure functions first, then wrap in framework-specific fixtures.
Compose capabilities via `mergeTests` (Playwright) or layered commands (Cypress), not
inheritance. Each fixture solves one isolated concern (auth, API, logs, network).

## Rationale

Traditional Page Object Models create tight coupling through inheritance chains
(`BasePage -> LoginPage -> AdminPage`). When base classes change, all descendants break.
Pure functions with fixture wrappers provide testability (unit-testable without the
framework), composability (mix capabilities freely), reusability (export via package
subpaths), and maintainability (one concern per fixture).

## Pattern Examples

### Pure Function into Fixture Pattern

Always start with a pure function that accepts dependencies explicitly, then wrap it.

```typescript
// Step 1: Pure function (unit-testable without Playwright)
// helpers/api-request.ts
type ApiRequestParams = {
  request: APIRequestContext;
  method: 'GET' | 'POST' | 'PUT' | 'DELETE';
  url: string;
  data?: unknown;
};

export async function apiRequest({ request, method, url, data }: ApiRequestParams) {
  const response = await request.fetch(url, {
    method,
    data,
    headers: { 'Content-Type': 'application/json' },
  });
  if (!response.ok()) {
    throw new Error(`API ${method} ${url} failed: ${response.status()}`);
  }
  return response.json();
}

// Step 2: Fixture wrapper injects framework dependency
// fixtures/api-request-fixture.ts
import { test as base } from '@playwright/test';
import { apiRequest } from '../helpers/api-request';

export const test = base.extend<{ apiRequest: typeof apiRequest }>({
  apiRequest: async ({ request }, use) => {
    await use((params) => apiRequest({ request, ...params }));
  },
});
```

### Composable Fixtures with mergeTests

Compose multiple focused fixtures instead of monolithic helpers.

```typescript
import { test as base, mergeTests } from '@playwright/test';
import { test as apiFixture } from './api-request-fixture';
import { test as networkFixture } from './network-fixture';
import { test as authFixture } from './auth-fixture';

// Compose all capabilities -- no inheritance needed
export const test = mergeTests(base, apiFixture, networkFixture, authFixture);
export { expect } from '@playwright/test';

// Usage: import { test, expect } from './merged-fixtures';
// test('example', async ({ page, apiRequest, auth, network }) => { ... });
```

### Fixture Cleanup Pattern

Track resources created during a test and auto-cleanup in teardown.

```typescript
export const test = base.extend<{ seedUser: (data: Partial<User>) => Promise<User> }>({
  seedUser: async ({}, use) => {
    const createdIds: string[] = [];

    const seedUser = async (data: Partial<User>) => {
      const user = await seedDatabase('users', data);
      createdIds.push(user.id);
      return user;
    };

    await use(seedUser);

    // Auto-cleanup: delete all created users after test
    for (const id of createdIds) {
      await deleteRecord('users', id);
    }
  },
});
```

## Anti-Patterns

1. **Inheritance-based Page Objects** -- `AdminPage extends LoginPage extends BasePage`
   creates fragile chains. Changes to `BasePage` break all descendants. Use pure
   functions and fixture composition instead.

2. **Monolithic fixture files** -- A single fixture providing auth, API, network, and
   database concerns violates single responsibility. Split into focused fixtures and
   compose with `mergeTests`.

3. **Framework-coupled helpers** -- Writing helpers that directly import `page` or `cy`
   makes them untestable in isolation. Accept dependencies as parameters.

4. **No cleanup in fixtures** -- Fixtures that create resources (DB records, files)
   without tracking and deleting them cause test pollution and flakiness.

5. **Premature abstraction** -- Creating fixtures for code used only once. Use the
   3+ uses rule: 3+ uses = fixture, 2-3 uses = utility module, 1 use = keep inline.

## Integration Points

- **Workflows**: `test-framework` (initial scaffold), `test-automation` (test generation),
  `test-review` (fixture quality check)
- **Related fragments**: `data-factories` (factory functions for test data),
  `test-isolation` (dependency injection patterns), `deterministic-testing` (cleanup
  prevents state leaks)
