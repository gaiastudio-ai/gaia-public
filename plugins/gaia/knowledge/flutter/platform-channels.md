---
name: Flutter Platform Channels
stack: flutter
version: "1.0"
focus: [flutter]
---

# Flutter Platform Channels

## Principle

Use platform channels to bridge Dart and native code (iOS/Android) when Flutter APIs do not cover a native capability. Use `MethodChannel` for request/response calls, `EventChannel` for continuous native-to-Dart streams, and `BasicMessageChannel` for simple bidirectional messaging. Always handle platform exceptions and check platform availability before invoking.

## Rationale

Flutter provides a rich set of plugins, but some features (biometrics, Bluetooth LE, custom camera pipelines, native SDKs) require direct native integration. Platform channels provide a structured, type-safe mechanism for this communication. Proper error handling and platform detection ensure the app degrades gracefully on unsupported platforms.

## Pattern Examples

### Pattern 1: MethodChannel for Native Calls

```dart
// Dart side — request/response pattern
class BatteryService {
  static const _channel = MethodChannel('com.example.app/battery');

  Future<int> getBatteryLevel() async {
    try {
      final int level = await _channel.invokeMethod('getBatteryLevel');
      return level;
    } on PlatformException catch (e) {
      throw BatteryException('Failed to get battery level: ${e.message}');
    }
  }
}

// Android (Kotlin)
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "com.example.app/battery"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getBatteryLevel" -> {
                    val level = getBatteryLevel()
                    if (level != -1) result.success(level)
                    else result.error("UNAVAILABLE", "Battery level unavailable", null)
                }
                else -> result.notImplemented()
            }
        }
    }
}

// iOS (Swift)
@UIApplicationMain
class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let controller = window?.rootViewController as! FlutterViewController
        let channel = FlutterMethodChannel(
            name: "com.example.app/battery",
            binaryMessenger: controller.binaryMessenger
        )
        channel.setMethodCallHandler { call, result in
            guard call.method == "getBatteryLevel" else {
                result(FlutterMethodNotImplemented)
                return
            }
            result(UIDevice.current.batteryLevel * 100)
        }
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
```

### Pattern 2: EventChannel for Streaming Data

```dart
// Dart — continuous stream from native
class AccelerometerService {
  static const _eventChannel = EventChannel('com.example.app/accelerometer');

  Stream<AccelerometerData> get readings {
    return _eventChannel.receiveBroadcastStream().map((event) {
      final map = Map<String, double>.from(event as Map);
      return AccelerometerData(x: map['x']!, y: map['y']!, z: map['z']!);
    });
  }
}

// Consumed in widget
StreamBuilder<AccelerometerData>(
  stream: accelerometerService.readings,
  builder: (context, snapshot) {
    if (!snapshot.hasData) return const Text('Waiting...');
    final data = snapshot.data!;
    return Text('X: ${data.x.toStringAsFixed(2)}');
  },
);
```

### Pattern 3: Platform Detection

```dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class PlatformService {
  static bool get isIOS => !kIsWeb && Platform.isIOS;
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get isMobile => isIOS || isAndroid;
  static bool get isDesktop =>
      !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

  static Future<T> platformSpecific<T>({
    required Future<T> Function() ios,
    required Future<T> Function() android,
    Future<T> Function()? fallback,
  }) async {
    if (isIOS) return ios();
    if (isAndroid) return android();
    if (fallback != null) return fallback();
    throw UnsupportedError('Platform not supported');
  }
}
```

## Anti-Patterns

- **String-typed channel names without constants**: Typos in channel names cause silent failures. Define names as `static const`.
- **No error handling on native side**: Unhandled native exceptions crash the app. Always wrap in try/catch and use `result.error()`.
- **Heavy computation on the platform thread**: Blocking the main thread on native side causes UI jank. Use background threads for heavy work.
- **Ignoring platform availability**: Calling iOS-only APIs on Android throws. Always check the platform first.

## Integration Points

- **State Management**: Native data streams feed into BLoC/Cubit state; see `state-management.md`.
- **Widget Layer**: Platform-specific widgets use conditional rendering; see `widget-patterns.md`.
- **Dart Conventions**: Follow async/await patterns for channel calls; see `dart-conventions.md`.
- **Testing**: Mock the method channel in tests using `TestDefaultBinaryMessengerBinding`.
