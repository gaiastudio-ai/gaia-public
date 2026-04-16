---
name: data-factories
tier: extended
version: '1.0'
---

# Data Factories

## Principle

Prefer factory functions that accept overrides and return complete objects. Seed test
state through APIs or direct DB helpers before visiting the UI -- never via slow UI
interactions. The UI is for validation only, not data setup. Factories should generate
unique, parallel-safe data with explicit overrides that reveal test intent.

## Rationale

Static fixtures (JSON files, hardcoded objects) create brittle tests that fail when
schemas evolve, cause collisions in parallel execution, and hide test intent. Dynamic
factories with overrides provide parallel safety (UUIDs prevent collisions), schema
evolution (defaults adapt automatically), explicit intent (overrides show what matters),
and speed (API seeding is 10-50x faster than UI).

## Pattern Examples

### Factory Function with Overrides

```typescript
// test-utils/factories/user-factory.ts
import { faker } from '@faker-js/faker';

type User = {
  id: string;
  email: string;
  name: string;
  role: 'user' | 'admin' | 'moderator';
  createdAt: Date;
  isActive: boolean;
};

export const createUser = (overrides: Partial<User> = {}): User => ({
  id: faker.string.uuid(),
  email: faker.internet.email(),
  name: faker.person.fullName(),
  role: 'user',
  createdAt: new Date(),
  isActive: true,
  ...overrides,
});

// Usage -- override shows intent
const admin = createUser({ role: 'admin' });
const inactive = createUser({ isActive: false });
```

### Nested Factory Pattern (Relationships)

```typescript
import { createUser } from './user-factory';
import { createProduct } from './product-factory';

type OrderItem = { product: Product; quantity: number; price: number };
type Order = { id: string; user: User; items: OrderItem[]; total: number; status: string };

export const createOrderItem = (overrides: Partial<OrderItem> = {}): OrderItem => {
  const product = overrides.product || createProduct();
  const quantity = overrides.quantity || faker.number.int({ min: 1, max: 5 });
  return { product, quantity, price: product.price * quantity, ...overrides };
};

export const createOrder = (overrides: Partial<Order> = {}): Order => {
  const items = overrides.items || [createOrderItem(), createOrderItem()];
  const total = items.reduce((sum, item) => sum + item.price, 0);
  return {
    id: faker.string.uuid(),
    user: overrides.user || createUser(),
    items,
    total,
    status: 'pending',
    ...overrides,
  };
};
```

### Composed Specialized Factories

```typescript
// Compose from base -- do not duplicate
export const createAdminUser = (overrides: Partial<User> = {}) =>
  createUser({ role: 'admin', ...overrides });

export const createProAccount = (overrides: Partial<Account> = {}) =>
  createAccount({
    plan: 'pro',
    features: ['analytics', 'priority-support'],
    maxUsers: 10,
    ...overrides,
  });

// Test intent is immediately clear
test('pro accounts access analytics', async ({ page, apiRequest }) => {
  const admin = createAdminUser();
  const account = createProAccount({ owner: admin });
  await apiRequest({ method: 'POST', url: '/api/accounts', data: account });
  await page.goto('/analytics');
  await expect(page.getByText('Advanced Analytics')).toBeVisible();
});
```

### API Seeding Helper

```typescript
// helpers/seed-helpers.ts
export async function seedUser(
  request: APIRequestContext,
  overrides: Partial<User> = {}
): Promise<User> {
  const user = createUser(overrides);
  const response = await request.post('/api/users', { data: user });
  if (!response.ok()) throw new Error(`Seed failed: ${response.status()}`);
  return user;
}

// Cleanup pattern
const createdIds: string[] = [];
afterEach(async ({ request }) => {
  for (const id of createdIds) {
    await request.delete(`/api/users/${id}`);
  }
  createdIds.length = 0;
});
```

## Anti-Patterns

1. **Hardcoded test data** -- `email: 'test@test.com'` causes collisions in parallel
   runs. Use faker with unique values per test.

2. **Static JSON fixtures** -- `fixtures/users.json` with fixed IDs breaks when schemas
   change or tests run in parallel. Use factory functions.

3. **UI-based data setup** -- Filling forms to create test data is 10-50x slower than
   API calls. Use the UI only for validation.

4. **Hidden test intent** -- `createUser()` with no overrides when the test cares about
   a specific role. Always override the fields the test depends on.

5. **No schema evolution strategy** -- When a required field is added to the schema, every
   test with static data breaks. Factories centralize defaults -- update once, all tests
   adapt.

## Integration Points

- **Workflows**: `test-framework` (factory scaffold), `test-automation` (factory usage in
  generated tests)
- **Related fragments**: `fixture-architecture` (factories used inside fixtures),
  `test-isolation` (per-test data prevents state leaks), `api-testing-patterns` (API
  seeding patterns)
