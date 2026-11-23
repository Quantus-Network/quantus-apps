import 'package:flutter/widgets.dart';

import 'flutter_lite_camera_platform_interface.dart';

export 'flutter_lite_camera_platform_interface.dart' show ResolutionPreset;

class FlutterLiteCamera {
  Future<List<String>> getDeviceList() {
    return FlutterLiteCameraPlatform.instance.getDeviceList();
  }

  Future<bool> open(int index) {
    return FlutterLiteCameraPlatform.instance.open(index);
  }

  /// [byteOrder] selects the output channel arrangement of the RGB888
  /// buffer on Android: 0=RGB, 1=RBG, 2=GRB, 3=GBR, 4=BRG, 5=BGR.
  /// The default (GRB) is verified against on-device colors; other devices
  /// can pass a different order if their HAL lays the chroma out
  /// differently.
  Future<Map<String, dynamic>> captureFrame({int byteOrder = 2}) {
    return FlutterLiteCameraPlatform.instance.captureFrame(byteOrder: byteOrder);
  }

  /// Starts the native preview stream and returns a texture id that can be
  /// shown with [buildPreview]. Call [open] before this.
  Future<int> startPreview() {
    return FlutterLiteCameraPlatform.instance.startPreview();
  }

  /// Builds the widget that displays the preview for [textureId].
  ///
  /// Use this instead of a raw [Texture] widget so the plugin can pick the
  /// right rendering path per platform (zero-copy texture on native, an
  /// embedded video element on the web).
  Widget buildPreview(int textureId) {
    return FlutterLiteCameraPlatform.instance.buildPreview(textureId);
  }

  /// Stops the preview stream started with [startPreview].
  Future<void> stopPreview() {
    return FlutterLiteCameraPlatform.instance.stopPreview();
  }

  /// Sets the capture resolution in pixels.
  ///
  /// The value is a target: each platform negotiates the closest supported
  /// size with the device (a portrait request maps to the equivalent
  /// landscape sensor size on mobile). Query the actual size with
  /// [getWidth]/[getHeight]; every [captureFrame] also reports it. Returns
  /// false when no camera is open.
  Future<bool> setResolution(int width, int height) {
    return FlutterLiteCameraPlatform.instance.setResolution(width, height);
  }

  /// Convenience for [setResolution] using a [ResolutionPreset] target.
  Future<bool> setResolutionPreset(ResolutionPreset preset) {
    return FlutterLiteCameraPlatform.instance.setResolutionPreset(preset);
  }

  /// The actual capture width negotiated with the device, in pixels
  /// (0 when no camera is open).
  Future<int> getWidth() {
    return FlutterLiteCameraPlatform.instance.getWidth();
  }

  /// The actual capture height negotiated with the device, in pixels
  /// (0 when no camera is open).
  Future<int> getHeight() {
    return FlutterLiteCameraPlatform.instance.getHeight();
  }

  Future<void> release() {
    return FlutterLiteCameraPlatform.instance.release();
  }

  /// Returns the clockwise rotation in degrees (0, 90, 180, 270) to apply to
  /// the preview and decoded coordinates so they display upright.
  ///
  /// Native pixels are untouched on iOS/desktop; rotate the preview [Widget]
  /// and the result coordinates by this angle in Dart. On Android the
  /// display pipeline already orients the preview (and `captureFrame`
  /// returns display-oriented frames), so this is typically 0.
  Future<int> getRotation() {
    return FlutterLiteCameraPlatform.instance.getRotation();
  }
}
