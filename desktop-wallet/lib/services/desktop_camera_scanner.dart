import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_zxing/flutter_zxing.dart' as zxing;
import 'package:quantus_sdk/quantus_sdk.dart';

/// A desktop webcam feeding decoded QR codes to a scanner view. Frames are
/// decoded off the UI isolate; a frame that arrives while one is still being
/// decoded is dropped.
class DesktopCameraScanner {
  static final _decodeParams = zxing.DecodeParams(
    imageFormat: zxing.ImageFormat.bgra,
    format: zxing.Format.qrCode,
    tryInverted: true,
    tryRotate: false,
    maxSize: 768,
  );

  final CameraDescription camera;
  final CameraController controller;
  final StreamController<QrDetection> _detections = StreamController.broadcast();
  bool _busy = false;
  bool _streaming = false;

  DesktopCameraScanner(this.camera)
    : controller = CameraController(camera, ResolutionPreset.high, enableAudio: false, fps: 30);

  static Future<List<CameraDescription>> list() => availableCameras();

  Stream<QrDetection> get detections => _detections.stream;

  /// Windows previews are flipped in Flutter while the frames are not; the
  /// other desktops mirror both natively.
  bool get mirrored => Platform.isWindows;

  Future<void> start() async {
    await controller.initialize();
    await zxing.zx.startCameraProcessing();
    await resume();
  }

  Future<void> pause() async {
    if (!_streaming) return;
    _streaming = false;
    await controller.stopImageStream();
  }

  Future<void> resume() async {
    if (_streaming) return;
    _streaming = true;
    await controller.startImageStream(_onImage);
  }

  Future<void> _onImage(CameraImage image) async {
    if (_busy || !_streaming) return;
    _busy = true;
    try {
      final code = await zxing.zx.processCameraImage(image, _decodeParams);
      final text = code.text;
      final position = code.position;
      if (!code.isValid || text == null || position == null || _detections.isClosed) return;
      _detections.add(
        QrDetection(
          raw: text,
          corners: [
            Offset(position.topLeftX.toDouble(), position.topLeftY.toDouble()),
            Offset(position.topRightX.toDouble(), position.topRightY.toDouble()),
            Offset(position.bottomRightX.toDouble(), position.bottomRightY.toDouble()),
            Offset(position.bottomLeftX.toDouble(), position.bottomLeftY.toDouble()),
          ],
          imageSize: Size(position.imageWidth.toDouble(), position.imageHeight.toDouble()),
        ),
      );
    } catch (e) {
      debugPrint('QR decode failed: $e');
    } finally {
      _busy = false;
    }
  }

  Future<void> dispose() async {
    await pause();
    zxing.zx.stopCameraProcessing();
    await controller.dispose();
    await _detections.close();
  }
}
