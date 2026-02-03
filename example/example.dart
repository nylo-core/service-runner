import 'package:flutter/material.dart';
import 'package:service_runner/service_runner.dart';

/// Example: A simple API service
class ApiService extends Runnable {
  final String baseUrl;

  ApiService._({required this.baseUrl});

  /// Factory method for consistent initialization pattern
  static Future<ApiService> init() async {
    // Simulate async initialization (e.g., loading config)
    await Future.delayed(const Duration(milliseconds: 100));
    return ApiService._(baseUrl: 'https://api.example.com');
  }

  Future<String> fetchData() async {
    // Your API logic here
    return 'Data from $baseUrl';
  }

  @override
  Future<void> onDispose() async {
    // Clean up resources (e.g., close HTTP client)
    debugPrint('ApiService disposed');
  }
}

/// Example: A service with async factory pattern
class DatabaseService extends Runnable {
  final String connectionString;

  DatabaseService._(this.connectionString);

  /// Async factory for services requiring async setup before registration
  static Future<DatabaseService> init() async {
    // Simulate async setup (e.g., opening database connection)
    await Future.delayed(const Duration(milliseconds: 100));
    return DatabaseService._('sqlite://app.db');
  }

  @override
  Future<void> onReady() async {
    // Called after all services are initialized
    // Good place for setup that depends on other services
  }

  @override
  Future<void> onDispose() async {
    // Clean up resources (e.g., close database connection)
    debugPrint('DatabaseService disposed');
  }
}

/// Example: Analytics service demonstrating lifecycle hooks
class AnalyticsService extends Runnable {
  AnalyticsService._();

  /// Factory method for consistent initialization pattern
  static Future<AnalyticsService> init() async {
    // Perform any pre-registration setup here
    return AnalyticsService._();
  }

  @override
  Future<void> onAppReady() async {
    // Called when app is fully ready - safe to track events
    trackEvent('app_started');
  }

  void trackEvent(String name) {
    debugPrint('Analytics: $name');
  }
}

/// Example: Interface for cache implementations
abstract class CacheService extends Runnable {
  String? get(String key);
  void set(String key, String value);
}

/// Example: A concrete cache implementation
class MemoryCacheService extends CacheService {
  final Map<String, String> _cache = {};

  MemoryCacheService._();

  static Future<MemoryCacheService> init() async {
    return MemoryCacheService._();
  }

  @override
  String? get(String key) => _cache[key];

  @override
  void set(String key, String value) => _cache[key] = value;
}

void main() async {
  try {
    await ServiceRunner.init(
      // Services are initialized in order using .init() factory pattern
      services: [
        ApiService.init(),
        DatabaseService.init(),
        AnalyticsService.init(),
        // Use Runnable.add<T> for explicit type registration
        // This allows retrieving by interface type (CacheService)
        Runnable.add<CacheService>(() => MemoryCacheService.init()),
      ],
      // Optional: Show splash while services initialize
      splashScreen: const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      ),
      // Optional callbacks
      onBeforeInit: () {
        debugPrint('Starting service initialization...');
      },
      onAfterInit: (services) {
        debugPrint('Initialized ${services.length} services');
      },
      child: const MyApp(),
    );
  } on ServiceInitializationException catch (e) {
    // Handle service initialization errors gracefully
    debugPrint('Service initialization failed: ${e.serviceName}');
    debugPrint('Phase: ${e.phase}');
    debugPrint('Error: ${e.originalError}');
    runApp(ErrorApp(error: e));
  } catch (e) {
    // Handle other errors
    debugPrint('Unexpected error: $e');
    runApp(ErrorApp(error: e));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Service Runner Example')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Access services anywhere using service<T>()
              Text('API URL: ${service<ApiService>().baseUrl}'),
              const SizedBox(height: 16),
              Text('DB: ${service<DatabaseService>().connectionString}'),
              const SizedBox(height: 16),
              // Access by interface type using Runnable.add<T>
              Text(
                  'Cache available: ${ServiceRunner.hasService<CacheService>()}'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  // Use serviceOrNull<T>() for optional services
                  serviceOrNull<AnalyticsService>()?.trackEvent('button_tap');
                  // Use cache service by interface
                  service<CacheService>()
                      .set('last_tap', DateTime.now().toString());
                },
                child: const Text('Track Event'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Error screen shown when service initialization fails
class ErrorApp extends StatelessWidget {
  final Object error;

  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Initialization Error'),
          backgroundColor: Colors.red,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Failed to initialize services',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  // In a real app, you might retry initialization
                  // or navigate to a settings screen
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
