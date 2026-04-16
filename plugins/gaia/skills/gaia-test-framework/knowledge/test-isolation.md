---
name: test-isolation
tier: core
version: '1.0'
---

# Test Isolation

## Principle

Tests must be deterministic and independent. A test that depends on another test's side
effects is a time bomb. Isolate via test doubles, dependency injection, per-test data
cleanup, and network mocking. Each test must be runnable alone, in any order, at any time.

## Rationale

Shared mutable state between tests causes cascading failures that are nearly impossible
to debug. Test A creates a user, test B assumes it exists, test C deletes it -- now B
and C fail when run without A. Proper isolation eliminates this class of bugs entirely
and enables parallel execution, which dramatically reduces CI time.

## Pattern Examples

### Test Doubles -- When to Use Each

```typescript
// STUB: Returns canned data. Use when you need controlled input.
const priceService = { getPrice: () => 99.99 };

// MOCK: Verifies interactions. Use when you need to assert calls happened.
const emailService = { send: vi.fn() };
await registerUser(user, emailService);
expect(emailService.send).toHaveBeenCalledWith(user.email, expect.any(String));

// SPY: Wraps real implementation, records calls. Use for observation without replacement.
const spy = vi.spyOn(logger, 'warn');
await processOrder(invalidOrder);
expect(spy).toHaveBeenCalledWith('Invalid order data');

// FAKE: Simplified working implementation. Use for complex dependencies.
class InMemoryUserRepo implements UserRepository {
  private users = new Map<string, User>();
  async save(user: User) { this.users.set(user.id, user); }
  async findById(id: string) { return this.users.get(id) ?? null; }
}

// DUMMY: Placeholder that is never used. Use to satisfy required parameters.
const unusedLogger = {} as Logger;
const calc = new PriceCalculator(unusedLogger); // logger not called in this test
```

### Dependency Injection for Testability

```typescript
// BAD: Hard dependency -- impossible to test without real DB
class UserService {
  async getUser(id: string) {
    return await database.query('SELECT * FROM users WHERE id = ?', [id]);
  }
}

// GOOD: Inject dependency -- testable with fake/mock
class UserService {
  constructor(private repo: UserRepository) {}

  async getUser(id: string) {
    return this.repo.findById(id);
  }
}

// Test with fake
const repo = new InMemoryUserRepo();
await repo.save({ id: '1', name: 'Alice', email: 'alice@test.com' });
const service = new UserService(repo);
const user = await service.getUser('1');
expect(user?.name).toBe('Alice');
```

### Database Isolation

```typescript
// Per-test truncation -- clean slate for every test
beforeEach(async () => {
  await db.query('TRUNCATE users, orders, products CASCADE');
});

// Test containers -- isolated DB per test suite
import { PostgreSqlContainer } from '@testcontainers/postgresql';

let container: StartedPostgreSqlContainer;
beforeAll(async () => {
  container = await new PostgreSqlContainer().start();
  await runMigrations(container.getConnectionUri());
});
afterAll(async () => { await container.stop(); });

// Transaction rollback -- fastest, wraps each test in a transaction
beforeEach(async () => { await db.query('BEGIN'); });
afterEach(async () => { await db.query('ROLLBACK'); });
```

### Network Isolation

```typescript
// Playwright: intercept all external calls
await page.route('**/api/**', (route) => {
  route.fulfill({
    status: 200,
    body: JSON.stringify({ users: [{ id: 1, name: 'Test User' }] }),
  });
});

// Intercept BEFORE navigate to prevent race conditions
const responsePromise = page.waitForResponse('**/api/dashboard');
await page.goto('/dashboard');
await responsePromise;
```

## Anti-Patterns

1. **Shared mutable state** -- Global variables modified by tests. Use fresh instances
   per test or factory functions that return new objects each time.

2. **Order-dependent tests** -- Test B relies on data created by test A. Each test must
   set up and tear down its own data.

3. **Real network calls in tests** -- Tests hitting live APIs are slow, flaky, and
   nondeterministic. Mock or intercept all external network calls.

4. **Mocking what you do not own** -- Mocking third-party library internals creates
   brittle tests. Wrap the library in your own adapter, then mock the adapter.

5. **Over-mocking** -- Mocking every dependency reduces test confidence. Use fakes for
   complex dependencies, mocks for interaction verification, and real implementations
   when fast and deterministic.

## Integration Points

- **Workflows**: `test-framework` (isolation setup), `test-review` (isolation audit)
- **Related fragments**: `fixture-architecture` (cleanup in fixtures),
  `deterministic-testing` (preventing flakiness), `data-factories` (per-test data
  generation)
