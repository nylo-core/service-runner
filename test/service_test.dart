import 'package:flutter_test/flutter_test.dart';
import 'package:service_runner/service_runner.dart';

/// Mock service for testing
class MockService extends Runnable {
  bool initCalled = false;
  bool readyCalled = false;
  bool appReadyCalled = false;
  bool disposeCalled = false;

  @override
  Future<void> onInit() async {
    initCalled = true;
  }

  @override
  Future<void> onReady() async {
    readyCalled = true;
  }

  @override
  Future<void> onAppReady() async {
    appReadyCalled = true;
  }

  @override
  Future<void> onDispose() async {
    disposeCalled = true;
  }
}

/// Another mock service for testing
class AnotherMockService extends Runnable {}

/// Async mock service for testing
class AsyncMockService extends Runnable {
  final String data;

  AsyncMockService._(this.data);

  static Future<AsyncMockService> init(String data) async {
    await Future.delayed(const Duration(milliseconds: 10));
    return AsyncMockService._(data);
  }
}

void main() {
  setUp(() async {
    await Runnable.clearRegistry();
  });

  group('Runnable', () {
    group('register and get', () {
      test('should register a service', () {
        final service = MockService();
        Runnable.register(service);

        expect(Runnable.has<MockService>(), isTrue);
      });

      test('should get a registered service', () {
        final mockService = MockService();
        Runnable.register(mockService);

        final retrieved = Runnable.get<MockService>();
        expect(retrieved, same(mockService));
      });

      test('should throw when getting unregistered service', () {
        expect(
          () => Runnable.get<MockService>(),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('getOrNull', () {
      test('should return service when registered', () {
        final mockService = MockService();
        Runnable.register(mockService);

        expect(Runnable.getOrNull<MockService>(), same(mockService));
      });

      test('should return null when not registered', () {
        expect(Runnable.getOrNull<MockService>(), isNull);
      });
    });

    group('has', () {
      test('should return true when service is registered', () {
        Runnable.register(MockService());
        expect(Runnable.has<MockService>(), isTrue);
      });

      test('should return false when service is not registered', () {
        expect(Runnable.has<MockService>(), isFalse);
      });
    });

    group('clearRegistry', () {
      test('should remove all registered services', () async {
        Runnable.register(MockService());
        Runnable.register(AnotherMockService());

        expect(Runnable.has<MockService>(), isTrue);
        expect(Runnable.has<AnotherMockService>(), isTrue);

        await Runnable.clearRegistry();

        expect(Runnable.has<MockService>(), isFalse);
        expect(Runnable.has<AnotherMockService>(), isFalse);
      });
    });

    group('add', () {
      test('should register service using factory', () async {
        await Runnable.add<MockService>(() => MockService());

        expect(Runnable.has<MockService>(), isTrue);
      });

      test('should register service with async factory', () async {
        await Runnable.add<AsyncMockService>(
          () => AsyncMockService.init('test-data'),
        );

        expect(Runnable.has<AsyncMockService>(), isTrue);
        expect(Runnable.get<AsyncMockService>().data, 'test-data');
      });

      test('should return the created service', () async {
        final mockService =
            await Runnable.add<MockService>(() => MockService());

        expect(mockService, isA<MockService>());
        expect(Runnable.get<MockService>(), same(mockService));
      });
    });

    group('all', () {
      test('should return all registered services', () {
        final mock1 = MockService();
        final mock2 = AnotherMockService();
        Runnable.register(mock1);
        Runnable.register(mock2);

        final allServices = Runnable.all;
        expect(allServices.length, 2);
        expect(allServices.contains(mock1), isTrue);
        expect(allServices.contains(mock2), isTrue);
      });

      test('should return empty list when no services registered', () {
        expect(Runnable.all, isEmpty);
      });
    });

    group('lifecycle methods', () {
      test('should call onInit when invoked', () async {
        final mockService = MockService();
        expect(mockService.initCalled, isFalse);

        await mockService.onInit();
        expect(mockService.initCalled, isTrue);
      });

      test('should call onReady when invoked', () async {
        final mockService = MockService();
        expect(mockService.readyCalled, isFalse);

        await mockService.onReady();
        expect(mockService.readyCalled, isTrue);
      });

      test('should call onAppReady when invoked', () async {
        final mockService = MockService();
        expect(mockService.appReadyCalled, isFalse);

        await mockService.onAppReady();
        expect(mockService.appReadyCalled, isTrue);
      });
    });

    group('serviceName', () {
      test('should return runtime type name', () {
        final mockService = MockService();
        expect(mockService.serviceName, 'MockService');
      });
    });
  });

  group('service helper function', () {
    test('should return registered service', () {
      final mockService = MockService();
      Runnable.register(mockService);

      final retrieved = service<MockService>();
      expect(retrieved, same(mockService));
    });

    test('should throw when service not registered', () {
      expect(() => service<MockService>(), throwsA(isA<StateError>()));
    });
  });

  group('serviceOrNull helper function', () {
    test('should return service when registered', () {
      final mockService = MockService();
      Runnable.register(mockService);

      expect(serviceOrNull<MockService>(), same(mockService));
    });

    test('should return null when not registered', () {
      expect(serviceOrNull<MockService>(), isNull);
    });
  });

  group('onDispose lifecycle', () {
    test('should call onDispose when clearRegistry is called', () async {
      final mockService = MockService();
      Runnable.register(mockService);

      expect(mockService.disposeCalled, isFalse);

      await Runnable.clearRegistry();

      expect(mockService.disposeCalled, isTrue);
    });

    test('should call onDispose on all services', () async {
      final mock1 = MockService();
      // Use Runnable.add to register under type key
      await Runnable.add<MockService>(() => mock1);
      // Verify the registry was cleared after dispose
      await Runnable.clearRegistry();

      expect(mock1.disposeCalled, isTrue);
      expect(Runnable.has<MockService>(), isFalse);
    });
  });

  group('ServiceInitializationException', () {
    test('should store all fields correctly', () {
      final originalError = Exception('test error');
      final stackTrace = StackTrace.current;

      final exception = ServiceInitializationException(
        serviceName: 'TestService',
        phase: 'onInit',
        originalError: originalError,
        stackTrace: stackTrace,
      );

      expect(exception.serviceName, 'TestService');
      expect(exception.phase, 'onInit');
      expect(exception.originalError, originalError);
      expect(exception.stackTrace, stackTrace);
    });

    test('should format toString correctly', () {
      final exception = ServiceInitializationException(
        serviceName: 'TestService',
        phase: 'onReady',
        originalError: Exception('test'),
        stackTrace: StackTrace.current,
      );

      final str = exception.toString();
      expect(str, contains('TestService'));
      expect(str, contains('onReady'));
      expect(str, contains('Exception: test'));
    });
  });
}
