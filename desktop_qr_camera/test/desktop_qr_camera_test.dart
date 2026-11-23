import 'dart:async';

import 'package:desktop_qr_camera/desktop_qr_camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('desktop_qr_camera');

/// The native side, answering each method with a value, or by throwing.
class _FakeNative {
  final calls = <String>[];
  final answers = <String, Object? Function()>{'open': () => null, 'startPreview': () => 7, 'release': () => null};

  Future<Object?> handle(MethodCall call) async {
    calls.add(call.method);
    final answer = answers[call.method];
    if (answer == null) throw MissingPluginException(call.method);
    return answer();
  }
}

Map<String, Object?> _frame({int width = 2, int height = 2, int? length}) => {
  'width': width,
  'height': height,
  'luma': Uint8List(length ?? width * height),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeNative native;
  late QrCamera camera;

  setUp(() {
    native = _FakeNative();
    camera = QrCamera();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, native.handle);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
  });

  group('failures', () {
    for (final (code, failure) in const [
      ('no_camera', QrCameraFailure.noCamera),
      ('permission_denied', QrCameraFailure.permissionDenied),
      ('busy', QrCameraFailure.busy),
      ('unsupported', QrCameraFailure.unsupported),
      ('media_unavailable', QrCameraFailure.mediaUnavailable),
      ('stopped', QrCameraFailure.stopped),
      ('failed', QrCameraFailure.failed),
    ]) {
      test('$code on opening is told apart as ${failure.name}', () async {
        native.answers['open'] = () => throw PlatformException(code: code);

        await expectLater(
          camera.start(),
          throwsA(isA<QrCameraException>().having((e) => e.failure, 'failure', failure)),
        );
      });

      test('$code while reading is told apart as ${failure.name}', () async {
        native.answers['captureFrame'] = () => throw PlatformException(code: code);
        await camera.start();

        await expectLater(
          camera.readFrame(),
          throwsA(isA<QrCameraException>().having((e) => e.failure, 'failure', failure)),
        );
      });
    }

    test('a code this version does not know is a plain failure, keeping the code', () async {
      native.answers['open'] = () => throw PlatformException(code: 'something_new');

      await expectLater(
        camera.start(),
        throwsA(
          isA<QrCameraException>()
              .having((e) => e.failure, 'failure', QrCameraFailure.failed)
              .having((e) => e.detail, 'detail', contains('something_new')),
        ),
      );
    });
  });

  group('when the native plugin is missing', () {
    final isPlainFailure = throwsA(
      isA<QrCameraException>().having((e) => e.failure, 'failure', QrCameraFailure.failed),
    );

    test('opening is a plain failure', () async {
      native.answers.remove('open');

      await expectLater(camera.start(), isPlainFailure);
    });

    test('it can start again afterwards', () async {
      final open = native.answers.remove('open')!;
      await expectLater(camera.start(), isPlainFailure);

      native.answers['open'] = open;

      expect(await camera.start(), 7);
    });

    test('a failed start still reports its own failure when releasing is missing too', () async {
      native.answers['open'] = () => throw PlatformException(code: 'busy');
      native.answers.remove('release');

      await expectLater(
        camera.start(),
        throwsA(isA<QrCameraException>().having((e) => e.failure, 'failure', QrCameraFailure.busy)),
      );
    });

    test('reading is a plain failure', () async {
      await camera.start();

      await expectLater(camera.readFrame(), isPlainFailure);
    });

    test('stopping is a plain failure', () async {
      await camera.start();
      native.answers.remove('release');

      await expectLater(camera.stop(), isPlainFailure);
    });
  });

  group('frames', () {
    setUp(() async => camera.start());

    test('a whole frame comes back with its size and brightness', () async {
      final luma = Uint8List.fromList([1, 2, 3, 4, 5, 6]);
      native.answers['captureFrame'] = () => {'width': 3, 'height': 2, 'luma': luma};

      final frame = await camera.readFrame();

      expect((frame!.width, frame.height), (3, 2));
      expect(frame.luma, luma);
    });

    test('no new frame yet is no frame, not a failure', () async {
      native.answers['captureFrame'] = () => null;

      expect(await camera.readFrame(), isNull);
    });

    for (final (name, bad) in <(String, Map<String, Object?>)>[
      ('too few bytes', _frame(length: 3)),
      ('too many bytes', _frame(length: 5)),
      ('no width', _frame(width: 0, height: 2, length: 0)),
      ('no height', _frame(width: 2, height: 0, length: 0)),
      ('a negative side', _frame(width: -2, height: -2, length: 4)),
      ('an absurd width', _frame(width: QrCamera.maxFrameSide + 1, height: 1)),
      ('an absurd height', _frame(width: 1, height: QrCamera.maxFrameSide + 1)),
      ('sides whose product wraps in 32 bits', _frame(width: 65536, height: 65536, length: 0)),
      ('no bytes at all', {'width': 2, 'height': 2}),
      ('a side of the wrong type', {'width': '2', 'height': 2, 'luma': Uint8List(4)}),
    ]) {
      test('a frame with $name is refused', () async {
        native.answers['captureFrame'] = () => bad;

        expect(await camera.readFrame(), isNull);
      });
    }
  });

  group('when frames are asked for', () {
    test('never before the camera has started', () async {
      expect(await camera.readFrame(), isNull);

      expect(native.calls, isNot(contains('captureFrame')));
    });

    test('never after it has stopped', () async {
      native.answers['captureFrame'] = () => _frame();
      await camera.start();
      await camera.stop();

      expect(await camera.readFrame(), isNull);

      expect(native.calls, isNot(contains('captureFrame')));
    });

    test('never after opening it failed', () async {
      native.answers['open'] = () => throw PlatformException(code: 'busy');
      await expectLater(camera.start(), throwsA(isA<QrCameraException>()));

      expect(await camera.readFrame(), isNull);

      expect(native.calls, isNot(contains('captureFrame')));
    });
  });

  group('starting and stopping', () {
    test('starting opens the camera, then its preview, and gives the texture', () async {
      expect(await camera.start(), 7);

      expect(native.calls, ['open', 'startPreview']);
    });

    test('stopping releases the camera', () async {
      await camera.start();

      await camera.stop();

      expect(native.calls, ['open', 'startPreview', 'release']);
    });

    test('a failed open still releases it', () async {
      native.answers['open'] = () => throw PlatformException(code: 'busy');

      await expectLater(camera.start(), throwsA(isA<QrCameraException>()));

      expect(native.calls, ['open', 'release']);
    });

    test('a failed preview still releases it', () async {
      native.answers['startPreview'] = () => throw PlatformException(code: 'failed');

      await expectLater(camera.start(), throwsA(isA<QrCameraException>()));

      expect(native.calls, ['open', 'startPreview', 'release']);
    });

    test('stopping what never started asks nothing of the camera', () async {
      await camera.stop();

      expect(native.calls, isEmpty);
    });

    test('stopping twice releases once', () async {
      await camera.start();

      await Future.wait([camera.stop(), camera.stop()]);

      expect(native.calls.where((call) => call == 'release'), hasLength(1));
    });

    test('a stop during a start waits for it, then releases', () async {
      final opening = Completer<void>();
      native.answers['open'] = () => opening.future;

      final starting = camera.start();
      final stopping = camera.stop();
      await pumpEventQueue();
      expect(native.calls, ['open']);

      opening.complete();
      await starting;
      await stopping;

      expect(native.calls, ['open', 'startPreview', 'release']);
      expect(await camera.readFrame(), isNull);
    });

    group('start, stop, start while the first open is running', () {
      late Completer<void> firstOpen;

      setUp(() {
        firstOpen = Completer<void>();
        var opens = 0;
        native.answers['open'] = () => ++opens == 1 ? firstOpen.future : null;
        native.answers['captureFrame'] = () => _frame();
      });

      test('when the first open fails, the second start runs', () async {
        final first = camera.start();
        final stopping = camera.stop();
        final second = camera.start();
        await pumpEventQueue();

        firstOpen.completeError(PlatformException(code: 'busy'));
        await expectLater(first, throwsA(isA<QrCameraException>()));
        await stopping;

        expect(await second, 7);
        expect(await camera.readFrame(), isNotNull);
      });

      test('when the first open fails, the last stop still releases the camera', () async {
        final first = camera.start();
        final stopping = camera.stop();
        final second = camera.start();
        await pumpEventQueue();

        firstOpen.completeError(PlatformException(code: 'busy'));
        await expectLater(first, throwsA(isA<QrCameraException>()));
        await stopping;
        await second;
        await camera.stop();

        expect(native.calls, ['open', 'release', 'open', 'startPreview', 'release']);
      });

      test('when the first open succeeds, no frame is asked for until the second is open', () async {
        final releasing = Completer<void>();
        native.answers['release'] = () => releasing.future;

        final first = camera.start();
        final stopping = camera.stop();
        final second = camera.start();
        await pumpEventQueue();

        firstOpen.complete();
        await first;
        await pumpEventQueue();
        expect(native.calls.last, 'release');

        expect(await camera.readFrame(), isNull);
        expect(native.calls, isNot(contains('captureFrame')));

        releasing.complete();
        await stopping;
        expect(await second, 7);
        expect(await camera.readFrame(), isNotNull);
      });
    });

    test('stopping after a failed start asks nothing more of the camera', () async {
      native.answers['open'] = () => throw PlatformException(code: 'busy');
      await expectLater(camera.start(), throwsA(isA<QrCameraException>()));

      await camera.stop();

      expect(native.calls, ['open', 'release']);
    });

    test('it can start again after stopping', () async {
      await camera.start();
      await camera.stop();

      expect(await camera.start(), 7);

      expect(native.calls, ['open', 'startPreview', 'release', 'open', 'startPreview']);
    });

    test('it can start again after a failure', () async {
      native.answers['open'] = () => throw PlatformException(code: 'no_camera');
      await expectLater(camera.start(), throwsA(isA<QrCameraException>()));

      native.answers['open'] = () => null;

      expect(await camera.start(), 7);
    });

    test('starting twice without a stop is a mistake in the caller', () async {
      await camera.start();

      await expectLater(camera.start(), throwsStateError);

      expect(native.calls.where((call) => call == 'open'), hasLength(1));
    });

    test('a texture that is not a number is a failure, and the camera is released', () async {
      native.answers['startPreview'] = () => 'not a texture';

      await expectLater(
        camera.start(),
        throwsA(isA<QrCameraException>().having((e) => e.failure, 'failure', QrCameraFailure.failed)),
      );

      expect(native.calls.last, 'release');
    });
  });
}
