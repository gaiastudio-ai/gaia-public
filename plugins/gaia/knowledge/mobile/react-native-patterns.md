---
name: React Native Application Patterns
stack: mobile
version: "1.0"
focus: [react-native]
---

# React Native Application Patterns

## Principle

Build cross-platform mobile apps with React Native using platform-aware component composition, optimized list rendering with `FlatList`, and React Navigation for type-safe navigation. Use the Hermes engine for improved startup performance and the new architecture (Fabric, TurboModules) for better native interop.

## Rationale

React Native bridges JavaScript and native platforms, so performance-sensitive code must account for the bridge overhead. `FlatList` virtualizes long lists, rendering only visible items. React Navigation provides a native-feeling navigation experience with proper gesture handling. Hermes (default since RN 0.70) pre-compiles JavaScript to bytecode, reducing TTI by 30-50%. The new architecture eliminates the async bridge bottleneck with synchronous native calls.

## Pattern Examples

### Pattern 1: Optimized FlatList with Memoized Items

```typescript
interface Message {
  id: string;
  text: string;
  sender: string;
  timestamp: number;
}

const MessageItem = memo(function MessageItem({
  item,
  onPress,
}: {
  item: Message;
  onPress: (id: string) => void;
}) {
  const handlePress = useCallback(() => onPress(item.id), [item.id, onPress]);

  return (
    <Pressable onPress={handlePress} style={styles.messageItem}>
      <Text style={styles.sender}>{item.sender}</Text>
      <Text style={styles.text}>{item.text}</Text>
    </Pressable>
  );
});

function MessageList({ messages }: { messages: Message[] }) {
  const handlePress = useCallback((id: string) => {
    // Handle message press
  }, []);

  const renderItem = useCallback(
    ({ item }: { item: Message }) => (
      <MessageItem item={item} onPress={handlePress} />
    ),
    [handlePress]
  );

  const keyExtractor = useCallback((item: Message) => item.id, []);

  return (
    <FlatList
      data={messages}
      renderItem={renderItem}
      keyExtractor={keyExtractor}
      initialNumToRender={15}
      maxToRenderPerBatch={10}
      windowSize={5}
      removeClippedSubviews
      getItemLayout={(_, index) => ({
        length: ITEM_HEIGHT,
        offset: ITEM_HEIGHT * index,
        index,
      })}
    />
  );
}
```

### Pattern 2: Type-Safe React Navigation

```typescript
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';

// Define all route params in one place
type RootStackParamList = {
  Auth: undefined;
  Main: undefined;
};

type MainTabParamList = {
  Home: undefined;
  Profile: { userId: string };
  Settings: undefined;
};

type HomeStackParamList = {
  Feed: undefined;
  PostDetail: { postId: string };
};

const RootStack = createNativeStackNavigator<RootStackParamList>();
const MainTab = createBottomTabNavigator<MainTabParamList>();
const HomeStack = createNativeStackNavigator<HomeStackParamList>();

// Type-safe navigation in components
import { NativeStackScreenProps } from '@react-navigation/native-stack';

type PostDetailProps = NativeStackScreenProps<HomeStackParamList, 'PostDetail'>;

function PostDetailScreen({ route, navigation }: PostDetailProps) {
  const { postId } = route.params;  // TypeScript knows postId is string
  // navigation.navigate('Feed') works; navigate('Invalid') is a type error
  return <PostView postId={postId} />;
}
```

### Pattern 3: Platform-Specific Code

```typescript
import { Platform, StyleSheet } from 'react-native';

// Platform-specific styling
const styles = StyleSheet.create({
  shadow: Platform.select({
    ios: {
      shadowColor: '#000',
      shadowOffset: { width: 0, height: 2 },
      shadowOpacity: 0.1,
      shadowRadius: 4,
    },
    android: {
      elevation: 4,
    },
    default: {},
  })!,
  container: {
    paddingTop: Platform.OS === 'ios' ? 44 : 0,
  },
});

// Platform-specific files (RN resolves automatically)
// DatePicker.ios.tsx  — uses native iOS date picker
// DatePicker.android.tsx — uses Android material date picker
// DatePicker.tsx — fallback / web
```

## Anti-Patterns

- **ScrollView for long lists**: `ScrollView` renders all children at once. Use `FlatList` or `SectionList` for lists with more than ~20 items.
- **Inline styles and functions in render**: Creating new objects and functions on every render defeats `memo`. Extract to `StyleSheet.create` and `useCallback`.
- **Ignoring Hermes**: Not enabling Hermes (or using an old RN version without it) wastes 30-50% startup performance.
- **Untyped navigation**: Using `navigation.navigate('Screen')` without type definitions. Type your param lists for compile-time safety.

## Integration Points

- **Swift/Kotlin**: Native modules bridge platform APIs; see `swift-patterns.md` and `kotlin-patterns.md`.
- **Testing**: See `mobile-testing.md` for Detox E2E and component testing strategies.
- **React Patterns**: Core React hooks and component patterns apply; see `react-patterns.md` (typescript stack).
- **State Management**: Use Zustand, Redux Toolkit, or React Query for state; principles from `react-patterns.md` apply.
