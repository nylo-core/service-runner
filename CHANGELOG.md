## 1.0.0

Initial release.

### Features

- **Service lifecycle management** with four phases: `onInit()`, `onReady()`, `onAppReady()`, and `onDispose()`
- **Splash screen support** - display a widget while services initialize
- **Global service registry** - access services anywhere with `service<T>()` and `serviceOrNull<T>()`
- **Async factory pattern** - services can use `static Future<T> init()` for async initialization
- **Explicit type registration** - use `Runnable.add<T>()` to register by interface type
- **Lifecycle callbacks** - `onBeforeInit` and `onAfterInit` hooks in `ServiceRunner.init()`
- **Error handling** - `ServiceInitializationException` with service name, phase, and original error
- **State tracking** - `ServiceRunner.isInitialized` and `ServiceRunner.isInitializing` properties
- **Concurrent initialization protection** - throws if `init()` is called while already initializing
