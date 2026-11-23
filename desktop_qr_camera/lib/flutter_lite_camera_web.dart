// The web implementation uses browser DOM APIs by design.
// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as dom;

import 'flutter_lite_camera_platform_interface.dart';

/// A web implementation of [FlutterLiteCameraPlatform] backed by
/// `navigator.mediaDevices.getUserMedia`.
///
/// The preview is rendered with a hidden `HTMLVideoElement` hosted in a web
/// platform view, so frames never cross a platform channel at all —
/// [buildPreview] returns an [HtmlElementView] instead of a [Texture].
/// [captureFrame] draws the current video frame onto an offscreen canvas on
/// demand and returns RGB888 bytes, the same contract as the native
/// platforms.
class FlutterLiteCameraWeb extends FlutterLiteCameraPlatform {
  /// Constructs a FlutterLiteCameraWeb.
  FlutterLiteCameraWeb();

  /// Registers this class as the default instance of [FlutterLiteCameraPlatform].
  static void registerWith(Registrar registrar) {
    FlutterLiteCameraPlatform.instance = FlutterLiteCameraWeb();
  }

  final List<dom.MediaDeviceInfo> _videoDevices = [];
  dom.MediaStream? _stream;
  dom.HTMLVideoElement? _videoElement;

  int _nextTextureId = 1;
  final Map<int, String> _viewTypes = {};

  @override
  Future<List<String>> getDeviceList() async {
    // Device labels are only populated once permission has been granted, so
    // briefly acquire a stream first (the same approach camera_web uses),
    // then stop every track immediately.
    await _requestTemporaryStream();

    final devices =
        (await dom.window.navigator.mediaDevices.enumerateDevices().toDart)
            .toDart;
    _videoDevices
      ..clear()
      ..addAll(devices.where(
          (device) => device.kind == 'videoinput' && device.deviceId.isNotEmpty));

    final names = <String>[];
    for (var i = 0; i < _videoDevices.length; i++) {
      final label = _videoDevices[i].label;
      names.add(label.isNotEmpty ? label : 'Camera $i');
    }
    return names;
  }

  Future<void> _requestTemporaryStream() async {
    final stream = await dom.window.navigator.mediaDevices
        .getUserMedia(
            dom.MediaStreamConstraints(video: true.toJS, audio: false.toJS))
        .toDart;
    for (final track in stream.getTracks().toDart) {
      track.stop();
    }
  }

  @override
  Future<bool> open(int index) async {
    await release();

    if (_videoDevices.isEmpty) {
      await getDeviceList();
    }
    if (index >= _videoDevices.length) {
      return false;
    }

    final deviceId = _videoDevices[index].deviceId;
    final constraints = dom.MediaStreamConstraints(
      video: dom.MediaTrackConstraints(deviceId: deviceId.toJS),
      audio: false.toJS,
    );

    try {
      _stream = await dom.window.navigator.mediaDevices
          .getUserMedia(constraints)
          .toDart;
    } catch (e) {
      _stream = null;
      return false;
    }

    final tracks = _stream!.getVideoTracks().toDart;
    if (tracks.isEmpty) {
      _stopStream();
      return false;
    }

    // The video element feeds both the platform-view preview and the
    // captureFrame() draws. muted + playsinline is required for autoplay.
    _videoElement = dom.HTMLVideoElement()
      ..autoplay = true
      ..muted = true
      ..setAttribute('playsinline', '')
      ..srcObject = _stream;
    await _play();

    return true;
  }

  Future<void> _play() async {
    final element = _videoElement;
    if (element == null) return;
    // Browsers may reject autoplay before a user gesture; retry at preview
    // start time.
    try {
      await element.play().toDart;
    } catch (e) {
      // Ignore until the next play() attempt.
    }
  }

  void _stopStream() {
    final stream = _stream;
    if (stream != null) {
      for (final track in stream.getTracks().toDart) {
        track.stop();
      }
    }
    _stream = null;
    final element = _videoElement;
    if (element != null) {
      element.srcObject = null;
    }
    _videoElement = null;
  }

  @override
  Future<int> startPreview() async {
    final element = _videoElement;
    if (element == null) {
      throw PlatformException(
          code: 'CAMERA_ERROR', message: 'Camera is not open.');
    }

    await _play();

    final id = _nextTextureId++;
    final viewType = 'flutter_lite_camera_$id';
    _viewTypes[id] = viewType;

    // Wrap the video in a sized div so the platform view fills its slot with
    // object-fit behavior from the video element itself.
    element.style
      ..width = '100%'
      ..height = '100%'
      ..objectFit = 'cover';
    final wrapper = dom.HTMLDivElement()
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.overflow = 'hidden'
      ..append(element);
    ui_web.platformViewRegistry.registerViewFactory(viewType, (_) => wrapper);
    return id;
  }

  @override
  Future<void> stopPreview() async {
    // Dropping the view type makes buildPreview return an empty widget, so
    // Flutter tears the platform view down by itself. The media stream keeps
    // running so captureFrame() and a later startPreview() still work.
    _viewTypes.clear();
  }

  @override
  Widget buildPreview(int textureId) {
    final viewType = _viewTypes[textureId];
    if (viewType == null) {
      return const SizedBox.shrink();
    }
    return HtmlElementView(viewType: viewType);
  }

  @override
  Future<Map<String, dynamic>> captureFrame({int byteOrder = 2}) async {
    final element = _videoElement;
    if (element == null) {
      throw PlatformException(
          code: 'CAPTURE_FAILED', message: 'No frame available.');
    }

    // Wait for frame metadata the first time so width/height are non-zero.
    if (element.videoWidth == 0) {
      final completer = Completer<void>();
      // The same JS function object must be used for add and remove, so the
      // closure captures the converted callback through a late variable.
      late final JSFunction metadataCallback;
      metadataCallback = ((dom.Event _) {
        element.removeEventListener('loadedmetadata', metadataCallback);
        if (!completer.isCompleted) completer.complete();
      }).toJS;
      element.addEventListener('loadedmetadata', metadataCallback);
      await completer.future
          .timeout(const Duration(seconds: 2), onTimeout: () {});
    }

    final width = element.videoWidth;
    final height = element.videoHeight;
    if (width == 0 || height == 0) {
      throw PlatformException(
          code: 'CAPTURE_FAILED', message: 'No frame available.');
    }

    final canvas = dom.HTMLCanvasElement()
      ..width = width
      ..height = height;
    final context = canvas.context2D;
    context.drawImage(element, 0, 0, width.toDouble(), height.toDouble());

    final rgba = context.getImageData(0, 0, width, height).data.toDart;

    final rgb = Uint8List(width * height * 3);
    for (var src = 0, dst = 0; dst < rgb.length; src += 4, dst += 3) {
      rgb[dst] = rgba[src];
      rgb[dst + 1] = rgba[src + 1];
      rgb[dst + 2] = rgba[src + 2];
    }

    return <String, dynamic>{'width': width, 'height': height, 'data': rgb};
  }

  @override
  Future<void> release() async {
    _viewTypes.clear();
    _stopStream();
  }

  @override
  Future<int> getRotation() async {
    // Browsers auto-rotate the getUserMedia stream to match the page, so the
    // preview is already upright.
    return 0;
  }

  @override
  Future<bool> setResolution(int width, int height) async {
    final tracks = _stream?.getVideoTracks().toDart;
    if (tracks == null || tracks.isEmpty) return false;
    try {
      // Browsers treat these as ideals and pick the closest supported mode,
      // the same negotiation the native platforms do.
      await tracks.first
          .applyConstraints(dom.MediaTrackConstraints(
              width: width.toJS, height: height.toJS))
          .toDart;
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<int> getWidth() async => _videoElement?.videoWidth ?? 0;

  @override
  Future<int> getHeight() async => _videoElement?.videoHeight ?? 0;
}
