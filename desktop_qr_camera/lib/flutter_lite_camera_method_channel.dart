import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_lite_camera_platform_interface.dart';

/// An implementation of [FlutterLiteCameraPlatform] that uses method channels.
class MethodChannelFlutterLiteCamera extends FlutterLiteCameraPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_lite_camera');

  /// Lists the available video capture devices.
  ///
  /// Returns a [Future] that completes with a list of device names as strings.
  @override
  Future<List<String>> getDeviceList() async {
    List<dynamic> devices = await methodChannel.invokeMethod('getDeviceList');
    return devices.cast<String>();
  }

  /// Opens the camera with the specified index.
  ///
  /// Takes an [index] as a parameter to specify the camera to open.
  /// Returns a [Future] that completes with a boolean indicating success or failure.
  @override
  Future<bool> open(int index) async {
    bool success = await methodChannel.invokeMethod('open', [index]);
    return success;
  }

  /// Captures a frame from the camera.
  ///
  /// Returns a [Future] that completes with a map containing the frame RGB88 data, width, and height.
  @override
  Future<Map<String, dynamic>> captureFrame({int byteOrder = 2}) async {
    Map<dynamic, dynamic> frame = await methodChannel
        .invokeMethod('captureFrame', {'byteOrder': byteOrder});
    return frame.cast<String, dynamic>();
  }

  /// Starts the native preview stream.
  ///
  /// Returns a [Future] that completes with the texture id used by a
  /// [Texture] widget to display the feed.
  @override
  Future<int> startPreview() async {
    final int textureId = await methodChannel.invokeMethod('startPreview');
    return textureId;
  }

  /// Stops the native preview stream and unregisters the texture.
  @override
  Future<void> stopPreview() async {
    await methodChannel.invokeMethod('stopPreview');
  }

  /// Sets the capture resolution in pixels; the platform negotiates the
  /// closest supported size with the device.
  @override
  Future<bool> setResolution(int width, int height) async {
    final bool success =
        await methodChannel.invokeMethod('setResolution', [width, height]);
    return success;
  }

  /// Returns the actual capture width negotiated with the device.
  @override
  Future<int> getWidth() async {
    return await methodChannel.invokeMethod('getWidth') as int;
  }

  /// Returns the actual capture height negotiated with the device.
  @override
  Future<int> getHeight() async {
    return await methodChannel.invokeMethod('getHeight') as int;
  }

  /// Releases the camera resources.
  ///
  /// Returns a [Future] that completes when the resources are released.
  @override
  Future<void> release() async {
    await methodChannel.invokeMethod('release');
  }

  /// Returns the clockwise preview rotation in degrees. Desktop and web
  /// platforms that do not implement the native method return 0.
  @override
  Future<int> getRotation() async {
    try {
      return await methodChannel.invokeMethod('getRotation') as int;
    } on MissingPluginException {
      return 0;
    }
  }
}
