import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';

class LocalAuthService {
  static final LocalAuthService _instance = LocalAuthService._internal();
  factory LocalAuthService() => _instance;

  final LocalAuthentication _localAuth;
  final SettingsService _settingsService;
  final Duration _authTimeout;

  /// In-memory only: the background grace window must never survive
  /// process death. A null value with an existing wallet therefore means
  /// "this process has not recorded a backgrounding" — i.e. locked.
  DateTime? _lastPausedTime;

  /// True while a system auth dialog is on screen. The dialog pushes the app
  /// into inactive/paused, which AppLifecycleManager would otherwise treat as
  /// a real backgrounding and, on resume, re-trigger auth — a double prompt.
  /// Every caller authenticates through this singleton, so the flag covers the
  /// flows that call [authenticate] directly (send, multisig, settings) as well
  /// as [LocalAuthController].
  bool _isAuthenticating = false;
  bool get isAuthenticating => _isAuthenticating;

  LocalAuthService._internal()
    : _localAuth = LocalAuthentication(),
      _settingsService = SettingsService(),
      _authTimeout = const Duration(seconds: 10);

  @visibleForTesting
  LocalAuthService.withDependencies({
    required LocalAuthentication localAuth,
    required SettingsService settingsService,
    Duration authTimeout = const Duration(seconds: 10),
  }) : _localAuth = localAuth,
       _settingsService = settingsService,
       _authTimeout = authTimeout;

  /// Whether the device has any lock-screen security enrolled: biometrics
  /// or a device credential (PIN/pattern/password).
  Future<bool> isDeviceSecure() async {
    try {
      return await _localAuth.isDeviceSupported();
    } catch (e) {
      quantusPrint('Error checking device security: $e');
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
      quantusPrint('Error checking biometric availability: $e');
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      quantusPrint('Error getting available biometrics: $e');
      return [];
    }
  }

  Future<bool> authenticate({String localizedReason = 'Please authenticate to access your wallet'}) async {
    try {
      if (!await _settingsService.getHasWallet()) return true;

      // Require whatever device security is enrolled: biometrics or the
      // device credential (PIN/pattern/password). biometricOnly: false lets
      // the plugin fall back to the device credential, so PIN-only devices
      // are prompted for their PIN. A device with no lock-screen security at
      // all has nothing to enforce: skip the prompt and grant access —
      // failing closed here would just dead-end the app on the lock screen.
      if (!await isDeviceSecure()) return true;

      _isAuthenticating = true;
      final bool didAuthenticate;
      try {
        didAuthenticate = await _localAuth.authenticate(
          localizedReason: localizedReason,
          biometricOnly: false,
          persistAcrossBackgrounding: true,
          sensitiveTransaction: true,
        );
      } finally {
        _isAuthenticating = false;
      }

      if (didAuthenticate) cleanLastPausedTime();
      return didAuthenticate;
    } on PlatformException catch (e) {
      quantusPrint('Platform exception during authentication: $e');
      return false;
    } catch (e) {
      quantusPrint('Error during authentication: $e');
      return false;
    }
  }

  Future<bool> shouldRequireAuthentication() async {
    try {
      if (!await _settingsService.getHasWallet()) return false;
      // No device lock enrolled → there is nothing to gate with, so don't
      // require auth (otherwise every resume would flash a lock screen that
      // can only auto-dismiss).
      if (!await isDeviceSecure()) return false;
      // Fail closed: a wallet with no in-memory pause record means the
      // process started (or was killed) since the last unlock.
      final lastPausedTime = _lastPausedTime;
      if (lastPausedTime == null) return true;
      return DateTime.now().difference(lastPausedTime) > _authTimeout;
    } catch (e) {
      quantusPrint('Error checking if authentication is required: $e');
      return true;
    }
  }

  Future<bool> updateLastPausedTime() async {
    if (!await _settingsService.getHasWallet()) return false;
    _lastPausedTime = DateTime.now();
    return true;
  }

  void cleanLastPausedTime() {
    _lastPausedTime = null;
  }

  Future<void> stopAuthentication() async {
    try {
      await _localAuth.stopAuthentication();
    } catch (e) {
      quantusPrint('Error stopping authentication: $e');
    }
  }
}
