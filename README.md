# Service Runner

A lightweight Flutter package for service initialization with lifecycle management, splash screen support, and a global service registry.

## Features

- **Service Lifecycle Management** - Services go through `onInit()`, `onReady()`, and `onAppReady()` phases
- **Splash Screen Support** - Show a splash screen while services initialize
- **Global Service Registry** - Access services from anywhere with `service<T>()`
- **Async Factory Pattern** - Support for services requiring async initialization

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  service_runner: ^1.0.1
```

## Quick Start

```dart
import 'package:service_runner/service_runner.dart';

void main() async {
  await ServiceRunner.init(
    services: [
      FirebaseKit.init(...),
      AnalyticsService.init(),
    ],
    splashScreen: const SplashScreen(),
    child: const MyApp(),
  );
}

// Access services anywhere:
final firebase = service<FirebaseKit>();
```

## Creating Services

All services should use the `.init()` factory pattern for consistency:

```dart
class MyService extends Runnable {
  MyService._();

  static Future<MyService> init() async {
    // Perform any setup before registration
    return MyService._();
  }

  @override
  Future<void> onInit() async {
    // Called during initialization phase
  }

  @override
  Future<void> onReady() async {
    // Called after all services are initialized
  }

  @override
  Future<void> onAppReady() async {
    // Called when the app is fully ready
  }
}
```

For services requiring async setup before registration:

```dart
class DatabaseService extends Runnable {
  final Database db;

  DatabaseService._(this.db);

  static Future<DatabaseService> init() async {
    final db = await Database.open();
    return DatabaseService._(db);
  }
}
```

## Explicit Type Registration

Use `Runnable.add<T>()` for explicit type registration:

```dart
await ServiceRunner.init(
  services: [
    Runnable.add<FirebaseKit>(() => FirebaseKit.init(...)),
    MyService.init(),
  ],
  child: const MyApp(),
);
```

## Accessing Services

```dart
// Get required service (throws if not found)
final firebase = service<FirebaseKit>();

// Get optional service (returns null if not found)
final analytics = serviceOrNull<AnalyticsService>();
analytics?.trackEvent('page_view');

// Check if service exists
if (Runnable.has<FirebaseKit>()) {
  // Firebase is available
}
```

## Service Lifecycle

Services go through three phases in order:

1. **onInit()** - Called for each service in order during initialization
2. **onReady()** - Called after all services have completed onInit()
3. **onAppReady()** - Called after the app widget is running

## Hooks

```dart
await ServiceRunner.init(
  services: [...],
  onBeforeInit: () async {
    // Custom setup before services initialize
  },
  onAfterInit: (services) async {
    // Called after all services initialized
  },
  child: const MyApp(),
);
```

## License

MIT License
