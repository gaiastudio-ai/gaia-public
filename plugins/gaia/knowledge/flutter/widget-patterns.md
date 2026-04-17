---
name: Flutter Widget Patterns
stack: flutter
version: "1.0"
focus: [flutter]
---

# Flutter Widget Patterns

## Principle

Build UIs through small, composable widgets. Use `const` constructors wherever possible to enable framework-level render optimization. Understand the widget-element-renderobject tree to make informed decisions about when to split widgets, use keys, and optimize rebuilds.

## Rationale

Flutter rebuilds widgets frequently. The framework diffs the widget tree and only updates elements whose configuration changed. `const` widgets are canonicalized at compile time, so the framework skips diffing them entirely. Splitting large build methods into smaller widgets gives Flutter finer granularity for selective rebuilds, and `Key` objects ensure correct element reuse when lists reorder.

## Pattern Examples

### Pattern 1: Const Constructors and Widget Extraction

```dart
// Good: const constructor enables compile-time canonicalization
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// Usage with const — Flutter skips rebuild entirely
const StatusBadge(label: 'Active', color: Colors.green);
```

### Pattern 2: Keys for List Reordering

```dart
class TodoList extends StatelessWidget {
  const TodoList({super.key, required this.items});
  final List<TodoItem> items;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        // ValueKey ensures correct element reuse when items reorder
        return Dismissible(
          key: ValueKey(item.id),
          onDismissed: (_) => context.read<TodoCubit>().remove(item.id),
          child: TodoTile(item: item),
        );
      },
    );
  }
}
```

### Pattern 3: Custom Widget with Composition

```dart
class UserCard extends StatelessWidget {
  const UserCard({
    super.key,
    required this.user,
    this.onTap,
    this.trailing,
  });

  final User user;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(backgroundImage: NetworkImage(user.avatarUrl)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name, style: theme.textTheme.titleMedium),
                    Text(user.email, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}
```

## Anti-Patterns

- **Mega build methods**: A single `build()` with 200+ lines. Extract sub-widgets so Flutter can selectively rebuild.
- **Missing const**: Omitting `const` on constructors and widget instantiations wastes the canonicalization optimization.
- **Using `GlobalKey` for everything**: `GlobalKey` is expensive; prefer `ValueKey` or `ObjectKey` for list items.
- **Rebuilding the entire tree on state change**: Not splitting stateful and stateless parts. Place `StatefulWidget` at the narrowest scope possible.

## Integration Points

- **State Management**: Widgets consume state from BLoC/Cubit/Provider; see `state-management.md`.
- **Platform Channels**: Custom widgets may wrap platform-specific views; see `platform-channels.md`.
- **Dart Conventions**: Follow `const` and null-safety patterns from `dart-conventions.md`.
- **Theme**: Access `Theme.of(context)` for consistent styling; define tokens in `ThemeData`.
