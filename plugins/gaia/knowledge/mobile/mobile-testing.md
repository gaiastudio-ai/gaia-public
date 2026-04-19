---
name: Mobile Testing Strategies
stack: mobile
version: "1.0"
focus: [mobile-testing]
---

# Mobile Testing Strategies

## Principle

Test mobile apps at three levels: unit tests for business logic, component/widget tests for UI rendering, and end-to-end tests for critical user flows. Use platform-specific tools (XCTest, Espresso, Detox) for E2E, and cross-platform tools (Jest, flutter_test) for unit and component layers. Include screenshot testing to catch visual regressions across devices and OS versions.

## Rationale

Mobile apps run on diverse hardware (screen sizes, OS versions, chipsets) and are distributed as immutable binaries that cannot be hotfixed. This makes pre-release testing critical. Unit tests verify logic without simulators/emulators and run in seconds. Component tests verify UI rendering and interaction in isolation. E2E tests validate real user flows but are slower and flakier, so they should cover only critical paths. Screenshot testing catches subtle visual regressions that functional tests miss.

## Pattern Examples

### Pattern 1: React Native Testing with Detox

```typescript
// e2e/login.test.ts — Detox E2E test
describe('Login Flow', () => {
  beforeAll(async () => {
    await device.launchApp({ newInstance: true });
  });

  beforeEach(async () => {
    await device.reloadReactNative();
  });

  it('should log in with valid credentials', async () => {
    await element(by.id('email-input')).typeText('user@example.com');
    await element(by.id('password-input')).typeText('password123');
    await element(by.id('login-button')).tap();

    // Wait for navigation to complete
    await waitFor(element(by.id('home-screen')))
      .toBeVisible()
      .withTimeout(5000);

    await expect(element(by.text('Welcome back'))).toBeVisible();
  });

  it('should show error for invalid credentials', async () => {
    await element(by.id('email-input')).typeText('wrong@example.com');
    await element(by.id('password-input')).typeText('wrong');
    await element(by.id('login-button')).tap();

    await waitFor(element(by.id('error-message')))
      .toBeVisible()
      .withTimeout(3000);

    await expect(element(by.text('Invalid credentials'))).toBeVisible();
  });
});

// Component test with React Native Testing Library
import { render, fireEvent, waitFor } from '@testing-library/react-native';

test('LoginForm calls onSubmit with email and password', async () => {
  const onSubmit = jest.fn();
  const { getByTestId } = render(<LoginForm onSubmit={onSubmit} />);

  fireEvent.changeText(getByTestId('email-input'), 'user@example.com');
  fireEvent.changeText(getByTestId('password-input'), 'password123');
  fireEvent.press(getByTestId('login-button'));

  await waitFor(() => {
    expect(onSubmit).toHaveBeenCalledWith({
      email: 'user@example.com',
      password: 'password123',
    });
  });
});
```

### Pattern 2: iOS Testing with XCTest

```swift
// Unit test — pure logic, no UI
class UserServiceTests: XCTestCase {
    var sut: UserService!
    var mockRepository: MockUserRepository!

    override func setUp() {
        super.setUp()
        mockRepository = MockUserRepository()
        sut = UserService(repository: mockRepository)
    }

    func testFetchUsersReturnsUsers() async throws {
        mockRepository.stubbedUsers = [
            User(id: "1", name: "Alice", email: "alice@test.com"),
        ]

        let users = try await sut.fetchAll()

        XCTAssertEqual(users.count, 1)
        XCTAssertEqual(users.first?.name, "Alice")
    }
}

// UI test with XCUITest
class LoginUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    func testSuccessfulLogin() {
        let emailField = app.textFields["email-field"]
        let passwordField = app.secureTextFields["password-field"]
        let loginButton = app.buttons["login-button"]

        emailField.tap()
        emailField.typeText("user@example.com")
        passwordField.tap()
        passwordField.typeText("password123")
        loginButton.tap()

        let homeScreen = app.staticTexts["Welcome back"]
        XCTAssertTrue(homeScreen.waitForExistence(timeout: 5))
    }
}
```

### Pattern 3: Screenshot Testing

```kotlin
// Android — Compose screenshot test (Roborazzi)
@RunWith(ParameterizedRobolectricTestRunner::class)
class UserCardScreenshotTest(
    private val config: ScreenConfig,
) {
    @get:Rule
    val composeTestRule = createComposeRule()

    @Test
    fun userCard_default() {
        composeTestRule.setContent {
            AppTheme {
                UserCard(
                    user = User(
                        name = "Alice Johnson",
                        email = "alice@example.com",
                        avatarUrl = null,
                    ),
                )
            }
        }
        composeTestRule.onRoot()
            .captureRoboImage("screenshots/user_card_${config.name}.png")
    }

    companion object {
        @JvmStatic
        @ParameterizedRobolectricTestRunner.Parameters(name = "{0}")
        fun configs() = listOf(
            ScreenConfig("phone", 360, 640, 2f),
            ScreenConfig("tablet", 800, 1280, 2f),
            ScreenConfig("phone_large_font", 360, 640, 2f, fontScale = 1.5f),
        )
    }
}
```

## Anti-Patterns

- **E2E tests for everything**: E2E tests are slow and flaky. Use them only for critical user flows (login, checkout, onboarding). Test business logic with unit tests.
- **No testIDs on interactive elements**: Without accessibility IDs (`testID` in RN, `accessibilityIdentifier` in iOS), E2E tests rely on fragile text matchers.
- **Testing implementation details**: Testing internal state or private methods couples tests to implementation. Test behavior and outputs.
- **Skipping device matrix testing**: Testing only on one device/OS version misses platform-specific rendering bugs.
- **No screenshot baseline management**: Screenshot tests without proper baseline storage and diff tooling generate false positives.

## Integration Points

- **React Native**: Detox and RNTL for cross-platform testing; see `react-native-patterns.md`.
- **Swift**: XCTest and XCUITest for iOS; see `swift-patterns.md`.
- **Kotlin**: JUnit, Compose Test, and Espresso for Android; see `kotlin-patterns.md`.
- **CI/CD**: Run unit/component tests on every PR; E2E tests nightly or on release branches.
