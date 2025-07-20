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

  /// Check if biometric authentication is available on the device
  Future<bool> isBiometricAvailable() async {
    try {
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();
      debugPrint('Device supported: $isDeviceSupported');

      if (!isDeviceSupported) return false;

      final bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
      debugPrint('Can check biometrics: $canCheckBiometrics');

      if (!canCheckBiometrics) return false;

      // Additional check for enrolled biometrics
      final List<BiometricType> availableBiometrics =
          await getAvailableBiometrics();
      debugPrint('Available biometric types: $availableBiometrics');

      return availableBiometrics.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking biometric availability: $e');
      return false;
    }
  }

  /// Get list of available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('Error getting available biometrics: $e');
      return [];
    }
  }

  /// Check if local authentication is enabled in app settings
  bool isLocalAuthEnabled() {
    return _settingsService.isAuthEnabled();
  }

  /// Enable or disable local authentication in app settings
  void setLocalAuthEnabled(bool enabled) {
    _settingsService.setAuthEnabled(enabled);
  }

  /// Authenticate using biometrics
  Future<bool> authenticate({
    String localizedReason = 'Please authenticate to access your wallet',
    bool biometricOnly = false,
    bool forSetup = false, // Add this parameter for setup flows
  }) async {
    try {
      // Check if biometrics are available
      final bool isAvailable = await isBiometricAvailable();
      if (!isAvailable) {
        debugPrint('Biometric authentication is not available');
        return false;
      }

      if (!forSetup) {
        final bool isEnabled = isLocalAuthEnabled();
        if (!isEnabled) {
          debugPrint('Local authentication is disabled in settings');
          return true; // Allow access if not enabled
        }
      }

      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: localizedReason,
        options: AuthenticationOptions(
          biometricOnly: biometricOnly,
          stickyAuth: true,
          sensitiveTransaction: true,
        ),
      );

      if (didAuthenticate) {
        // Update last successful auth time
        _settingsService.setLastSuccessfulAuthTime(DateTime.now());
      }

      return didAuthenticate;
    } on PlatformException catch (e) {
      debugPrint('Platform exception during authentication: $e');

      // Handle specific error cases
      switch (e.code) {
        case 'NotAvailable':
        case 'NotEnrolled':
          return false;
        case 'LockedOut':
        case 'PermanentlyLockedOut':
          return false;
        case 'UserCancel':
        case 'SystemCancel':
          return false;
        default:
          return false;
      }
    } catch (e) {
      debugPrint('Error during authentication: $e');
      return false;
    }
  }

  /// Get a user-friendly description of available biometric types
  Future<String> getBiometricDescription() async {
    try {
      final List<BiometricType> availableBiometrics =
          await getAvailableBiometrics();

      if (availableBiometrics.isEmpty) {
        return 'No biometric authentication available';
      }

      final List<String> descriptions = [];

      for (final biometric in availableBiometrics) {
        switch (biometric) {
          case BiometricType.face:
            descriptions.add('Face ID');
            break;
          case BiometricType.fingerprint:
            descriptions.add('Fingerprint');
            break;
          case BiometricType.iris:
            descriptions.add('Iris');
            break;
          case BiometricType.weak:
            descriptions.add('Device PIN/Pattern');
            break;
          case BiometricType.strong:
            descriptions.add('Strong Biometrics');
            break;
        }
      }

      if (descriptions.length == 1) {
        return descriptions.first;
      } else if (descriptions.length == 2) {
        return '${descriptions[0]} or ${descriptions[1]}';
      } else {
        // ignore: lines_longer_than_80_chars
        return '${descriptions.take(descriptions.length - 1).join(', ')}, or ${descriptions.last}';
      }
    } catch (e) {
      debugPrint('Error getting biometric description: $e');
      return 'Biometric Authentication';
    }
  }

  /// Check if authentication is required (based on app lifecycle and settings)
  Future<bool> shouldRequireAuthentication() async {
    try {
      final bool isEnabled = isLocalAuthEnabled();
      if (!isEnabled) return false;

      final DateTime? lastAuthTime = _settingsService
          .getLastSuccessfulAuthTime();
      if (lastAuthTime == null) return true;

      // Require authentication if more than 1 minute has passed
      // You can adjust this duration based on your security requirements
      const Duration authTimeout = Duration(minutes: 1);

      print(
        // ignore: lines_longer_than_80_chars
        'auth time difference: ${DateTime.now().difference(lastAuthTime).inSeconds}',
      );

      return DateTime.now().difference(lastAuthTime) > authTimeout;
    } catch (e) {
      debugPrint('Error checking if authentication is required: $e');
      return true; // Err on the side of caution
    }
  }

  /// Stop local authentication (useful for cleanup)
  Future<void> stopAuthentication() async {
    try {
      await _localAuth.stopAuthentication();
    } catch (e) {
      debugPrint('Error stopping authentication: $e');
    }
  }
}
