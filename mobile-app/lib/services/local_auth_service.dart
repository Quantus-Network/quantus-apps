import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class LocalAuthService {
  static final LocalAuthService _instance = LocalAuthService._internal();
  factory LocalAuthService() => _instance;

  final LocalAuthentication _localAuth;
  final SettingsService _settingsService;

  LocalAuthService._internal() : _localAuth = LocalAuthentication(), _settingsService = SettingsService();

  @visibleForTesting
  LocalAuthService.withDependencies({required LocalAuthentication localAuth, required SettingsService settingsService})
    : _localAuth = localAuth,
      _settingsService = settingsService;

  static const _authTimeout = Duration(seconds: 10);

  /// Whether the device has any lock-screen security enrolled: biometrics
  /// or a device credential (PIN/pattern/password).
  Future<bool> isDeviceSecure() async {
    try {
      return await _localAuth.isDeviceSupported();
    } catch (e) {
      debugPrint('Error checking device security: $e');
      return false;
    }
  }

  Future<bool> isBiometricAvailable() async {
    try {
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      if (!isDeviceSupported) return false;

      final canCheck = await _localAuth.canCheckBiometrics;
      if (!canCheck) return false;

      final available = await getAvailableBiometrics();
      return available.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking biometric availability: $e');
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('Error getting available biometrics: $e');
      return [];
    }
  }

  Future<bool> authenticate({String localizedReason = 'Please authenticate to access your wallet'}) async {
    try {
      if (!await _settingsService.getHasWallet()) return true;

      // Require whatever device security is enrolled: biometrics or the
      // device credential (PIN/pattern/password). biometricOnly: false lets
      // the plugin fall back to the device credential, so PIN-only devices
      // are prompted for their PIN. A device with no security at all fails
      // closed: gated actions stay blocked until the device is secured.
      if (!await isDeviceSecure()) return false;

      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
        sensitiveTransaction: true,
      );

      if (didAuthenticate) cleanLastPausedTime();
      return didAuthenticate;
    } on PlatformException catch (e) {
      debugPrint('Platform exception during authentication: $e');
      return false;
    } catch (e) {
      debugPrint('Error during authentication: $e');
      return false;
    }
  }

  Future<bool> shouldRequireAuthentication() async {
    try {
      if (!await _settingsService.getHasWallet()) return false;
      final lastPausedTime = _settingsService.getLastPausedTime();
      if (lastPausedTime == null) return false;
      return DateTime.now().difference(lastPausedTime) > _authTimeout;
    } catch (e) {
      debugPrint('Error checking if authentication is required: $e');
      return true;
    }
  }

  Future<bool> updateLastPausedTime() async {
    if (!await _settingsService.getHasWallet()) return false;
    _settingsService.setLastPausedTime(DateTime.now());
    return true;
  }

  void cleanLastPausedTime() {
    _settingsService.cleanLastPausedTime();
  }

  Future<void> stopAuthentication() async {
    try {
      await _localAuth.stopAuthentication();
    } catch (e) {
      debugPrint('Error stopping authentication: $e');
    }
  }
}
