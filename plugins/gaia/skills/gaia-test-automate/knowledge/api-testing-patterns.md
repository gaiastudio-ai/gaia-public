---
name: api-testing-patterns
tier: extended
version: '1.0'
---

# API Testing Patterns

## Principle

Test APIs and backend services directly without browser overhead. Use Playwright's
`request` context for HTTP operations and Zod schemas for runtime validation. API-first
testing provides faster feedback, better stability, and more focused coverage than
testing backend logic through UI layers.

## Rationale

Many teams over-rely on E2E browser tests when API tests would be faster, more stable,
and more precise. If you are testing what the server returns (not how it looks), use API
tests. They run in milliseconds, have no browser startup cost, and provide clear
request/response debugging without DOM noise.

## Pattern Examples

### Pure API Test (No Browser)

```typescript
// tests/api/users.spec.ts
import { test, expect } from '@playwright/test';

test.describe('Users API', () => {
  test('creates user', async ({ request }) => {
    const response = await request.post('/api/users', {
      data: { name: 'John Doe', email: 'john@example.com', role: 'user' },
    });
    expect(response.status()).toBe(201);
    const user = await response.json();
    expect(user.id).toBeDefined();
    expect(user.email).toBe('john@example.com');
  });

  test('returns 404 for missing user', async ({ request }) => {
    const response = await request.get('/api/users/nonexistent');
    expect(response.status()).toBe(404);
    const error = await response.json();
    expect(error.code).toBe('USER_NOT_FOUND');
  });

  test('validates required fields', async ({ request }) => {
    const response = await request.post('/api/users', {
      data: { name: 'Missing Email' },
    });
    expect(response.status()).toBe(400);
    const error = await response.json();
    expect(error.code).toBe('VALIDATION_ERROR');
  });
});
```

### Schema Validation with Zod

```typescript
import { z } from 'zod';

const OrderSchema = z.object({
  id: z.string().uuid(),
  userId: z.string(),
  items: z.array(z.object({
    productId: z.string(),
    quantity: z.number().positive(),
    price: z.number().positive(),
  })),
  total: z.number().positive(),
  status: z.enum(['pending', 'processing', 'shipped', 'delivered']),
  createdAt: z.string().datetime(),
});

test('creates order with valid schema', async ({ request }) => {
  const response = await request.post('/api/orders', {
    data: {
      userId: 'user-123',
      items: [{ productId: 'prod-1', quantity: 2, price: 29.99 }],
    },
  });
  expect(response.status()).toBe(201);
  const body = await response.json();
  const parsed = OrderSchema.parse(body); // Throws if schema mismatch
  expect(parsed.status).toBe('pending');
});
```

### Error Response Validation

```typescript
test.describe('Error handling', () => {
  test('handles duplicate email (409)', async ({ request }) => {
    await request.post('/api/users', { data: { email: 'dup@test.com' } });
    const dup = await request.post('/api/users', { data: { email: 'dup@test.com' } });
    expect(dup.status()).toBe(409);
    const error = await dup.json();
    expect(error.message).toContain('already exists');
  });

  test('handles malformed JSON (400)', async ({ request }) => {
    const response = await request.post('/api/users', {
      headers: { 'Content-Type': 'application/json' },
      data: 'not-json',
    });
    expect(response.status()).toBe(400);
  });

  test('handles rate limiting (429)', async ({ request }) => {
    // Trigger rate limit
    for (let i = 0; i < 100; i++) {
      await request.get('/api/users');
    }
    const response = await request.get('/api/users');
    expect(response.status()).toBe(429);
    expect(response.headers()['retry-after']).toBeDefined();
  });
});
```

### Authentication in API Tests

```typescript
test.describe('Authenticated API', () => {
  let authToken: string;

  test.beforeAll(async ({ request }) => {
    const res = await request.post('/api/auth/login', {
      data: { email: process.env.TEST_USER_EMAIL, password: process.env.TEST_USER_PASSWORD },
    });
    authToken = (await res.json()).token;
  });

  test('accesses protected endpoint', async ({ request }) => {
    const response = await request.get('/api/me', {
      headers: { Authorization: `Bearer ${authToken}` },
    });
    expect(response.status()).toBe(200);
  });

  test('rejects missing token', async ({ request }) => {
    const response = await request.get('/api/me');
    expect(response.status()).toBe(401);
  });

  test('rejects insufficient role', async ({ request }) => {
    const response = await request.get('/api/admin/users', {
      headers: { Authorization: `Bearer ${authToken}` },
    });
    expect(response.status()).toBe(403);
  });
});
```

### API-Only Playwright Config

```typescript
export default defineConfig({
  testDir: './tests/api',
  use: {
    baseURL: process.env.API_URL || 'http://localhost:3000',
    extraHTTPHeaders: { Accept: 'application/json' },
  },
  timeout: 30000,
  workers: 4,
  fullyParallel: true,
});
```

## Anti-Patterns

1. **Testing APIs through UI** -- Filling a form and clicking submit to test user
   creation validates the UI, not the API. Test the API directly.

2. **No dedicated API test suite** -- Assuming E2E tests cover the API. E2E tests one
   happy path; API tests cover edge cases, error codes, and validation.

3. **Hardcoded test data** -- Static emails and IDs cause parallel test collisions.
   Use factory functions with unique values.

4. **Ignoring error responses** -- Only testing 200 responses. Test 400, 401, 403, 404,
   409, 429, and 500 scenarios explicitly.

5. **No schema validation** -- Trusting response shapes without runtime verification.
   Use Zod or AJV to validate response structures.

## Integration Points

- **Workflows**: `test-design` (API test planning), `test-automation` (API test generation),
  `atdd` (acceptance criteria via API)
- **Related fragments**: `test-pyramid` (API tests are integration level),
  `data-factories` (test data for API requests), `contract-testing` (Pact for service
  contracts)
