---
name: RxJS Observable Patterns
stack: angular
version: "1.0"
focus: [rxjs]
---

# RxJS Observable Patterns

## Principle

Use RxJS observables as the primary mechanism for managing asynchronous data flows. Choose operators deliberately based on the concurrency semantics required (switch, merge, concat, exhaust). Always manage subscription lifecycle to prevent memory leaks.

## Rationale

RxJS provides a composable, declarative approach to async operations. Choosing the right flattening operator prevents subtle bugs: `switchMap` cancels prior requests (ideal for search), `concatMap` queues them (ideal for ordered writes), `mergeMap` runs concurrently, and `exhaustMap` ignores new emissions while one is active (ideal for form submissions). Proper subscription management is critical because Angular components are created and destroyed frequently.

## Pattern Examples

### Pattern 1: Type-Ahead Search with switchMap

```typescript
@Component({ /* ... */ })
export class SearchComponent implements OnInit, OnDestroy {
  searchControl = new FormControl('');
  results$!: Observable<SearchResult[]>;
  private destroy$ = new Subject<void>();

  constructor(private searchService: SearchService) {}

  ngOnInit(): void {
    this.results$ = this.searchControl.valueChanges.pipe(
      debounceTime(300),
      distinctUntilChanged(),
      filter((term): term is string => term !== null && term.length >= 2),
      switchMap(term => this.searchService.search(term).pipe(
        catchError(() => of([]))  // Recover per-request, not globally
      )),
      takeUntil(this.destroy$)
    );
  }

  ngOnDestroy(): void {
    this.destroy$.next();
    this.destroy$.complete();
  }
}
```

### Pattern 2: Combining Multiple Streams

```typescript
export class DashboardComponent implements OnInit {
  vm$!: Observable<DashboardViewModel>;

  ngOnInit(): void {
    this.vm$ = combineLatest([
      this.store.select(selectUser),
      this.store.select(selectNotifications),
      this.store.select(selectMetrics),
    ]).pipe(
      map(([user, notifications, metrics]) => ({
        user,
        notifications,
        metrics,
        hasUnread: notifications.some(n => !n.read),
      }))
    );
  }
}

// Template: single async pipe, one subscription
// <ng-container *ngIf="vm$ | async as vm">
//   <app-header [user]="vm.user" [unread]="vm.hasUnread" />
//   <app-metrics [data]="vm.metrics" />
// </ng-container>
```

### Pattern 3: Retry with Exponential Backoff

```typescript
export function retryWithBackoff<T>(
  maxRetries = 3,
  delayMs = 1000
): MonoTypeOperatorFunction<T> {
  return (source: Observable<T>) =>
    source.pipe(
      retry({
        count: maxRetries,
        delay: (error, retryCount) => {
          const backoff = delayMs * Math.pow(2, retryCount - 1);
          console.warn(`Retry #${retryCount} in ${backoff}ms`, error.message);
          return timer(backoff);
        },
      })
    );
}

// Usage
this.http.get<Data[]>('/api/data').pipe(
  retryWithBackoff(3, 500),
  catchError(() => of([]))
);
```

## Anti-Patterns

- **Nested subscriptions**: Never subscribe inside a subscribe callback; use flattening operators (`switchMap`, `mergeMap`, etc.) instead.
- **Forgetting to unsubscribe**: Every manual `.subscribe()` in a component must be cleaned up via `takeUntil`, `DestroyRef`, or the `async` pipe.
- **Using `mergeMap` for search**: `mergeMap` does not cancel prior emissions; race conditions will show stale results. Use `switchMap`.
- **Catching errors at the top level**: Placing `catchError` outside the inner observable kills the outer stream on first error.
- **Subscribing multiple times to the same HTTP call**: HTTP observables are cold; each subscription triggers a new request. Use `shareReplay(1)` when sharing.

## Integration Points

- **Angular HttpClient**: Returns cold observables; combine with RxJS operators for caching, retry, and transformation.
- **NgRx Effects**: Effects are observable streams that listen to actions and dispatch new actions; see `ngrx-state.md`.
- **Angular Forms**: `valueChanges` and `statusChanges` are observables on reactive form controls.
- **Component lifecycle**: Tie subscriptions to `OnDestroy` via the `destroy$` pattern or Angular 16+ `DestroyRef`.
