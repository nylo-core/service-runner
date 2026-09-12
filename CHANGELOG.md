## [1.0.2] - 2026-09-12

### Changed
- Replaced the `flutter_lints` dev dependency with the `vibe_check` Nylo lint preset and fixed all resulting analyzer issues
- Added explicit local variable types in the `Runnable` registry (no behavior change)
- Tightened the failed-initialization test to assert that a `ServiceInitializationException` is thrown instead of silently catching all errors

## 1.0.1

- Updated dependencies

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
