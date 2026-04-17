---
name: Angular Component Patterns
stack: angular
version: "1.0"
focus: [angular]
---

# Angular Component Patterns

## Principle

Design components using a strict smart/dumb (container/presentational) separation. Smart components manage state and orchestrate logic; dumb components receive data via `@Input()` and emit events via `@Output()`. This maximizes reusability, testability, and change detection efficiency.

## Rationale

Angular's change detection traverses the component tree on every cycle. By isolating side effects and state management into container components, presentational components can use `OnPush` change detection, dramatically reducing unnecessary re-renders. This architecture also makes unit testing straightforward since presentational components are pure functions of their inputs.

## Pattern Examples

### Pattern 1: Smart/Dumb Component Separation

```typescript
// Smart (container) component — manages state, injects services
@Component({
  selector: 'app-user-list-page',
  template: `
    <app-user-list
      [users]="users$ | async"
      [loading]="loading$ | async"
      (userSelected)="onUserSelected($event)"
    />
  `,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class UserListPageComponent {
  users$ = this.store.select(selectAllUsers);
  loading$ = this.store.select(selectUsersLoading);

  constructor(private store: Store) {
    this.store.dispatch(loadUsers());
  }

  onUserSelected(user: User): void {
    this.store.dispatch(selectUser({ userId: user.id }));
  }
}

// Dumb (presentational) component — pure inputs/outputs
@Component({
  selector: 'app-user-list',
  templateUrl: './user-list.component.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class UserListComponent {
  @Input() users: User[] = [];
  @Input() loading = false;
  @Output() userSelected = new EventEmitter<User>();
}
```

### Pattern 2: Lifecycle Hooks with Cleanup

```typescript
@Component({
  selector: 'app-dashboard',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class DashboardComponent implements OnInit, OnDestroy {
  private destroy$ = new Subject<void>();

  ngOnInit(): void {
    this.dataService.getMetrics()
      .pipe(takeUntil(this.destroy$))
      .subscribe(metrics => this.updateChart(metrics));
  }

  ngOnDestroy(): void {
    this.destroy$.next();
    this.destroy$.complete();
  }
}
```

### Pattern 3: Content Projection for Flexible Layout

```typescript
@Component({
  selector: 'app-card',
  template: `
    <div class="card">
      <div class="card-header">
        <ng-content select="[card-title]" />
      </div>
      <div class="card-body">
        <ng-content />
      </div>
      <div class="card-footer">
        <ng-content select="[card-actions]" />
      </div>
    </div>
  `,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class CardComponent {}

// Usage
// <app-card>
//   <h2 card-title>Title</h2>
//   <p>Body content here</p>
//   <button card-actions>Save</button>
// </app-card>
```

## Anti-Patterns

- **God components**: Components that fetch data, transform it, and render complex templates. Split into smart + dumb.
- **Default change detection everywhere**: Leaving `ChangeDetectionStrategy.Default` on presentational components wastes cycles.
- **Direct DOM manipulation**: Using `document.querySelector` instead of `@ViewChild` or `Renderer2` breaks SSR and testability.
- **Subscribing in templates without `async` pipe**: Manual subscriptions in component classes without proper cleanup cause memory leaks.

## Integration Points

- **NgRx Store**: Smart components dispatch actions and select state via the store (see `ngrx-state.md`).
- **RxJS**: Observable streams power async data flow; see `rxjs-patterns.md` for operator guidance.
- **Angular Router**: Smart components often live at route boundaries; dumb components are nested within.
- **Angular CDK**: Use CDK primitives (overlay, drag-drop, virtual scroll) inside presentational components for complex UI behavior.
