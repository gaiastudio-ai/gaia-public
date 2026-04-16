---
name: react-native-testing
tier: mobile-testing
version: '1.0'
---

# React Native Testing

## Principle

React Native testing follows the same test pyramid as web React: Jest for unit tests,
React Native Testing Library for component tests, and Detox for E2E. Native modules
require mocking, but the core testing philosophy — test behavior, not implementation
— remains identical.

## Rationale

React Native bridges JavaScript and native code, creating unique testing challenges.
Native modules, platform-specific behavior, and navigation require careful mocking
strategies. Detox provides gray-box E2E testing that synchronizes with the app's
internal state, reducing flakiness.

## Pattern Examples

### Jest + React Native Testing Library

```typescript
import { render, screen, fireEvent } from '@testing-library/react-native';
import { ProfileCard } from './ProfileCard';

describe('ProfileCard', () => {
  it('displays user information', () => {
    render(<ProfileCard name="Alice" email="alice@example.com" />);

    expect(screen.getByText('Alice')).toBeTruthy();
    expect(screen.getByText('alice@example.com')).toBeTruthy();
  });

  it('calls onPress when tapped', () => {
    const onPress = jest.fn();
    render(<ProfileCard name="Alice" email="alice@example.com" onPress={onPress} />);

    fireEvent.press(screen.getByText('Alice'));
    expect(onPress).toHaveBeenCalledTimes(1);
  });
});
```

### Navigation Testing

```typescript
import { NavigationContainer } from '@react-navigation/native';
import { render, screen, fireEvent } from '@testing-library/react-native';

function renderWithNavigation(component: React.ReactElement) {
  return render(
    <NavigationContainer>{component}</NavigationContainer>
  );
}

describe('AppNavigator', () => {
  it('navigates to profile on tab press', () => {
    renderWithNavigation(<AppNavigator />);
    fireEvent.press(screen.getByText('Profile'));
    expect(screen.getByText('Profile Settings')).toBeTruthy();
  });
});
```

### Native Module Mocking

```typescript
// jest/setup.ts — mock native modules globally
jest.mock('react-native/Libraries/Animated/NativeAnimatedHelper');

jest.mock('@react-native-async-storage/async-storage', () =>
  require('@react-native-async-storage/async-storage/jest/async-storage-mock')
);

jest.mock('react-native-camera', () => ({
  RNCamera: {
    Constants: {
      Type: { back: 'back', front: 'front' },
      FlashMode: { on: 'on', off: 'off', auto: 'auto' },
    },
  },
}));

// Platform-specific mock
jest.mock('react-native/Libraries/Utilities/Platform', () => ({
  OS: 'ios',
  select: (obj: any) => obj.ios,
}));
```

### Detox E2E Setup

```javascript
// .detoxrc.js
module.exports = {
  testRunner: { args: { config: 'e2e/jest.config.js' } },
  apps: {
    'ios.release': {
      type: 'ios.app',
      binaryPath: 'ios/build/MyApp.app',
      build: 'xcodebuild -workspace ios/MyApp.xcworkspace -scheme MyApp -configuration Release -sdk iphonesimulator',
    },
    'android.release': {
      type: 'android.apk',
      binaryPath: 'android/app/build/outputs/apk/release/app-release.apk',
      build: 'cd android && ./gradlew assembleRelease',
    },
  },
  devices: {
    simulator: { type: 'ios.simulator', device: { type: 'iPhone 15' } },
    emulator: { type: 'android.emulator', device: { avdName: 'Pixel_6_API_33' } },
  },
};
```

### Detox E2E Tests

```typescript
describe('Login Flow', () => {
  beforeAll(async () => {
    await device.launchApp({ newInstance: true });
  });

  beforeEach(async () => {
    await device.reloadReactNative();
  });

  it('logs in with valid credentials', async () => {
    await element(by.id('email-input')).typeText('user@example.com');
    await element(by.id('password-input')).typeText('password123');
    await element(by.id('login-button')).tap();

    await waitFor(element(by.id('dashboard-screen')))
      .toBeVisible()
      .withTimeout(5000);
  });

  it('shows error for invalid credentials', async () => {
    await element(by.id('email-input')).typeText('wrong@example.com');
    await element(by.id('password-input')).typeText('wrong');
    await element(by.id('login-button')).tap();

    await expect(element(by.text('Invalid credentials'))).toBeVisible();
  });
});
```

### Snapshot Testing for Components

```typescript
import { render } from '@testing-library/react-native';
import { Button } from './Button';

describe('Button snapshots', () => {
  it('renders primary variant', () => {
    const tree = render(<Button variant="primary" title="Submit" />);
    expect(tree.toJSON()).toMatchSnapshot();
  });

  it('renders disabled state', () => {
    const tree = render(<Button variant="primary" title="Submit" disabled />);
    expect(tree.toJSON()).toMatchSnapshot();
  });
});
```

## Anti-Patterns

1. **Not mocking native modules** — Unmocked native modules crash Jest. Set up
   comprehensive mocks in jest/setup.ts for all native dependencies.

2. **Testing styles directly** — Asserting on style objects is brittle. Test visual
   outcomes with snapshots or accessibility labels instead.

3. **Ignoring platform differences** — Platform.select branches need testing on
   both platforms. Use parameterized tests with platform mocks.

4. **Detox without synchronization** — Not waiting for animations or network calls
   to complete before assertions. Use waitFor patterns.

5. **Over-relying on snapshots** — Large component tree snapshots are unreviewed noise.
   Use targeted snapshots for small, stable components only.

## Integration Points

- **Tools**: Jest, RNTL, Detox, Metro bundler
- **Workflows**: `mobile-testing` (test plan), `test-framework` (initial setup)
- **Related fragments**: `jest-vitest-patterns` (shared Jest patterns)
