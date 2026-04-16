---
name: jest-vitest-patterns
tier: unit-testing
version: '1.0'
---

# Jest & Vitest Patterns

## Principle

Fast feedback loops drive TDD adoption in JavaScript and TypeScript. Jest and Vitest
provide near-identical APIs with different performance profiles — Vitest leverages
Vite's transform pipeline for faster execution. Choose based on your bundler; the
testing patterns remain the same.

## Rationale

JavaScript's module system and dynamic typing make mocking both powerful and dangerous.
The describe/it/expect structure enables readable tests, but over-reliance on mocking
internals creates brittle suites. Focus on testing behavior through public APIs and
rendered output.

## Pattern Examples

### Basic Structure

```typescript
// src/utils/format-currency.test.ts
import { formatCurrency } from './format-currency';

describe('formatCurrency', () => {
  it('formats USD with two decimal places', () => {
    expect(formatCurrency(1234.5, 'USD')).toBe('$1,234.50');
  });

  it('handles zero', () => {
    expect(formatCurrency(0, 'USD')).toBe('$0.00');
  });

  it('handles negative amounts', () => {
    expect(formatCurrency(-50, 'USD')).toBe('-$50.00');
  });
});
```

### Parameterized Tests

```typescript
describe('validateEmail', () => {
  it.each([
    ['user@example.com', true],
    ['user@sub.example.com', true],
    ['invalid', false],
    ['@example.com', false],
    ['user@', false],
  ])('validates %s as %s', (email, expected) => {
    expect(validateEmail(email)).toBe(expected);
  });
});
```

### Module Mocking

```typescript
// Jest
jest.mock('./api-client', () => ({
  fetchUsers: jest.fn().mockResolvedValue([{ id: 1, name: 'Alice' }]),
}));

// Vitest
vi.mock('./api-client', () => ({
  fetchUsers: vi.fn().mockResolvedValue([{ id: 1, name: 'Alice' }]),
}));

// Manual mock — __mocks__/api-client.ts
export const fetchUsers = jest.fn().mockResolvedValue([]);
```

### React Testing Library

```typescript
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { LoginForm } from './LoginForm';

describe('LoginForm', () => {
  it('submits credentials', async () => {
    const onSubmit = vi.fn();
    render(<LoginForm onSubmit={onSubmit} />);

    await userEvent.type(screen.getByLabelText('Email'), 'user@test.com');
    await userEvent.type(screen.getByLabelText('Password'), 'secret123');
    await userEvent.click(screen.getByRole('button', { name: 'Sign In' }));

    expect(onSubmit).toHaveBeenCalledWith({
      email: 'user@test.com',
      password: 'secret123',
    });
  });

  it('shows validation error for empty email', async () => {
    render(<LoginForm onSubmit={vi.fn()} />);
    await userEvent.click(screen.getByRole('button', { name: 'Sign In' }));
    expect(screen.getByText('Email is required')).toBeInTheDocument();
  });
});
```

### Async Testing

```typescript
describe('UserService', () => {
  it('fetches user by id', async () => {
    const user = await userService.getById(1);
    expect(user).toEqual(expect.objectContaining({ id: 1, name: 'Alice' }));
  });

  it('throws on not found', async () => {
    await expect(userService.getById(999)).rejects.toThrow('User not found');
  });
});
```

### Snapshot Testing (Judicious Use)

```typescript
// Good — stable UI structure
it('renders navigation menu', () => {
  const { container } = render(<NavMenu items={menuItems} />);
  expect(container.firstChild).toMatchSnapshot();
});

// Better — inline snapshot for small outputs
it('formats address', () => {
  expect(formatAddress(address)).toMatchInlineSnapshot(`
    "123 Main St
    Suite 100
    New York, NY 10001"
  `);
});
```

### Setup and Teardown

```typescript
describe('DatabaseService', () => {
  let db: TestDatabase;

  beforeAll(async () => {
    db = await TestDatabase.create();
  });

  afterAll(async () => {
    await db.destroy();
  });

  beforeEach(async () => {
    await db.seed(testData);
  });

  afterEach(async () => {
    await db.truncate();
  });

  it('creates a record', async () => {
    const record = await db.insert({ name: 'test' });
    expect(record.id).toBeDefined();
  });
});
```

## Anti-Patterns

1. **Implementation testing** — Testing that a function calls another internal function
   rather than testing the observable output. Refactoring breaks these tests.

2. **Snapshot overuse** — Large component snapshots that nobody reviews. Snapshots
   should be small, targeted, and meaningful.

3. **Testing framework internals** — Verifying React re-renders or state updates
   instead of rendered output. Test what the user sees.

4. **Mocking everything** — Mocking the module under test or its direct logic.
   Only mock external dependencies and side effects.

5. **Ignoring async cleanup** — Not awaiting cleanup in afterEach, causing test
   pollution and flaky failures.

## Integration Points

- **Frameworks**: React (RTL), Next.js (next/jest), Express (supertest), Vue (vue-test-utils)
- **Workflows**: `test-framework` (initial setup), `test-automation` (coverage expansion)
- **Related fragments**: `fixture-architecture` (test helpers), `test-isolation` (isolation)
