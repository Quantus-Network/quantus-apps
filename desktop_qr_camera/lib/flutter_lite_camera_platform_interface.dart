import 'package:flutter/widgets.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_lite_camera_method_channel.dart';

/// Common capture resolution targets for
/// [FlutterLiteCameraPlatform.setResolution].
///
/// A preset is a target, not a guarantee: every platform negotiates with the
/// device and activates the closest supported size. Mobile camera sensors are
/// physically landscape, so a portrait-shaped target simply selects the
/// matching landscape sensor size. The actual negotiated size is reported by
/// [FlutterLiteCameraPlatform.getWidth],
/// [FlutterLiteCameraPlatform.getHeight], and every
/// [FlutterLiteCameraPlatform.captureFrame] result.
enum ResolutionPreset {
  /// 320x240 (QVGA).
  low(320, 240),

  /// 640x480 (VGA).
  medium(640, 480),

  /// 1280x720 (HD).
  high(1280, 720),

  /// 1920x1080 (Full HD).
  veryHigh(1920, 1080),

  /// 3840x2160 (4K UHD).
  ultraHigh(3840, 2160),

  /// Effectively the largest size the device supports.
  max(7680, 4320);

  const ResolutionPreset(this.width, this.height);

  /// Target width in pixels (landscape reference).
  final int width;

  /// Target height in pixels (landscape reference).
  final int height;
}

abstract class FlutterLiteCameraPlatform extends PlatformInterface {
  /// Constructs a FlutterLiteCameraPlatform.
  FlutterLiteCameraPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterLiteCameraPlatform _instance = MethodChannelFlutterLiteCamera();

  /// The default instance of [FlutterLiteCameraPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterLiteCamera].
  static FlutterLiteCameraPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterLiteCameraPlatform] when
  /// they register themselves.
  static set instance(FlutterLiteCameraPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Lists available video capture devices.
  Future<List<String>> getDeviceList() {
    throw UnimplementedError('getDeviceList() has not been implemented.');
  }

  /// Opens the camera with the specified index.
  Future<bool> open(int index) {
    throw UnimplementedError('open() has not been implemented.');
  }

  /// Captures a single RGB frame from the camera.
  ///
  /// While a preview is running (see [startPreview]) this returns the latest
  /// frame from the native frame cache without disturbing the video stream.
  ///
  /// On Android the returned frame is rotated to match the on-screen preview
  /// (the display pipeline already orients the preview), so coordinates
  /// derived from the frame map 1:1 onto the displayed image.
  Future<Map<String, dynamic>> captureFrame({int byteOrder = 2}) {
    throw UnimplementedError('captureFrame() has not been implemented.');
  }

  /// Starts the native preview stream and returns a texture id.
  ///
  /// The camera must be opened with [open] first. Pass the returned id to
  /// [buildPreview] to display the video feed. Frames are drawn entirely at
  /// the native layer; no pixel data crosses the platform channel.
  Future<int> startPreview() {
    throw UnimplementedError('startPreview() has not been implemented.');
  }

  /// Builds the widget that renders the preview started with [startPreview].
  ///
  /// On the desktop and mobile implementations this is a zero-copy [Texture]
  /// fed by the native frame producer. The web implementation overrides this
  /// to return an `HtmlElementView` hosting the `getUserMedia` stream.
  Widget buildPreview(int textureId) {
    return Texture(textureId: textureId);
  }

  /// Stops the preview stream and unregisters the texture.
  Future<void> stopPreview() {
    throw UnimplementedError('stopPreview() has not been implemented.');
  }

  /// Sets the capture resolution in pixels.
  ///
  /// The value is a target: each platform negotiates the closest supported
  /// size with the device (a portrait request maps to the equivalent
  /// landscape sensor size on mobile). The actual size is available through
  /// [getWidth]/[getHeight] and every [captureFrame] result. Returns false
  /// when no camera is open.
  Future<bool> setResolution(int width, int height) {
    throw UnimplementedError('setResolution() has not been implemented.');
  }

  /// Convenience for [setResolution] using a [ResolutionPreset] target.
  Future<bool> setResolutionPreset(ResolutionPreset preset) {
    return setResolution(preset.width, preset.height);
  }

  /// The actual capture width negotiated with the device, in pixels
  /// (0 when no camera is open).
  Future<int> getWidth() {
    throw UnimplementedError('getWidth() has not been implemented.');
  }

  /// The actual capture height negotiated with the device, in pixels
  /// (0 when no camera is open).
  Future<int> getHeight() {
    throw UnimplementedError('getHeight() has not been implemented.');
  }

  /// Releases the camera and associated resources.
  Future<void> release() {
    throw UnimplementedError('release() has not been implemented.');
  }

  /// Returns the clockwise rotation in degrees (0, 90, 180, or 270) that must
  /// be applied to the camera preview and any coordinates derived from
  /// [captureFrame] so they appear upright for the current device orientation.
  ///
  /// iOS reports a non-zero value on phones (the sensor is physically
  /// landscape and its buffers reach Dart unrotated). On Android the display
  /// pipeline already orients the preview texture (the same behavior the
  /// official camera plugin relies on), so this is typically 0; captured
  /// frames are rotated natively to match. Desktops and web report 0. The
  /// preview itself is never rotated at the pixel level on iOS/desktop —
  /// apply the returned angle to the preview [Widget] and to decoded result
  /// coordinates in Dart.
  Future<int> getRotation() {
    throw UnimplementedError('getRotation() has not been implemented.');
  }
}
