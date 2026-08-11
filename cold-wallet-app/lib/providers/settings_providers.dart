import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class ColdSettings {
  static const minQrFps = 5;
  static const maxQrFps = 50;
  static const defaultQrFps = 15;
  static const minQrBytes = 300;

  // 1400 payload bytes encode to ~2870 UR chars, under the 2953-char capacity
  // of a version-40 byte-mode QR at error correction L; encodeUrForQr measures
  // the final strings and shrinks fragments if they would still overflow.
  static const maxQrBytes = 1400;
  static const defaultQrBytes = 1100;

  final bool wifiOverrideEnabled;
  final int qrFps;
  final int qrBytes;

  const ColdSettings({this.wifiOverrideEnabled = false, this.qrFps = defaultQrFps, this.qrBytes = defaultQrBytes});

  ColdSettings copyWith({bool? wifiOverrideEnabled, int? qrFps, int? qrBytes}) => ColdSettings(
    wifiOverrideEnabled: wifiOverrideEnabled ?? this.wifiOverrideEnabled,
    qrFps: qrFps ?? this.qrFps,
    qrBytes: qrBytes ?? this.qrBytes,
  );
}

class ColdSettingsController extends Notifier<ColdSettings> {
  static const _wifiOverrideKey = 'wifi_lock_override';
  static const _qrFpsKey = 'qr_fps';
  static const _qrBytesKey = 'qr_bytes_per_frame';

  @override
  ColdSettings build() {
    _load();
    return const ColdSettings();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = ColdSettings(
      wifiOverrideEnabled: prefs.getBool(_wifiOverrideKey) ?? false,
      qrFps: (prefs.getInt(_qrFpsKey) ?? ColdSettings.defaultQrFps).clamp(ColdSettings.minQrFps, ColdSettings.maxQrFps),
      qrBytes: (prefs.getInt(_qrBytesKey) ?? ColdSettings.defaultQrBytes).clamp(
        ColdSettings.minQrBytes,
        ColdSettings.maxQrBytes,
      ),
    );
  }

  Future<void> setWifiOverrideEnabled(bool enabled) async {
    state = state.copyWith(wifiOverrideEnabled: enabled);
    if (!enabled) ref.read(wifiLockOverriddenProvider.notifier).set(false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_wifiOverrideKey, enabled);
  }

  Future<void> setQrFps(int fps) async {
    state = state.copyWith(qrFps: fps);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_qrFpsKey, fps);
  }

  Future<void> setQrBytes(int bytes) async {
    state = state.copyWith(qrBytes: bytes);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_qrBytesKey, bytes);
  }
}

final coldSettingsProvider = NotifierProvider<ColdSettingsController, ColdSettings>(ColdSettingsController.new);

/// Session-only: armed from the connectivity guard after the user confirms the
/// override warning; disarmed when the persistent toggle is switched off.
class WifiLockOverridden extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final wifiLockOverriddenProvider = NotifierProvider<WifiLockOverridden, bool>(WifiLockOverridden.new);
