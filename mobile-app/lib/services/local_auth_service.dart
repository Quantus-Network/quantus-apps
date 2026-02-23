import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class LocalAuthService {
  static final LocalAuthService _instance = LocalAuthService._internal();
  factory LocalAuthService() => _instance;
  LocalAuthService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();
  final SettingsService _settingsService = SettingsService();

  static const _authTimeout = Duration(seconds: 30);

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
      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) return true;

      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true, sensitiveTransaction: true),
      );

      if (didAuthenticate) _cleanLastPausedTime();
      return didAuthenticate;
    } on PlatformException catch (e) {
      debugPrint('Platform exception during authentication: $e');
      return false;
    } catch (e) {
      debugPrint('Error during authentication: $e');
      return false;
    }
  }

  bool shouldRequireAuthentication() {
    try {
      final lastPausedTime = _settingsService.getLastPausedTime();
      if (lastPausedTime == null) return false;
      return DateTime.now().difference(lastPausedTime) > _authTimeout;
    } catch (e) {
      debugPrint('Error checking if authentication is required: $e');
      return true;
    }
  }

  void updateLastPausedTime() {
    _settingsService.setLastPausedTime(DateTime.now());
  }

  void _cleanLastPausedTime() {
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
