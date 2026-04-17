---
name: Angular Style Guide and Conventions
stack: angular
version: "1.0"
focus: [angular]
---

# Angular Style Guide and Conventions

## Principle

Follow the official Angular style guide for consistent naming, file organization, and coding patterns. Use PascalCase for components and directives, camelCase for services and pipes, and organize code by feature module. Barrel exports simplify imports and enforce public API boundaries.

## Rationale

Consistent conventions reduce cognitive load across teams and projects. Angular's opinionated style guide exists because the framework's DI system, module system, and CLI tooling all assume these conventions. Deviating from them breaks `ng generate`, confuses new team members, and makes automated tooling unreliable.

## Pattern Examples

### Pattern 1: File and Class Naming

```
src/app/
  features/
    users/
      components/
        user-list/
          user-list.component.ts        # UserListComponent
          user-list.component.html
          user-list.component.scss
          user-list.component.spec.ts
        user-detail/
          user-detail.component.ts       # UserDetailComponent
      services/
        user.service.ts                  # UserService
        user-api.service.ts              # UserApiService
      models/
        user.model.ts                    # User (interface)
      pipes/
        user-role.pipe.ts                # UserRolePipe
      directives/
        highlight.directive.ts           # HighlightDirective
      guards/
        auth.guard.ts                    # authGuard (functional)
      users.routes.ts                    # Route definitions
      index.ts                           # Barrel export
  shared/
    components/
    directives/
    pipes/
    index.ts
  core/
    interceptors/
      auth.interceptor.ts               # authInterceptor (functional)
    services/
      logger.service.ts                  # LoggerService
    index.ts
```

### Pattern 2: Barrel Exports

```typescript
// features/users/index.ts — public API of the users feature
export { UserListComponent } from './components/user-list/user-list.component';
export { UserDetailComponent } from './components/user-detail/user-detail.component';
export { UserService } from './services/user.service';
export { User } from './models/user.model';

// Do NOT export internal components, helpers, or private services.
// Consumers import from the barrel:
// import { UserService, User } from '@app/features/users';
```

### Pattern 3: Standalone Components with Lazy Loading

```typescript
// users.routes.ts — lazy-loaded feature routes (Angular 15+)
import { Routes } from '@angular/router';

export const USERS_ROUTES: Routes = [
  {
    path: '',
    loadComponent: () =>
      import('./components/user-list/user-list.component')
        .then(m => m.UserListComponent),
  },
  {
    path: ':id',
    loadComponent: () =>
      import('./components/user-detail/user-detail.component')
        .then(m => m.UserDetailComponent),
  },
];

// app.routes.ts
export const APP_ROUTES: Routes = [
  {
    path: 'users',
    loadChildren: () =>
      import('./features/users/users.routes')
        .then(m => m.USERS_ROUTES),
  },
];
```

## Anti-Patterns

- **Flat src/app directory**: Dumping all components, services, and models into the root app directory. Organize by feature, then by type within each feature.
- **Inconsistent casing**: Mixing `userList.component.ts` with `UserList.component.ts`. Always use kebab-case for file names, PascalCase for classes.
- **Wildcard barrel exports**: Using `export * from './...'` leaks internal implementation details. Export explicitly.
- **Circular dependencies**: Feature A importing from Feature B which imports from Feature A. Use a shared module or refactor.
- **Single shared module**: One giant `SharedModule` that re-exports everything. Break into smaller focused modules or use standalone components.

## Integration Points

- **Angular CLI**: `ng generate` respects these conventions. Use `--flat=false` for directory-per-component.
- **Path Aliases**: Configure `tsconfig.json` paths (`@app/*`, `@shared/*`, `@core/*`) to match the directory structure.
- **ESLint**: Use `@angular-eslint` with naming-convention rules to enforce PascalCase for components and camelCase for services.
- **NgRx**: Feature state files follow the same feature directory structure: `features/users/store/` (see `ngrx-state.md`).
