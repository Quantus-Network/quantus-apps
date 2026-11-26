import 'dart:async';

import 'package:desktop_qr_camera/desktop_qr_camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
// The package's only way to release a failed start ([MacQrScanSource]).
// ignore: implementation_imports
import 'package:mobile_scanner/src/method_channel/mobile_scanner_method_channel.dart';
import 'package:quantus_desktop_wallet/services/qr_frame_decoder.dart';
import 'package:quantus_desktop_wallet/utils/serial_queue.dart';

/// A camera reading QR codes, the same to the sheet on every platform.
abstract interface class QrScanSource {
  /// Each code read, one per frame. A camera that fails once running is an
  /// error here, a [QrCameraException], and it is off by then.
  Stream<String> get reads;

  /// Turns the camera on. Throws [QrCameraException] when it cannot.
  Future<void> start();

  /// Turns the camera off. Safe to call at any time.
  Future<void> stop();

  /// The camera's picture, filling the space it is given.
  Widget buildPreview();

  /// Turns the camera off for good.
  Future<void> dispose();
}

/// Makes the scan source for this platform: macOS has `mobile_scanner`, and
/// Windows and Linux our own camera with a decoder.
final qrScanSourceFactoryProvider = Provider<QrScanSource Function()>(
  (ref) =>
      () => defaultTargetPlatform == TargetPlatform.macOS ? MacQrScanSource() : FrameQrScanSource(),
);

/// Makes the scan source for an animated code, whose frames change faster
/// than one read every 200 ms: macOS reads every frame. Windows and Linux
/// read as for one code.
final animatedQrScanSourceFactoryProvider = Provider<QrScanSource Function()>(
  (ref) =>
      () =>
          defaultTargetPlatform == TargetPlatform.macOS ? MacQrScanSource(readsEveryFrame: true) : FrameQrScanSource(),
);

/// Windows and Linux: reads the newest frame about five times a second and
/// decodes it in a worker. A frame that arrives during a decode is never
/// queued, as the next read takes only the newest.
class FrameQrScanSource implements QrScanSource {
  FrameQrScanSource({
    QrCamera? camera,
    QrFrameDecoder Function()? newDecoder,
    this.interval = const Duration(milliseconds: 200),
  }) : _camera = camera ?? QrCamera(),
       _newDecoder = newDecoder ?? QrFrameDecoder.new;

  final QrCamera _camera;
  final QrFrameDecoder Function() _newDecoder;
  final Duration interval;

  final _reads = StreamController<String>.broadcast();
  final _picture = ValueNotifier<({int texture, Size size})?>(null);

  /// Which start is current: a read still running for an earlier one stops.
  int _run = 0;
  QrFrameDecoder? _decoder;

  @override
  Stream<String> get reads => _reads.stream;

  @override
  Future<void> start() async {
    final run = ++_run;
    final decoder = _decoder = _newDecoder();
    final int texture;
    try {
      texture = await _camera.start();
    } catch (_) {
      if (run == _run) _closeDecoder();
      rethrow;
    }
    if (run == _run) unawaited(_readFrames(run, texture, decoder));
  }

  Future<void> _readFrames(int run, int texture, QrFrameDecoder decoder) async {
    while (run == _run) {
      try {
        final frame = await _camera.readFrame();
        if (run != _run) return;
        if (frame != null) {
          _picture.value = (texture: texture, size: Size(frame.width.toDouble(), frame.height.toDouble()));
          final text = await decoder.decode(frame.luma, frame.width, frame.height);
          if (run != _run) return;
          if (text != null) _reads.add(text);
        }
      } on QrCameraException catch (error) {
        await _fail(run, error);
        return;
      } on QrDecodeFailure catch (error) {
        await _fail(run, QrCameraException(QrCameraFailure.failed, detail: error.detail));
        return;
      }
      await Future<void>.delayed(interval);
    }
  }

  Future<void> _fail(int run, QrCameraException error) async {
    if (run != _run) return;
    await stop();
    if (!_reads.isClosed) _reads.addError(error);
  }

  void _closeDecoder() {
    _decoder?.close();
    _decoder = null;
  }

  @override
  Future<void> stop() {
    _run++;
    _closeDecoder();
    _picture.value = null;
    return _camera.stop();
  }

  @override
  Widget buildPreview() => ValueListenableBuilder(
    valueListenable: _picture,
    builder: (context, picture, _) => picture == null
        ? const SizedBox.expand()
        : SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox.fromSize(
                size: picture.size,
                child: Texture(textureId: picture.texture),
              ),
            ),
          ),
  );

  @override
  Future<void> dispose() async {
    await stop();
    await _reads.close();
    _picture.dispose();
  }
}

/// macOS, through `mobile_scanner`. Its controller keeps a failed start's
/// error to itself and ignores a stop while it is starting, so starts and
/// stops take turns here and each start's outcome is checked.
///
/// It reads a frame every 200 ms, or, with [readsEveryFrame], every frame the
/// camera gives, as an animated code needs.
class MacQrScanSource implements QrScanSource {
  MacQrScanSource({bool readsEveryFrame = false})
    : _controller = MobileScannerController(
        autoStart: false,
        formats: const [BarcodeFormat.qrCode],
        detectionSpeed: readsEveryFrame ? DetectionSpeed.unrestricted : DetectionSpeed.normal,
        detectionTimeoutMs: 200,
      );

  final MobileScannerController _controller;
  final _turns = SerialQueue();

  /// Whether the last call was a start: one that has not begun by the time
  /// a stop follows it never turns the camera on.
  bool _isWanted = false;

  @override
  late final Stream<String> reads = _controller.barcodes.transform(
    StreamTransformer.fromHandlers(
      handleData: (capture, sink) {
        // Two codes in view cannot be told apart, so neither is taken.
        if (capture.barcodes case [Barcode(:final rawValue?)]) sink.add(rawValue);
      },
      handleError: (error, stackTrace, sink) {
        unawaited(_stopAfterFailure());
        sink.addError(_scanningExceptionOf(error), stackTrace);
      },
    ),
  );

  /// What the patched Swift sends when the camera is unplugged or its
  /// session fails while running (`third_party/mobile_scanner/PATCHES.md`).
  static const _cameraStoppedCode = 'MOBILE_SCANNER_CAMERA_STOPPED';

  static QrCameraException _scanningExceptionOf(Object error) => switch (error) {
    PlatformException(code: _cameraStoppedCode, :final message) => QrCameraException(
      QrCameraFailure.stopped,
      detail: message,
    ),
    _ => QrCameraException(QrCameraFailure.failed, detail: '$error'),
  };

  /// The failure that started this is the one to report, so a second one is
  /// only logged.
  Future<void> _stopAfterFailure() async {
    try {
      await stop();
    } catch (error) {
      debugPrint('The camera could not be turned off after a failure: $error');
    }
  }

  @override
  Future<void> start() {
    _isWanted = true;
    return _turns.run(() async {
      if (!_isWanted) return;
      await _controller.start();
      final state = _controller.value;
      if (state.isRunning) return;
      await _releaseFailedStart();
      throw _exceptionOf(state.error);
    });
  }

  /// A native start that fails keeps the session and texture it allocated,
  /// and refuses every later start until they are released. The controller's
  /// stop skips a camera that is not running, so only a forced stop on the
  /// channel reaches them. The failure that started this is the one to
  /// report, so a second one is only logged.
  static Future<void> _releaseFailedStart() async {
    try {
      if (MobileScannerPlatform.instance case final MethodChannelMobileScanner channel) {
        await channel.stop(force: true);
      }
    } catch (error) {
      debugPrint('The camera could not be released after a failed start: $error');
    }
  }

  @override
  Future<void> stop() {
    _isWanted = false;
    return _turns.run(_controller.stop);
  }

  static QrCameraException _exceptionOf(MobileScannerException? error) => QrCameraException(switch (error?.errorCode) {
    MobileScannerErrorCode.permissionDenied => QrCameraFailure.permissionDenied,
    // What the package reports when the computer has no camera.
    MobileScannerErrorCode.unsupported => QrCameraFailure.noCamera,
    _ => QrCameraFailure.failed,
  }, detail: error?.errorDetails?.message);

  @override
  Widget buildPreview() => MobileScanner(controller: _controller, fit: BoxFit.cover);

  @override
  Future<void> dispose() async {
    await stop();
    await _controller.dispose();
  }
}
