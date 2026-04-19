---
name: Dart Language Conventions
stack: flutter
version: "1.0"
focus: [dart]
---

# Dart Language Conventions

## Principle

Follow Effective Dart guidelines: embrace null safety, use strong typing with type inference where clear, prefer immutable data, and use `async`/`await` over raw `Future` chains. Write code that reads like well-structured prose, using Dart's expressive syntax features (cascades, collection literals, extension methods).

## Rationale

Dart's sound null safety eliminates entire categories of runtime errors at compile time. Type inference reduces verbosity without sacrificing safety. Extension methods add functionality to types without modifying them, keeping code modular. Consistent adherence to Effective Dart conventions ensures that code is idiomatic, readable, and maintainable across teams.

## Pattern Examples

### Pattern 1: Null Safety and Smart Typing

```dart
// Sound null safety — explicit nullable vs non-nullable
class UserProfile {
  final String name;           // required, never null
  final String? bio;           // optional, may be null
  final DateTime createdAt;

  const UserProfile({
    required this.name,
    this.bio,
    required this.createdAt,
  });

  // Null-aware operators
  String get displayBio => bio ?? 'No bio provided';
  int? get bioLength => bio?.length;  // null if bio is null

  // Pattern matching with null checks (Dart 3)
  String describe() => switch (bio) {
    final b? when b.length > 100 => '${name} has a detailed bio',
    final b? => '${name}: $b',
    null => '${name} (no bio)',
  };
}
```

### Pattern 2: Extension Methods and Typedefs

```dart
// Extension on String for domain-specific logic
extension StringValidation on String {
  bool get isValidEmail =>
      RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(this);

  String get capitalized =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';

  String truncate(int maxLength, {String suffix = '...'}) =>
      length <= maxLength ? this : '${substring(0, maxLength)}$suffix';
}

// Extension on DateTime
extension DateTimeFormat on DateTime {
  String get iso8601Date => toIso8601String().split('T').first;
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }
}

// Typedef for readability
typedef JsonMap = Map<String, dynamic>;
typedef FromJson<T> = T Function(JsonMap json);
```

### Pattern 3: Async/Await Patterns

```dart
// Structured async with error handling
class ApiClient {
  Future<Result<T>> safeRequest<T>(
    Future<T> Function() request,
  ) async {
    try {
      final data = await request();
      return Result.success(data);
    } on SocketException {
      return Result.failure('No internet connection');
    } on TimeoutException {
      return Result.failure('Request timed out');
    } on FormatException catch (e) {
      return Result.failure('Invalid response: ${e.message}');
    }
  }
}

// Result type for explicit error handling
sealed class Result<T> {
  const Result();
  const factory Result.success(T data) = Success;
  const factory Result.failure(String message) = Failure;
}

class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

class Failure<T> extends Result<T> {
  final String message;
  const Failure(this.message);
}

// Parallel async operations
Future<DashboardData> loadDashboard() async {
  final results = await Future.wait([
    fetchUserProfile(),
    fetchNotifications(),
    fetchMetrics(),
  ]);
  return DashboardData(
    profile: results[0] as UserProfile,
    notifications: results[1] as List<Notification>,
    metrics: results[2] as Metrics,
  );
}
```

## Anti-Patterns

- **Using `dynamic` to avoid typing**: Defeats null safety and type checking. Use generics or union types instead.
- **Catching `Exception` generically**: Catch specific exception types for proper error handling.
- **Mutable data classes**: Prefer `final` fields and `const` constructors for value objects. Use `copyWith` for modifications.
- **Ignoring linter rules**: Configure `analysis_options.yaml` with recommended rules and fix all warnings.
- **Nested `.then()` chains**: Use `async`/`await` for readability. Reserve `.then()` only for fire-and-forget scenarios.

## Integration Points

- **Flutter Widgets**: Dart conventions (const, null safety, sealed classes) directly impact widget code; see `widget-patterns.md`.
- **State Management**: Sealed classes and pattern matching define state hierarchies; see `state-management.md`.
- **Platform Channels**: Async/await wraps channel calls; see `platform-channels.md`.
- **Linting**: Use `flutter_lints` or `very_good_analysis` for enforcement.
