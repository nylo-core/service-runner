import 'dart:async';

import 'package:flutter/foundation.dart';

/// Exception thrown when a service fails to initialize.
///
/// Contains the service name, original error, and stack trace for debugging.
class ServiceInitializationException implements Exception {
  /// The name of the service that failed to initialize.
  final String serviceName;

  /// The lifecycle phase that failed (e.g., 'onInit', 'onReady', 'onAppReady').
  final String phase;

  /// The original error that caused the failure.
  final Object originalError;

  /// The stack trace from the original error.
  final StackTrace stackTrace;

  ServiceInitializationException({
    required this.serviceName,
    required this.phase,
    required this.originalError,
    required this.stackTrace,
  });

  @override
  String toString() {
    return 'ServiceInitializationException: Failed to run $phase() on $serviceName\n'
        'Original error: $originalError\n'
        'Stack trace:\n$stackTrace';
  }
}

/// Abstract base class for runnables.
///
/// Extend this class to create custom runnables that integrate
/// with the ServiceRunner initialization system.
///
/// ## Basic Example
/// All services should use the `.init()` factory pattern for consistency:
/// ```dart
/// class MyCustomRunnable extends Runnable {
///   MyCustomRunnable._();
///
///   static Future<MyCustomRunnable> init() async {
///     // Perform any setup before registration
///     return MyCustomRunnable._();
///   }
///
///   @override
///   Future<void> onInit() async {
///     // Initialize your runnable
///   }
///
///   @override
///   Future<void> onReady() async {
///     // Called after all runnables are initialized
///   }
///
///   @override
///   Future<void> onAppReady() async {
///     // Called when the app is fully ready
///   }
/// }
/// ```
///
/// ## Async Factory Pattern
/// For runnables that require async initialization (e.g., Firebase),
/// perform the async work in the static `init()` method:
///
/// ```dart
/// class FirebaseKit extends Runnable {
///   final FirebaseOptions options;
///   final List<FirebaseKitService> services;
///
///   FirebaseKit._({required this.options, this.services = const []});
///
///   /// Async factory - returns Future<Runnable>
///   static Future<FirebaseKit> init({
///     required FirebaseOptions options,
///     List<FirebaseKitService> services = const [],
///   }) async {
///     final kit = FirebaseKit._(options: options, services: services);
///     // Perform any pre-registration async setup here
///     return kit;
///   }
///
///   @override
///   Future<void> onInit() async {
///     // Initialize Firebase and child services
///     await Firebase.initializeApp(options: options);
///     for (final childService in services) {
///       await childService.onInit();
///     }
///   }
/// }
/// ```
///
/// ## Usage
/// ```dart
/// await ServiceRunner.init(
///   services: [
///     // Using Runnable.add for explicit type registration
///     Runnable.add<FirebaseKit>(() {
///       return FirebaseKit.init(
///         options: DefaultFirebaseOptions.currentPlatform,
///         services: [
///           FirebaseKitMessaging(sendTokenOnBoot: true),
///           FirebaseKitAnalytics(),
///         ],
///       );
///     }),
///     // All services use .init()
///     MyCustomRunnable.init(),
///   ],
///   child: const MyApp(),
/// );
///
/// // Retrieve runnables anywhere in your app:
/// final firebase = service<FirebaseKit>();
/// ```
abstract class Runnable {
  /// Static registry of all registered runnables by their runtime type.
  static final Map<Type, Runnable> _registry = {};

  /// Register a runnable using a factory function.
  ///
  /// Use this in the [ServiceRunner.init] services list for explicit type registration.
  /// The factory is called and awaited, the runnable is registered by type [T],
  /// and then returned for [ServiceRunner.init] to run lifecycle methods.
  ///
  /// Example:
  /// ```dart
  /// await ServiceRunner.init(
  ///   services: [
  ///     Runnable.add<FirebaseKit>(() {
  ///       return FirebaseKit.init(
  ///         options: DefaultFirebaseOptions.currentPlatform,
  ///         services: [
  ///           FirebaseKitMessaging(),
  ///           FirebaseKitAnalytics(),
  ///         ],
  ///       );
  ///     }),
  ///     MyCustomRunnable(),
  ///   ],
  ///   child: const MyApp(),
  /// );
  ///
  /// // Later, retrieve it anywhere:
  /// final firebase = service<FirebaseKit>();
  /// ```
  static Future<T> add<T extends Runnable>(
    FutureOr<T> Function() factory,
  ) async {
    final T resolvedRunnable = await factory();
    _registry[T] = resolvedRunnable;
    return resolvedRunnable;
  }

  /// Register a runnable in the global registry.
  ///
  /// This is called automatically during [ServiceRunner.init()] for each runnable.
  /// Runnables are registered by their runtime type.
  ///
  /// Note: This registers by runtime type. Use [add] for explicit type registration.
  /// If a runnable of the same type is already registered, a warning is logged
  /// and the existing registration is overwritten.
  static void register<T extends Runnable>(T runnable) {
    final type = runnable.runtimeType;
    if (_registry.containsKey(type)) {
      debugPrint(
        'Warning: Runnable $type is already registered. '
        'The existing registration will be overwritten.',
      );
    }
    _registry[type] = runnable;
  }

  /// Get a registered runnable by type.
  ///
  /// Throws [StateError] if the runnable is not registered.
  ///
  /// Example:
  /// ```dart
  /// final firebase = Runnable.get<FirebaseKit>();
  /// ```
  static T get<T extends Runnable>() {
    final runnable = _registry[T];
    if (runnable == null) {
      throw StateError(
        'Runnable $T is not registered. '
        'Make sure it was added to the services list in ServiceRunner.init().',
      );
    }
    return runnable as T;
  }

  /// Get a registered runnable by type, or null if not registered.
  ///
  /// Example:
  /// ```dart
  /// final analytics = Runnable.getOrNull<AnalyticsService>();
  /// if (analytics != null) {
  ///   analytics.trackEvent('page_view');
  /// }
  /// ```
  static T? getOrNull<T extends Runnable>() {
    final runnable = _registry[T];
    if (runnable is T) {
      return runnable;
    }
    return null;
  }

  /// Check if a runnable is registered.
  ///
  /// Example:
  /// ```dart
  /// if (Runnable.has<FirebaseKit>()) {
  ///   // Firebase is available
  /// }
  /// ```
  static bool has<T extends Runnable>() {
    return _registry.containsKey(T);
  }

  /// Internal method to dispose and clear all runnables.
  /// Used by [ServiceRunner.clear].
  static Future<void> _disposeAndClearAll() async {
    for (final runnable in _registry.values) {
      await runnable.onDispose();
    }
    _registry.clear();
  }

  /// Clear all registered runnables and call [onDispose] on each.
  ///
  /// This method is intended for testing purposes.
  @visibleForTesting
  static Future<void> clearRegistry() => _disposeAndClearAll();

  /// Get all registered runnables.
  static List<Runnable> get all => _registry.values.toList();

  /// Called when the runnable is initialized.
  /// Override this to set up your runnable.
  Future<void> onInit() async {}

  /// Called after all runnables have been initialized.
  /// Override this for post-initialization setup.
  Future<void> onReady() async {}

  /// Called when the app is ready and navigation is available.
  /// Useful for deep linking or navigation-dependent setup.
  Future<void> onAppReady() async {}

  /// Called when the service is being disposed.
  /// Override this to clean up resources (database connections, streams, etc.).
  Future<void> onDispose() async {}

  /// Get the runnable name for logging.
  String get serviceName => runtimeType.toString();
}

/// Get a registered runnable by type.
///
/// Throws [StateError] if the runnable is not registered.
/// For optional runnables, use [serviceOrNull] instead.
///
/// Example:
/// ```dart
/// final firebase = service<FirebaseKit>();
/// ```
T service<T extends Runnable>() => Runnable.get<T>();

/// Get a registered runnable by type, or null if not registered.
///
/// Use this for optional runnables that may not be configured.
///
/// Example:
/// ```dart
/// final analytics = serviceOrNull<AnalyticsService>();
/// analytics?.trackEvent('page_view');
/// ```
T? serviceOrNull<T extends Runnable>() => Runnable.getOrNull<T>();
