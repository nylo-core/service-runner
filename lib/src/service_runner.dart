import 'dart:async';

import 'package:flutter/widgets.dart';

import 'service.dart';

/// A lightweight service initialization system for Flutter apps.
///
/// ServiceRunner provides a simple way to initialize services with
/// lifecycle management and optional splash screen support.
///
/// ## Basic Usage
/// ```dart
/// void main() async {
///   await ServiceRunner.init(
///     services: [
///       FirebaseKit.init(...),
///       AnalyticsService(),
///     ],
///     splashScreen: const SplashScreen(),
///     child: const MyApp(),
///   );
/// }
/// ```
///
/// ## Service Lifecycle
/// Services go through three lifecycle phases in order:
/// 1. `onInit()` - Called for each service in order during initialization
/// 2. `onReady()` - Called after all services have completed onInit()
/// 3. `onAppReady()` - Called after the app widget is running
///
/// ## Accessing Services
/// After initialization, services can be accessed anywhere:
/// ```dart
/// final firebase = service<FirebaseKit>();
/// final analytics = serviceOrNull<AnalyticsService>(); // Returns null if not found
/// ```
class ServiceRunner {
  /// List of resolved services after initialization.
  static List<Runnable> _services = [];

  /// Whether initialization is currently in progress.
  static bool _isInitializing = false;

  /// Whether initialization has completed successfully.
  static bool _isInitialized = false;

  /// Get the list of initialized services.
  static List<Runnable> get services => _services;

  /// Whether initialization has completed successfully.
  static bool get isInitialized => _isInitialized;

  /// Whether initialization is currently in progress.
  static bool get isInitializing => _isInitializing;

  /// Initialize services and run the app.
  ///
  /// [services] - List of services to initialize. Supports both sync and
  /// async service factories (e.g., `Future<Runnable>`).
  ///
  /// [splashScreen] - Optional widget to display while services are initializing.
  /// If provided, this widget is shown immediately via `runApp()` before
  /// service initialization begins, then replaced with [child] after completion.
  ///
  /// [child] - The main app widget to run after service initialization.
  ///
  /// [onBeforeInit] - Optional callback invoked before service initialization
  /// begins. Useful for custom setup like timezone configuration.
  ///
  /// [onAfterInit] - Optional callback invoked after all services have
  /// completed their lifecycle methods but before the child widget is run.
  ///
  /// Example:
  /// ```dart
  /// await ServiceRunner.init(
  ///   services: [
  ///     // Async factory pattern
  ///     FirebaseKit.init(
  ///       options: DefaultFirebaseOptions.currentPlatform,
  ///       services: [
  ///         FirebaseKitMessaging(sendTokenOnBoot: true),
  ///         FirebaseKitAnalytics(),
  ///       ],
  ///     ),
  ///     // All services use .init()
  ///     MyCustomService.init(),
  ///   ],
  ///   splashScreen: const SplashScreen(),
  ///   child: const MyApp(),
  /// );
  /// ```
  static Future<void> init({
    required List<FutureOr<Runnable>> services,
    Widget? splashScreen,
    required Widget child,
    FutureOr<void> Function()? onBeforeInit,
    FutureOr<void> Function(List<Runnable> services)? onAfterInit,
  }) async {
    // Prevent concurrent initialization
    if (_isInitializing) {
      throw StateError(
        'ServiceRunner.init() is already in progress. '
        'Concurrent initialization is not allowed.',
      );
    }

    _isInitializing = true;
    _isInitialized = false;

    try {
      // Ensure Flutter bindings are initialized
      WidgetsFlutterBinding.ensureInitialized();

      // Show splash screen if provided
      if (splashScreen != null) {
        runApp(splashScreen);
      }

      // Run pre-initialization callback
      if (onBeforeInit != null) {
        await onBeforeInit();
      }

      // Resolve all FutureOr<Runnable> to Runnable instances
      final List<Runnable> resolvedServices = [];
      for (final serviceOrFuture in services) {
        final Runnable resolvedService = await serviceOrFuture;
        resolvedServices.add(resolvedService);
      }
      _services = resolvedServices;

      // Phase 1: Initialize all services
      for (final service in resolvedServices) {
        try {
          await service.onInit();
        } catch (e, stack) {
          throw ServiceInitializationException(
            serviceName: service.serviceName,
            phase: 'onInit',
            originalError: e,
            stackTrace: stack,
          );
        }
        // Register in the service registry after successful onInit
        Runnable.register(service);
      }

      // Phase 2: All services ready
      for (final service in resolvedServices) {
        try {
          await service.onReady();
        } catch (e, stack) {
          throw ServiceInitializationException(
            serviceName: service.serviceName,
            phase: 'onReady',
            originalError: e,
            stackTrace: stack,
          );
        }
      }

      // Phase 3: App fully ready (navigation available)
      for (final service in resolvedServices) {
        try {
          await service.onAppReady();
        } catch (e, stack) {
          throw ServiceInitializationException(
            serviceName: service.serviceName,
            phase: 'onAppReady',
            originalError: e,
            stackTrace: stack,
          );
        }
      }

      // Run post-initialization callback
      if (onAfterInit != null) {
        await onAfterInit(resolvedServices);
      }

      _isInitialized = true;

      // Run the main app
      runApp(child);
    } finally {
      _isInitializing = false;
    }
  }

  /// Check if a service is registered.
  ///
  /// Example:
  /// ```dart
  /// if (ServiceRunner.hasService<FirebaseKit>()) {
  ///   // Firebase is available
  /// }
  /// ```
  static bool hasService<T extends Runnable>() {
    return Runnable.has<T>();
  }

  /// Get a service by type.
  ///
  /// Returns null if the service is not registered.
  ///
  /// Example:
  /// ```dart
  /// final firebase = ServiceRunner.getService<FirebaseKit>();
  /// ```
  static T? getService<T extends Runnable>() {
    return Runnable.getOrNull<T>();
  }

  /// Clear all services, calling [Runnable.onDispose] on each.
  ///
  /// This method is intended for testing purposes.
  @visibleForTesting
  static Future<void> clear() async {
    _services.clear();
    // ignore: invalid_use_of_visible_for_testing_member
    await Runnable.clearRegistry();
    _isInitialized = false;
  }
}
