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
  /// lock exists, and on Android the Keystore can show the prompt (API 28+),
  /// which below API 30 is biometric-only and so needs an enrolled biometric.
  Future<bool> deviceCanProtect() async {
    try {
      if (!Platform.isIOS && !Platform.isAndroid) return false;
      if (!await _auth.isDeviceSupported()) return false;
      if (!Platform.isAndroid) return true;
      final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
      if (sdk < 28) return false;
      if (sdk < 30) return (await _auth.getAvailableBiometrics()).isNotEmpty;
      return true;
    } catch (e) {
      debugPrint('deviceCanProtect error: $e');
      return false;
    }
  }

  Future<bool> authenticate(String reason) async {
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
