---
name: NgRx State Management
stack: angular
version: "1.0"
focus: [ngrx]
---

# NgRx State Management

## Principle

Use NgRx as the single source of truth for application state. Follow strict action hygiene: actions describe unique events (not commands), reducers are pure functions, effects handle side effects, and selectors compose derived state. Keep the store normalized and flat.

## Rationale

NgRx enforces a unidirectional data flow that makes state changes predictable and debuggable via Redux DevTools. Action hygiene (naming actions as past-tense events from their source, e.g., `[User List] Load Users`) makes the action log a readable audit trail. Selectors with `createSelector` are memoized, preventing unnecessary recomputation and re-renders when combined with `OnPush` change detection.

## Pattern Examples

### Pattern 1: Action Hygiene and Reducer

```typescript
// actions — named as "[Source] Event Description"
export const UsersApiActions = createActionGroup({
  source: 'Users API',
  events: {
    'Users Loaded Successfully': props<{ users: User[] }>(),
    'Users Loaded Failure': props<{ error: string }>(),
  },
});

export const UsersPageActions = createActionGroup({
  source: 'Users Page',
  events: {
    'Opened': emptyProps(),
    'User Selected': props<{ userId: string }>(),
    'User Deleted': props<{ userId: string }>(),
  },
});

// reducer — pure function, uses entity adapter
export const usersAdapter = createEntityAdapter<User>();
const initialState: UsersState = usersAdapter.getInitialState({
  loading: false,
  error: null,
});

export const usersReducer = createReducer(
  initialState,
  on(UsersPageActions.opened, (state) => ({ ...state, loading: true })),
  on(UsersApiActions.usersLoadedSuccessfully, (state, { users }) =>
    usersAdapter.setAll(users, { ...state, loading: false })
  ),
  on(UsersApiActions.usersLoadedFailure, (state, { error }) => ({
    ...state, loading: false, error,
  })),
  on(UsersPageActions.userDeleted, (state, { userId }) =>
    usersAdapter.removeOne(userId, state)
  )
);
```

### Pattern 2: Effects for Side Effects

```typescript
@Injectable()
export class UsersEffects {
  loadUsers$ = createEffect(() =>
    this.actions$.pipe(
      ofType(UsersPageActions.opened),
      exhaustMap(() =>
        this.usersService.getAll().pipe(
          map(users => UsersApiActions.usersLoadedSuccessfully({ users })),
          catchError(error =>
            of(UsersApiActions.usersLoadedFailure({ error: error.message }))
          )
        )
      )
    )
  );

  constructor(
    private actions$: Actions,
    private usersService: UsersService
  ) {}
}
```

### Pattern 3: Composed Selectors

```typescript
const selectUsersState = createFeatureSelector<UsersState>('users');
const { selectAll, selectEntities } = usersAdapter.getSelectors();

export const selectAllUsers = createSelector(selectUsersState, selectAll);
export const selectUsersLoading = createSelector(selectUsersState, s => s.loading);
export const selectUsersError = createSelector(selectUsersState, s => s.error);

// Composed selector — memoized, only recomputes when inputs change
export const selectActiveUsers = createSelector(
  selectAllUsers,
  (users) => users.filter(u => u.active)
);

export const selectUserById = (id: string) =>
  createSelector(selectUsersState, (state) =>
    selectEntities(state)[id]
  );
```

## Anti-Patterns

- **Command-style actions**: Actions like `loadUsers` (imperative) instead of `UsersPageActions.opened` (event). Actions describe what happened, not what should happen.
- **Business logic in effects**: Effects should orchestrate, not compute. Put transformation logic in reducers or utility functions.
- **Subscribing to store in effects to get state**: Use `concatLatestFrom` (or `withLatestFrom`) instead of injecting the store and subscribing manually.
- **Deeply nested state**: Normalize entities with `createEntityAdapter` instead of nesting arrays inside objects.
- **Selectors without memoization**: Writing plain functions to derive state bypasses memoization. Always use `createSelector`.

## Integration Points

- **Angular Components**: Smart components dispatch actions on user events and select state via selectors (see `angular-patterns.md`).
- **RxJS**: Effects are observable pipelines; see `rxjs-patterns.md` for operator choices in effects.
- **Router Store**: `@ngrx/router-store` syncs route params into the store so selectors can derive route-dependent state.
- **Entity Adapter**: Normalizes collections and provides CRUD operations on entity state.
