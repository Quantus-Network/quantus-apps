import 'dart:async';
import 'dart:typed_data';

import 'package:desktop_qr_camera/desktop_qr_camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:quantus_desktop_wallet/services/qr_frame_decoder.dart';
import 'package:quantus_desktop_wallet/services/qr_scan_source.dart';

QrCameraFrame _frame(int marker) => QrCameraFrame(width: 2, height: 1, luma: Uint8List.fromList([marker, marker]));

class _FakeCamera implements QrCamera {
  final frames = <QrCameraFrame?>[];
  Object? startError;
  Object? readError;
  int starts = 0;
  int stops = 0;
  int reads = 0;

  @override
  Future<int> start() async {
    starts++;
    if (startError case final error?) throw error;
    return 7;
  }

  @override
  Future<void> stop() async => stops++;

  @override
  Future<QrCameraFrame?> readFrame() async {
    reads++;
    if (readError case final error?) throw error;
    return frames.isEmpty ? null : frames.removeAt(0);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDecoder implements QrFrameDecoder {
  _FakeDecoder(this.answer);

  final Future<String?> Function(Uint8List luma) answer;
  bool isClosed = false;

  @override
  Duration get limit => const Duration(seconds: 2);

  @override
  Future<String?> decode(Uint8List luma, int width, int height) => answer(luma);

  @override
  void close() => isClosed = true;
}

class _FakeScannerPlatform extends MobileScannerPlatform {
  final barcodes = StreamController<BarcodeCapture?>.broadcast(sync: true);
  Object? startError;
  Completer<void>? holdStart;
  int starts = 0;
  int stops = 0;

  @override
  Stream<BarcodeCapture?> get barcodesStream => barcodes.stream;

  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();

  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();

  @override
  Widget buildCameraView() => const SizedBox.expand();

  @override
  Future<MobileScannerViewAttributes> start(StartOptions startOptions) async {
    starts++;
    await holdStart?.future;
    if (startError case final error?) throw error;
    return const MobileScannerViewAttributes(
      cameraDirection: CameraFacing.front,
      currentTorchMode: TorchState.unavailable,
      size: Size(1280, 720),
    );
  }

  @override
  Future<void> stop() async => stops++;

  @override
  Future<void> dispose() async {}
}

BarcodeCapture _capture(List<String?> values) =>
    BarcodeCapture(barcodes: [for (final value in values) Barcode(rawValue: value)]);

void main() {
  group('FrameQrScanSource', () {
    late _FakeCamera camera;
    late List<_FakeDecoder> decoders;

    FrameQrScanSource source(Future<String?> Function(Uint8List luma) answer) {
      decoders = [];
      return FrameQrScanSource(
        camera: camera,
        newDecoder: () {
          final decoder = _FakeDecoder(answer);
          decoders.add(decoder);
          return decoder;
        },
        interval: Duration.zero,
      );
    }

    setUp(() => camera = _FakeCamera());

    test('passes on each code it reads', () async {
      camera.frames.addAll([_frame(1), _frame(2)]);
      final scan = source((luma) async => 'code ${luma.first}');
      final reads = <String>[];
      scan.reads.listen(reads.add);

      await scan.start();
      await pumpEventQueue();
      await scan.stop();

      expect(reads, ['code 1', 'code 2']);
    });

    test('a frame with no code passes on nothing', () async {
      camera.frames.add(_frame(1));
      final scan = source((_) async => null);
      final reads = <String>[];
      scan.reads.listen(reads.add);

      await scan.start();
      await pumpEventQueue();
      await scan.stop();

      expect(reads, isEmpty);
    });

    test('reads no new frame while one is being decoded', () async {
      camera.frames.addAll([_frame(1), _frame(2)]);
      final decoding = Completer<String?>();
      final scan = source((_) => decoding.future);

      await scan.start();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(camera.reads, 1);

      decoding.complete(null);
      await pumpEventQueue();
      expect(camera.reads, greaterThan(1));
      await scan.stop();
    });

    test('a camera that fails mid-scan is reported and turned off', () async {
      final scan = source((_) async => null);
      final errors = <Object>[];
      scan.reads.listen(null, onError: errors.add);

      await scan.start();
      camera.readError = const QrCameraException(QrCameraFailure.stopped);
      await pumpEventQueue();

      expect(errors.single, isA<QrCameraException>().having((e) => e.failure, 'failure', QrCameraFailure.stopped));
      expect(camera.stops, 1);
    });

    test('a decoder that breaks is reported as a failed camera and turns it off', () async {
      camera.frames.add(_frame(1));
      final scan = source((_) async => throw const QrDecodeFailure('broken'));
      final errors = <Object>[];
      scan.reads.listen(null, onError: errors.add);

      await scan.start();
      await pumpEventQueue();

      expect(errors.single, isA<QrCameraException>().having((e) => e.failure, 'failure', QrCameraFailure.failed));
      expect(camera.stops, 1);
    });

    test('a code decoded after stop is not passed on', () async {
      camera.frames.add(_frame(1));
      final decoding = Completer<String?>();
      final scan = source((_) => decoding.future);
      final reads = <String>[];
      scan.reads.listen(reads.add);

      await scan.start();
      await pumpEventQueue();
      await scan.stop();
      decoding.complete('late');
      await pumpEventQueue();

      expect(reads, isEmpty);
      expect(decoders.single.isClosed, isTrue);
    });

    test('a failed start is thrown, and no frames are read', () async {
      camera.startError = const QrCameraException(QrCameraFailure.busy);
      final scan = source((_) async => null);

      await expectLater(
        scan.start(),
        throwsA(isA<QrCameraException>().having((e) => e.failure, 'failure', QrCameraFailure.busy)),
      );
      await pumpEventQueue();

      expect(camera.reads, 0);
      expect(decoders.single.isClosed, isTrue);
    });

    test('starting again uses a new decoder', () async {
      final scan = source((_) async => null);

      await scan.start();
      await scan.stop();
      await scan.start();
      await scan.stop();

      expect(decoders, hasLength(2));
      expect(decoders.every((decoder) => decoder.isClosed), isTrue);
    });
  });

  group('MacQrScanSource', () {
    late _FakeScannerPlatform platform;
    late MobileScannerPlatform original;

    setUp(() {
      original = MobileScannerPlatform.instance;
      platform = _FakeScannerPlatform();
      MobileScannerPlatform.instance = platform;
    });

    tearDown(() => MobileScannerPlatform.instance = original);

    Future<MacQrScanSource> mounted(WidgetTester tester) async {
      final scan = MacQrScanSource();
      await tester.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: scan.buildPreview()));
      await tester.pump();
      return scan;
    }

    Future<void> unmount(WidgetTester tester, MacQrScanSource scan) async {
      await scan.dispose();
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    }

    for (final (code, failure) in [
      (MobileScannerErrorCode.permissionDenied, QrCameraFailure.permissionDenied),
      (MobileScannerErrorCode.unsupported, QrCameraFailure.noCamera),
      (MobileScannerErrorCode.genericError, QrCameraFailure.failed),
    ]) {
      testWidgets('a start refused with ${code.name} throws ${failure.name}', (tester) async {
        final scan = await mounted(tester);
        platform.startError = MobileScannerException(errorCode: code);

        await expectLater(scan.start(), throwsA(isA<QrCameraException>().having((e) => e.failure, 'failure', failure)));

        await unmount(tester, scan);
      });
    }

    testWidgets('stop during a start turns the camera off once it is on', (tester) async {
      final scan = await mounted(tester);
      platform.holdStart = Completer<void>();

      final starting = scan.start();
      await tester.pump();
      final stopping = scan.stop();
      await tester.pump();
      expect(platform.stops, 0);

      platform.holdStart!.complete();
      await starting;
      await stopping;

      expect(platform.stops, 1);
      await unmount(tester, scan);
    });

    testWidgets('a stop asked for before its start has begun keeps the camera off', (tester) async {
      final scan = await mounted(tester);

      final starting = scan.start();
      final stopping = scan.stop();
      await starting;
      await stopping;

      expect(platform.starts, 0);
      await unmount(tester, scan);
    });

    testWidgets('passes on a single code, and ignores a capture with none or several', (tester) async {
      final scan = await mounted(tester);
      final reads = <String>[];
      final subscription = scan.reads.listen(reads.add);
      await scan.start();

      platform.barcodes.add(_capture(['one']));
      platform.barcodes.add(_capture([null]));
      platform.barcodes.add(_capture(['two', 'three']));
      platform.barcodes.add(_capture(const []));
      await tester.pump();

      expect(reads, ['one']);
      // Not awaited: its future belongs to the root zone, and resuming there
      // leaves the test's fake clock with nothing to run what follows.
      unawaited(subscription.cancel());
      await unmount(tester, scan);
    });

    testWidgets('a scanning error is reported as a failed camera and turns it off', (tester) async {
      final scan = await mounted(tester);
      final errors = <Object>[];
      final subscription = scan.reads.listen(null, onError: errors.add);
      await scan.start();

      platform.barcodes.addError(const MobileScannerBarcodeException('broken'));
      await tester.pump();

      expect(errors.single, isA<QrCameraException>().having((e) => e.failure, 'failure', QrCameraFailure.failed));
      expect(platform.stops, 1);
      unawaited(subscription.cancel());
      await unmount(tester, scan);
    });
  });
}
