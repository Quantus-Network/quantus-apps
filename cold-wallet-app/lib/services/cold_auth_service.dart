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
