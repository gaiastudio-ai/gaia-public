---
name: TypeScript Conventions and Standards
stack: typescript
version: "1.0"
focus: [typescript]
---

# TypeScript Conventions and Standards

## Principle

Enable strict mode, use TypeScript's type system expressively (utility types, generics, discriminated unions), organize code with barrel exports and path aliases, and treat types as documentation. Prefer `interface` for object shapes and `type` for unions, intersections, and mapped types.

## Rationale

TypeScript's value comes from its type system catching errors at compile time. Strict mode (`"strict": true`) enables all strictness flags, preventing common bugs like implicit `any`, unchecked nulls, and incorrect `this` binding. Utility types (`Partial`, `Pick`, `Omit`, `Record`) reduce boilerplate. Generics enable reusable, type-safe abstractions. Barrel exports and path aliases create clean public APIs and eliminate deep relative import paths.

## Pattern Examples

### Pattern 1: Strict Mode and Utility Types

```typescript
// tsconfig.json — strict mode enabled
// { "compilerOptions": { "strict": true, "noUncheckedIndexedAccess": true } }

// Utility types reduce duplication
interface User {
  id: string;
  email: string;
  name: string;
  role: 'admin' | 'member' | 'viewer';
  createdAt: Date;
  updatedAt: Date;
}

// Derive types from the source of truth
type CreateUserInput = Omit<User, 'id' | 'createdAt' | 'updatedAt'>;
type UpdateUserInput = Partial<Pick<User, 'name' | 'role'>>;
type UserSummary = Pick<User, 'id' | 'name' | 'email'>;

// Record for typed dictionaries
type PermissionMap = Record<User['role'], string[]>;

const permissions: PermissionMap = {
  admin: ['read', 'write', 'delete', 'manage'],
  member: ['read', 'write'],
  viewer: ['read'],
};
```

### Pattern 2: Generics and Discriminated Unions

```typescript
// Generic Result type for explicit error handling
type Result<T, E = Error> =
  | { success: true; data: T }
  | { success: false; error: E };

function ok<T>(data: T): Result<T> {
  return { success: true, data };
}

function fail<E>(error: E): Result<never, E> {
  return { success: false, error };
}

// Usage — compiler forces handling both cases
async function fetchUser(id: string): Promise<Result<User, string>> {
  try {
    const user = await db.users.findUnique({ where: { id } });
    if (!user) return fail(`User ${id} not found`);
    return ok(user);
  } catch (e) {
    return fail('Database error');
  }
}

const result = await fetchUser('123');
if (result.success) {
  console.log(result.data.name);  // TypeScript knows data exists
} else {
  console.error(result.error);    // TypeScript knows error exists
}

// Discriminated union for state machines
type AsyncState<T> =
  | { status: 'idle' }
  | { status: 'loading' }
  | { status: 'success'; data: T }
  | { status: 'error'; error: Error };
```

### Pattern 3: Barrel Exports and Path Aliases

```typescript
// src/features/users/index.ts — barrel export
export { UserService } from './user.service';
export { UserRepository } from './user.repository';
export type { User, CreateUserInput, UpdateUserInput } from './user.types';
// Do NOT export internal helpers or implementation details

// tsconfig.json paths
// {
//   "compilerOptions": {
//     "baseUrl": ".",
//     "paths": {
//       "@/features/*": ["src/features/*"],
//       "@/shared/*": ["src/shared/*"],
//       "@/config": ["src/config/index.ts"]
//     }
//   }
// }

// Clean imports from consumers
import { UserService } from '@/features/users';
import { Logger } from '@/shared/logging';
import { config } from '@/config';
```

## Anti-Patterns

- **`any` escape hatch**: Using `any` to silence type errors defeats TypeScript's purpose. Use `unknown` for truly unknown types, then narrow with type guards.
- **Type assertions (`as`)**: `response as User` skips type checking. Use type guards or validation (Zod, io-ts) for runtime safety.
- **Enums for simple unions**: `enum Role { Admin, Member }` is heavier than `type Role = 'admin' | 'member'`. Prefer string literal unions.
- **Deep relative imports**: `import { X } from '../../../shared/utils/helpers'`. Use path aliases (`@/shared/utils`).
- **No strict mode**: Running without `"strict": true` allows implicit `any` and unchecked nulls throughout the codebase.

## Integration Points

- **React**: Typed props, hooks, and context use these conventions; see `react-patterns.md`.
- **Next.js**: Route handlers, page props, and metadata types; see `nextjs-patterns.md`.
- **Express**: Typed middleware and request extensions; see `express-patterns.md`.
- **ESLint**: Use `@typescript-eslint/parser` and `@typescript-eslint/eslint-plugin` for TypeScript-aware linting.
