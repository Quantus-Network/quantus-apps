import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/quantus_sdk_riverpod.dart';

/// How the animated sign-request QR is rendered. Defaults match the cold
/// wallet's own display so both directions behave alike.
class QrDisplaySettings {
  static const defaultFps = 10;
  static const defaultBytesPerFrame = 300;
  static const minFps = 4;
  static const maxFps = 20;
  static const minBytesPerFrame = 100;
  static const maxBytesPerFrame = 600;

  final int fps;
  final int bytesPerFrame;

  const QrDisplaySettings({this.fps = defaultFps, this.bytesPerFrame = defaultBytesPerFrame});

  QrDisplaySettings copyWith({int? fps, int? bytesPerFrame}) =>
      QrDisplaySettings(fps: fps ?? this.fps, bytesPerFrame: bytesPerFrame ?? this.bytesPerFrame);
}

class QrDisplaySettingsNotifier extends StateNotifier<QrDisplaySettings> {
  static const _fpsKey = 'desktop_qr_fps';
  static const _bytesKey = 'desktop_qr_bytes_per_frame';

  final SettingsService _settings;

  QrDisplaySettingsNotifier(this._settings) : super(_load(_settings));

  static QrDisplaySettings _load(SettingsService settings) => QrDisplaySettings(
    fps: int.tryParse(settings.getString(_fpsKey) ?? '') ?? QrDisplaySettings.defaultFps,
    bytesPerFrame: int.tryParse(settings.getString(_bytesKey) ?? '') ?? QrDisplaySettings.defaultBytesPerFrame,
  );

  Future<void> setFps(int fps) async {
    await _settings.setString(_fpsKey, '$fps');
    state = state.copyWith(fps: fps);
  }

  Future<void> setBytesPerFrame(int bytes) async {
    await _settings.setString(_bytesKey, '$bytes');
    state = state.copyWith(bytesPerFrame: bytes);
  }
}

final qrDisplaySettingsProvider = StateNotifierProvider<QrDisplaySettingsNotifier, QrDisplaySettings>(
  (ref) => QrDisplaySettingsNotifier(ref.watch(settingsServiceProvider)),
);

/// Name of the camera the user picked; null means the first one found.
class SelectedCameraNotifier extends StateNotifier<String?> {
  static const _key = 'desktop_camera_name';

  final SettingsService _settings;

  SelectedCameraNotifier(this._settings) : super(_settings.getString(_key));

  Future<void> select(String? name) async {
    await _settings.setString(_key, name ?? '');
    state = name == null || name.isEmpty ? null : name;
  }
}

final selectedCameraNameProvider = StateNotifierProvider<SelectedCameraNotifier, String?>(
  (ref) => SelectedCameraNotifier(ref.watch(settingsServiceProvider)),
);

/// Frames of a sample payload the size of a signature, for previewing the QR settings.
final sampleQrPartsProvider = Provider.family<List<String>, int>(
  (ref, bytesPerFrame) =>
      encodeUrForQr(data: List<int>.generate(900, (i) => (i * 7) % 256), maxFragmentLength: bytesPerFrame),
);
