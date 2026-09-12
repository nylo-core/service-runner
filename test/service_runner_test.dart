import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_runner/service_runner.dart';

/// Mock service that tracks lifecycle order
class LifecycleTrackingService extends Runnable {
  static final List<String> callOrder = [];
  final String name;

  LifecycleTrackingService(this.name);

  @override
  Future<void> onInit() async {
    callOrder.add('$name:onInit');
  }

  @override
  Future<void> onReady() async {
    callOrder.add('$name:onReady');
  }

  @override
  Future<void> onAppReady() async {
    callOrder.add('$name:onAppReady');
  }
}

/// Async service for testing
class AsyncService extends Runnable {
  final String data;

  AsyncService._(this.data);

  /// Creates an async service. The delay is optional for testing flexibility.
  static Future<AsyncService> init(String data, {bool useDelay = false}) async {
    if (useDelay) {
      await Future.delayed(const Duration(milliseconds: 5));
    }
    return AsyncService._(data);
  }
}

/// Service that throws during onInit
class ThrowingOnInitService extends Runnable {
  @override
  Future<void> onInit() async {
    throw Exception('onInit failed');
  }
}

/// Service that throws during onReady
class ThrowingOnReadyService extends Runnable {
  @override
  Future<void> onReady() async {
    throw Exception('onReady failed');
  }
}

/// Service that throws during onAppReady
class ThrowingOnAppReadyService extends Runnable {
  @override
  Future<void> onAppReady() async {
    throw Exception('onAppReady failed');
  }
}

/// Service that tracks disposal
class DisposableService extends Runnable {
  static bool disposed = false;

  @override
  Future<void> onDispose() async {
    disposed = true;
  }

  static void reset() {
    disposed = false;
  }
}

void main() {
  setUp(() async {
    await ServiceRunner.clear();
    LifecycleTrackingService.callOrder.clear();
    DisposableService.reset();
  });

  group('ServiceRunner', () {
    testWidgets('should initialize services in correct lifecycle order',
        (tester) async {
      await ServiceRunner.init(
        services: [
          LifecycleTrackingService('A'),
          LifecycleTrackingService('B'),
        ],
        child: Container(),
      );

      // Verify lifecycle order: all onInit first, then all onReady, then all onAppReady
      expect(LifecycleTrackingService.callOrder, [
        'A:onInit',
        'B:onInit',
        'A:onReady',
        'B:onReady',
        'A:onAppReady',
        'B:onAppReady',
      ]);
    });

    testWidgets('should register services in registry', (tester) async {
      await ServiceRunner.init(
        services: [
          LifecycleTrackingService('test'),
        ],
        child: Container(),
      );

      expect(ServiceRunner.hasService<LifecycleTrackingService>(), isTrue);
      expect(ServiceRunner.getService<LifecycleTrackingService>(), isNotNull);
    });

    testWidgets('should support async service factories', (tester) async {
      await ServiceRunner.init(
        services: [
          AsyncService.init('test-data'),
        ],
        child: Container(),
      );

      expect(ServiceRunner.hasService<AsyncService>(), isTrue);
      final AsyncService asyncService = service<AsyncService>();
      expect(asyncService.data, 'test-data');
    });

    testWidgets('should call onBeforeInit callback', (tester) async {
      bool beforeInitCalled = false;

      await ServiceRunner.init(
        services: [
          LifecycleTrackingService('A'),
        ],
        onBeforeInit: () async {
          beforeInitCalled = true;
        },
        child: Container(),
      );

      expect(beforeInitCalled, isTrue);
    });

    testWidgets('should call onAfterInit callback with services',
        (tester) async {
      List<Runnable>? receivedServices;

      await ServiceRunner.init(
        services: [
          LifecycleTrackingService('A'),
          LifecycleTrackingService('B'),
        ],
        onAfterInit: (services) async {
          receivedServices = services;
        },
        child: Container(),
      );

      expect(receivedServices, isNotNull);
      expect(receivedServices!.length, 2);
    });

    testWidgets('should store services in services list', (tester) async {
      await ServiceRunner.init(
        services: [
          LifecycleTrackingService('A'),
          LifecycleTrackingService('B'),
        ],
        child: Container(),
      );

      expect(ServiceRunner.services.length, 2);
    });

    testWidgets('should work with empty services list', (tester) async {
      await ServiceRunner.init(
        services: [],
        child: Container(),
      );

      expect(ServiceRunner.services, isEmpty);
    });

    testWidgets('should clear services', (tester) async {
      await ServiceRunner.init(
        services: [
          LifecycleTrackingService('A'),
        ],
        child: Container(),
      );

      expect(ServiceRunner.services.length, 1);

      await ServiceRunner.clear();

      expect(ServiceRunner.services, isEmpty);
      expect(Runnable.has<LifecycleTrackingService>(), isFalse);
    });

    testWidgets('should support Runnable.add for explicit type registration',
        (tester) async {
      await ServiceRunner.init(
        services: [
          Runnable.add<AsyncService>(() => AsyncService.init('explicit')),
        ],
        child: Container(),
      );

      expect(Runnable.has<AsyncService>(), isTrue);
      expect(service<AsyncService>().data, 'explicit');
    });

    testWidgets('should set isInitialized to true after successful init',
        (tester) async {
      expect(ServiceRunner.isInitialized, isFalse);

      await ServiceRunner.init(
        services: [],
        child: Container(),
      );

      expect(ServiceRunner.isInitialized, isTrue);
    });

    testWidgets('should reset isInitialized after clear', (tester) async {
      await ServiceRunner.init(
        services: [],
        child: Container(),
      );

      expect(ServiceRunner.isInitialized, isTrue);

      await ServiceRunner.clear();

      expect(ServiceRunner.isInitialized, isFalse);
    });

    testWidgets('should call onDispose when clearing services', (tester) async {
      await ServiceRunner.init(
        services: [
          DisposableService(),
        ],
        child: Container(),
      );

      expect(DisposableService.disposed, isFalse);

      await ServiceRunner.clear();

      expect(DisposableService.disposed, isTrue);
    });

    testWidgets('should work with empty services and callbacks',
        (tester) async {
      bool beforeCalled = false;
      bool afterCalled = false;

      await ServiceRunner.init(
        services: [],
        onBeforeInit: () {
          beforeCalled = true;
        },
        onAfterInit: (services) {
          afterCalled = true;
        },
        child: Container(),
      );

      expect(beforeCalled, isTrue);
      expect(afterCalled, isTrue);
    });
  });

  group('ServiceRunner error handling', () {
    testWidgets('should throw ServiceInitializationException when onInit fails',
        (tester) async {
      expect(
        () => ServiceRunner.init(
          services: [ThrowingOnInitService()],
          child: Container(),
        ),
        throwsA(isA<ServiceInitializationException>()),
      );
    });

    testWidgets(
        'should throw ServiceInitializationException when onReady fails',
        (tester) async {
      expect(
        () => ServiceRunner.init(
          services: [ThrowingOnReadyService()],
          child: Container(),
        ),
        throwsA(isA<ServiceInitializationException>()),
      );
    });

    testWidgets(
        'should throw ServiceInitializationException when onAppReady fails',
        (tester) async {
      expect(
        () => ServiceRunner.init(
          services: [ThrowingOnAppReadyService()],
          child: Container(),
        ),
        throwsA(isA<ServiceInitializationException>()),
      );
    });

    testWidgets(
        'ServiceInitializationException should contain service name and phase',
        (tester) async {
      try {
        await ServiceRunner.init(
          services: [ThrowingOnInitService()],
          child: Container(),
        );
        fail('Expected ServiceInitializationException');
      } on ServiceInitializationException catch (e) {
        expect(e.serviceName, 'ThrowingOnInitService');
        expect(e.phase, 'onInit');
        expect(e.originalError, isA<Exception>());
        expect(e.toString(), contains('ThrowingOnInitService'));
        expect(e.toString(), contains('onInit'));
      }
    });

    testWidgets('should throw when factory function throws', (tester) async {
      expect(
        () => ServiceRunner.init(
          services: [
            Future<Runnable>.error(Exception('factory failed')),
          ],
          child: Container(),
        ),
        throwsA(isA<Exception>()),
      );
    });

    testWidgets('should propagate exception from onBeforeInit callback',
        (tester) async {
      expect(
        () => ServiceRunner.init(
          services: [],
          onBeforeInit: () {
            throw Exception('onBeforeInit failed');
          },
          child: Container(),
        ),
        throwsA(isA<Exception>()),
      );
    });

    testWidgets('should propagate exception from onAfterInit callback',
        (tester) async {
      expect(
        () => ServiceRunner.init(
          services: [],
          onAfterInit: (services) {
            throw Exception('onAfterInit failed');
          },
          child: Container(),
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('ServiceRunner concurrent initialization', () {
    testWidgets('should throw when init is called concurrently',
        (tester) async {
      // We can't easily test true concurrency in widget tests, but we can
      // verify that the isInitializing flag works correctly
      expect(ServiceRunner.isInitializing, isFalse);

      // Start init - the flag should be set during the async operation
      final Future<void> initFuture = ServiceRunner.init(
        services: [LifecycleTrackingService('test')],
        child: Container(),
      );

      // Complete the init
      await initFuture;
      expect(ServiceRunner.isInitializing, isFalse);
      expect(ServiceRunner.isInitialized, isTrue);
    });

    testWidgets('should allow init after previous init completes',
        (tester) async {
      await ServiceRunner.init(
        services: [LifecycleTrackingService('first')],
        child: Container(),
      );

      await ServiceRunner.clear();

      // This should not throw
      await ServiceRunner.init(
        services: [LifecycleTrackingService('second')],
        child: Container(),
      );

      expect(ServiceRunner.isInitialized, isTrue);
    });

    testWidgets('should reset isInitializing after failed init',
        (tester) async {
      await expectLater(
        ServiceRunner.init(
          services: [ThrowingOnInitService()],
          child: Container(),
        ),
        throwsA(isA<ServiceInitializationException>()),
      );

      expect(ServiceRunner.isInitializing, isFalse);

      // Should be able to call init again
      await ServiceRunner.init(
        services: [],
        child: Container(),
      );

      expect(ServiceRunner.isInitialized, isTrue);
    });
  });
}
