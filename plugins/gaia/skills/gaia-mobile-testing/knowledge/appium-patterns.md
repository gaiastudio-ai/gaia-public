---
name: appium-patterns
tier: mobile-testing
version: '1.0'
---

# Appium Patterns

## Principle

Appium provides cross-platform mobile test automation using the WebDriver protocol.
Write tests once against a standard API, then run them on iOS and Android with
platform-specific capabilities. The Page Object Model keeps tests maintainable
as the app evolves.

## Rationale

Native mobile apps have platform-specific UI frameworks (UIKit, Jetpack Compose) that
require different automation approaches. Appium abstracts these differences behind a
unified API, enabling shared test logic with platform-specific configuration. This
reduces maintenance overhead for cross-platform apps.

## Pattern Examples

### Desired Capabilities

```javascript
// Android
const androidCaps = {
  platformName: 'Android',
  'appium:automationName': 'UiAutomator2',
  'appium:deviceName': 'Pixel 6',
  'appium:platformVersion': '13',
  'appium:app': '/path/to/app.apk',
  'appium:noReset': false,
};

// iOS
const iosCaps = {
  platformName: 'iOS',
  'appium:automationName': 'XCUITest',
  'appium:deviceName': 'iPhone 14',
  'appium:platformVersion': '16.4',
  'appium:app': '/path/to/app.ipa',
  'appium:noReset': false,
};
```

### Element Location Strategies

```javascript
// Accessibility ID — preferred, cross-platform
const loginButton = await driver.$('~login-button');

// Resource ID (Android)
const emailField = await driver.$('android=new UiSelector().resourceId("email-input")');

// iOS predicate
const submitBtn = await driver.$('-ios predicate string:name == "Submit"');

// XPath — last resort, fragile
const header = await driver.$('//android.widget.TextView[@text="Welcome"]');
```

### Page Object Model

```typescript
class LoginPage {
  get emailInput() { return $('~email-input'); }
  get passwordInput() { return $('~password-input'); }
  get loginButton() { return $('~login-button'); }
  get errorMessage() { return $('~error-message'); }

  async login(email: string, password: string) {
    await this.emailInput.setValue(email);
    await this.passwordInput.setValue(password);
    await this.loginButton.click();
  }

  async getErrorText(): Promise<string> {
    await this.errorMessage.waitForDisplayed({ timeout: 5000 });
    return this.errorMessage.getText();
  }
}
```

### Wait Strategies

```javascript
// Explicit wait — preferred
await driver.waitUntil(
  async () => (await $('~dashboard-title')).isDisplayed(),
  { timeout: 10000, timeoutMsg: 'Dashboard did not load' }
);

// Element wait
const element = await $('~loading-spinner');
await element.waitForDisplayed({ timeout: 5000, reverse: true }); // wait to disappear
```

### Gesture Automation

```javascript
// Swipe
await driver.execute('mobile: swipe', { direction: 'up', element: listView.elementId });

// Long press
await driver.execute('mobile: longClickGesture', {
  elementId: item.elementId,
  duration: 2000,
});

// Scroll to element
await driver.execute('mobile: scroll', {
  strategy: 'accessibility id',
  selector: 'target-element',
});
```

### Device Farm Integration

```javascript
// BrowserStack
const bsCaps = {
  'bstack:options': {
    projectName: 'MyApp Tests',
    buildName: `Build ${process.env.BUILD_NUMBER}`,
    deviceName: 'Samsung Galaxy S22',
    osVersion: '12.0',
  },
};

// SauceLabs
const sauceCaps = {
  'sauce:options': {
    appiumVersion: '2.0',
    deviceName: 'Google Pixel 6',
    platformVersion: '13',
  },
};
```

## Anti-Patterns

1. **XPath-first selectors** — XPath is slow and fragile. Use accessibility IDs
   as the primary locator strategy; they survive UI restructuring.

2. **Implicit waits** — Global implicit waits mask timing issues and slow down
   failure detection. Use explicit waits targeted to specific elements.

3. **Hardcoded sleep** — `Thread.sleep(5000)` is always wrong. Use waitUntil
   with a meaningful condition and timeout.

4. **Platform-coupled tests** — Writing separate test suites for iOS and Android
   when 90% of the logic is identical. Share test logic, isolate capabilities.

5. **Ignoring app state** — Not resetting app state between tests causes cascading
   failures. Use `noReset: false` or explicit cleanup.

## Integration Points

- **Tools**: Appium Server 2.x, UiAutomator2 (Android), XCUITest (iOS)
- **Workflows**: `mobile-testing` (test plan), `test-automation` (coverage expansion)
- **Related fragments**: `selector-resilience` (locator strategies)
