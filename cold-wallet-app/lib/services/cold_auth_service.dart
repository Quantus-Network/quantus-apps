import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Thin wrapper over [LocalAuthentication] used for the biometric unlock gate
/// and for probing whether the device offers a hardware-backed secure element.
class ColdAuthService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// A device lock (biometric or device credential) is a prerequisite for the
  /// OS to provide hardware-backed key storage, so we treat this as a proxy for
  /// "has a usable secure element".
  Future<bool> isDeviceSecure() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (e) {
      debugPrint('isDeviceSecure error: $e');
      return false;
    }
  }

  Future<bool> canUseBiometrics() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      if (!await _auth.canCheckBiometrics) return false;
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (e) {
      debugPrint('canUseBiometrics error: $e');
      return false;
    }
  }

  /// Whether the OS can keep the signing key behind user presence: a device
  /// lock exists, and on Android the Keystore can show the prompt
  /// ([androidCanProtect]).
  Future<bool> deviceCanProtect() async {
    try {
      if (!Platform.isIOS && !Platform.isAndroid) return false;
      if (!await _auth.isDeviceSupported()) return false;
      if (!Platform.isAndroid) return true;
      final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
      return androidCanProtect(sdk, await _auth.getAvailableBiometrics());
    } catch (e) {
      debugPrint('deviceCanProtect error: $e');
      return false;
    }
  }

  /// The Keystore prompt exists from API 28. Below API 30 it is biometric-only
  /// and releases a key only to a strong (class 3) biometric, so one must be
  /// enrolled; a weak one cannot open the store at all. From API 30 the device
  /// credential stands in.
  @visibleForTesting
  static bool androidCanProtect(int sdk, List<BiometricType> enrolled) {
    if (sdk < 28) return false;
    if (sdk < 30) return enrolled.contains(BiometricType.strong);
    return true;
  }

  int _prompts = 0;

  /// True while the platform prompt is up. On Android it pauses the activity,
  /// which must not count as the user leaving the app.
  bool get promptInProgress => _prompts > 0;

  /// Android's protected store authenticates once per process and serves
  /// later reads silently, so a read there proves nothing on its own. iOS
  /// prompts on every read of a user-presence item.
  bool get storeAuthenticatesOncePerProcess => Platform.isAndroid;

  /// A fresh user-presence check in front of a protected read the store would
  /// otherwise answer silently. True without a prompt where the read prompts.
  Future<bool> gateProtectedRead(String reason) async =>
      storeAuthenticatesOncePerProcess ? await authenticate(reason) : true;

  Future<bool> authenticate(String reason) async {
    _prompts++;
    try {
      return await promptUser(reason);
    } finally {
      _prompts--;
    }
  }

  /// The platform prompt itself; a test stands in here.
  @protected
  Future<bool> promptUser(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        sensitiveTransaction: true,
        persistAcrossBackgrounding: true,
      );
    } on PlatformException catch (e) {
      debugPrint('authenticate platform error: $e');
      return false;
    } catch (e) {
      debugPrint('authenticate error: $e');
      return false;
    }
  }
}
