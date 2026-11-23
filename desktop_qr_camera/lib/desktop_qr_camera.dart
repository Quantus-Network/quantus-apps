import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Why the camera cannot be used, each a different thing to tell the person.
enum QrCameraFailure {
  noCamera,
  permissionDenied,
  busy,

  /// The camera offers no picture format this package can read.
  unsupported,

  /// Windows without its Media Feature Pack, which cameras need.
  mediaUnavailable,

  /// It was working and stopped, as when it is unplugged.
  stopped,
  failed,
}

class QrCameraException implements Exception {
  const QrCameraException(this.failure, {this.detail});

  final QrCameraFailure failure;
  final String? detail;

  @override
  String toString() => 'QrCameraException(${failure.name}${detail == null ? '' : ': $detail'})';
}

/// One camera frame, as the brightness of each pixel, row by row.
class QrCameraFrame {
  const QrCameraFrame({required this.width, required this.height, required this.luma});

  final int width;
  final int height;
  final Uint8List luma;
}

/// The computer's first camera on Windows and Linux. macOS has its own scanner
/// and does not use this.
///
/// [start] and [stop] run one at a time, in the order they were called, so the
/// camera is never released while it is still being opened.
class QrCamera {
  /// The longest side of a frame that is accepted; the native code's limit.
  static const maxFrameSide = 4096;

  static const _channel = MethodChannel('desktop_qr_camera');

  static const _failures = {
    'no_camera': QrCameraFailure.noCamera,
    'permission_denied': QrCameraFailure.permissionDenied,
    'busy': QrCameraFailure.busy,
    'unsupported': QrCameraFailure.unsupported,
    'media_unavailable': QrCameraFailure.mediaUnavailable,
    'stopped': QrCameraFailure.stopped,
    'failed': QrCameraFailure.failed,
  };

  Future<void> _queue = Future.value();

  /// Between a [start] and its [stop].
  bool _isWanted = false;

  /// Whether the native camera may hold anything that needs releasing.
  bool _needsRelease = false;

  /// Whether frames can be read.
  bool _isRunning = false;

  /// Opens the camera and its preview, and returns the preview's texture.
  /// Throws [QrCameraException] when it cannot, with nothing left open.
  Future<int> start() async {
    if (_isWanted) throw StateError('The camera was started twice.');
    _isWanted = true;
    return _inTurn(_open);
  }

  /// Turns the camera off. Safe to call at any time.
  Future<void> stop() {
    if (!_isWanted) return _queue;
    _isWanted = false;
    _isRunning = false;
    return _inTurn(_release);
  }

  /// The newest frame not read yet. Null when there is none, when the camera
  /// is not running, or when the frame does not hold what it claims. Throws
  /// [QrCameraException] when the camera has failed.
  Future<QrCameraFrame?> readFrame() async {
    if (!_isRunning) return null;
    final Object? answer;
    try {
      answer = await _channel.invokeMethod<Object?>('captureFrame');
    } on PlatformException catch (error) {
      throw _exceptionOf(error);
    }
    return _isRunning ? _frameOf(answer) : null;
  }

  Future<T> _inTurn<T>(Future<T> Function() step) {
    final result = _queue.then((_) => step());
    _queue = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  Future<int> _open() async {
    _needsRelease = true;
    try {
      await _channel.invokeMethod<void>('open');
      final texture = await _channel.invokeMethod<Object?>('startPreview');
      if (texture is! int) {
        throw QrCameraException(QrCameraFailure.failed, detail: 'The preview gave no texture: $texture');
      }
      _isRunning = _isWanted;
      return texture;
    } on PlatformException catch (error) {
      await _releaseAfterFailure();
      throw _exceptionOf(error);
    } on QrCameraException {
      await _releaseAfterFailure();
      rethrow;
    }
  }

  Future<void> _release() async {
    if (!_needsRelease) return;
    _needsRelease = false;
    try {
      await _channel.invokeMethod<void>('release');
    } on PlatformException catch (error) {
      throw _exceptionOf(error);
    }
  }

  /// Releases what a failed start left. The failure that started this is the
  /// one to report, so a second one is only logged.
  Future<void> _releaseAfterFailure() async {
    _isWanted = false;
    _isRunning = false;
    try {
      await _release();
    } on QrCameraException catch (error) {
      debugPrint('The camera could not be released after a failed start: $error');
    }
  }

  static QrCameraException _exceptionOf(PlatformException error) {
    final failure = _failures[error.code];
    return failure == null
        ? QrCameraException(QrCameraFailure.failed, detail: '${error.code}: ${error.message}')
        : QrCameraException(failure, detail: error.message);
  }

  static QrCameraFrame? _frameOf(Object? answer) {
    if (answer is! Map) return null;
    final width = answer['width'];
    final height = answer['height'];
    final luma = answer['luma'];
    if (width is! int || height is! int || luma is! Uint8List) return null;
    if (width <= 0 || height <= 0 || width > maxFrameSide || height > maxFrameSide) return null;
    if (luma.length != width * height) return null;
    return QrCameraFrame(width: width, height: height, luma: luma);
  }
}
