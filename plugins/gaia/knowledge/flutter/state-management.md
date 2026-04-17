---
name: Flutter State Management
stack: flutter
version: "1.0"
focus: [flutter]
---

# Flutter State Management

## Principle

Choose the state management approach that matches the complexity of the state being managed. Use `setState` for local ephemeral state, `Provider`/`Riverpod` for simple shared state, and BLoC/Cubit for complex business logic with well-defined state transitions. Never mix approaches arbitrarily within the same feature.

## Rationale

Flutter has no single "right" state management solution. The key is matching the tool to the problem. `setState` is perfect for UI-only state (tab index, animation). Provider offers simple dependency injection and reactive rebuilds. Riverpod improves on Provider with compile-time safety and no `BuildContext` dependency. BLoC enforces a strict event-driven architecture ideal for complex flows with testable state transitions.

## Pattern Examples

### Pattern 1: BLoC/Cubit Pattern

```dart
// State definition — sealed class for exhaustive matching
sealed class AuthState {}
class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}
class AuthAuthenticated extends AuthState {
  final User user;
  AuthAuthenticated(this.user);
}
class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}

// Cubit — simpler than full BLoC when events aren't needed
class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._authRepo) : super(AuthInitial());
  final AuthRepository _authRepo;

  Future<void> signIn(String email, String password) async {
    emit(AuthLoading());
    try {
      final user = await _authRepo.signIn(email, password);
      emit(AuthAuthenticated(user));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> signOut() async {
    await _authRepo.signOut();
    emit(AuthInitial());
  }
}

// Widget consumption
BlocBuilder<AuthCubit, AuthState>(
  builder: (context, state) => switch (state) {
    AuthInitial() => const LoginForm(),
    AuthLoading() => const CircularProgressIndicator(),
    AuthAuthenticated(:final user) => HomeScreen(user: user),
    AuthError(:final message) => ErrorView(message: message),
  },
);
```

### Pattern 2: Riverpod with AsyncNotifier

```dart
// Provider definition — no BuildContext needed
@riverpod
class TodoList extends _$TodoList {
  @override
  Future<List<Todo>> build() async {
    return ref.read(todoRepositoryProvider).fetchAll();
  }

  Future<void> addTodo(String title) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(todoRepositoryProvider).add(title);
      return ref.read(todoRepositoryProvider).fetchAll();
    });
  }
}

// Widget consumption
class TodoScreen extends ConsumerWidget {
  const TodoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todosAsync = ref.watch(todoListProvider);
    return todosAsync.when(
      data: (todos) => TodoListView(todos: todos),
      loading: () => const CircularProgressIndicator(),
      error: (err, stack) => ErrorView(message: err.toString()),
    );
  }
}
```

### Pattern 3: Provider for Simple DI

```dart
// Simple shared state with ChangeNotifier
class CartModel extends ChangeNotifier {
  final List<Product> _items = [];
  List<Product> get items => List.unmodifiable(_items);
  double get total => _items.fold(0, (sum, p) => sum + p.price);

  void add(Product product) {
    _items.add(product);
    notifyListeners();
  }

  void remove(String productId) {
    _items.removeWhere((p) => p.id == productId);
    notifyListeners();
  }
}

// Provided at app root
ChangeNotifierProvider(create: (_) => CartModel(), child: const MyApp());

// Consumed
final cart = context.watch<CartModel>();
Text('Total: \$${cart.total.toStringAsFixed(2)}');
```

## Anti-Patterns

- **Global state for everything**: Using BLoC for toggle buttons or tab indices. Use `setState` for ephemeral UI state.
- **Mixing approaches randomly**: Using Provider in one feature, BLoC in another, and Riverpod in a third within the same app.
- **Fat BLoCs**: Putting UI formatting logic in BLoC. BLoC handles business logic; the widget formats display.
- **Not sealing state classes**: Using abstract base class without sealed means the compiler cannot check exhaustiveness in switch statements.

## Integration Points

- **Widgets**: State is consumed in the widget layer via `BlocBuilder`, `Consumer`, or `context.watch`; see `widget-patterns.md`.
- **Platform Channels**: Async platform calls feed into state management layer; see `platform-channels.md`.
- **Testing**: Cubits and Notifiers are plain Dart classes, easily testable without Flutter test harness.
- **Navigation**: State transitions (authenticated/unauthenticated) drive route guards.
