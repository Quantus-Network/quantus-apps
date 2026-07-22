import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/local_auth_provider.dart';
import 'package:resonance_network_wallet/services/local_auth_service.dart';

class FakeLocalAuthentication extends Fake implements LocalAuthentication {
  bool deviceSupported = true;
  bool authenticateResult = true;
  int authenticateCalls = 0;

  @override
  Future<bool> isDeviceSupported() async => deviceSupported;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<dynamic> authMessages = const <dynamic>[],
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) async {
    authenticateCalls++;
    return authenticateResult;
  }
}

class FakeSettingsService extends Fake implements SettingsService {
  bool hasWallet = true;

  @override
  Future<bool> getHasWallet() async => hasWallet;
}

/// Lets fire-and-forget async work (e.g. the unawaited authenticate() call
/// inside checkAuthentication) complete before asserting.
Future<void> flushAsync() => Future<void>.delayed(const Duration(milliseconds: 5));

void main() {
  late FakeLocalAuthentication localAuth;
  late FakeSettingsService settingsService;
  late LocalAuthService service;

  setUp(() {
    localAuth = FakeLocalAuthentication();
    settingsService = FakeSettingsService();
    service = LocalAuthService.withDependencies(localAuth: localAuth, settingsService: settingsService);
  });

  group('authenticate', () {
    test('returns true without prompting when no wallet exists', () async {
      settingsService.hasWallet = false;

      expect(await service.authenticate(), isTrue);
      expect(localAuth.authenticateCalls, 0);
    });

    test('prompts for device security when enrolled (biometrics or PIN-only device)', () async {
      localAuth.deviceSupported = true;

      expect(await service.authenticate(), isTrue);
      expect(localAuth.authenticateCalls, 1);
    });

    test('returns false when the user fails the device prompt', () async {
      localAuth
        ..deviceSupported = true
        ..authenticateResult = false;

      expect(await service.authenticate(), isFalse);
    });

    test('fails closed without prompting when the device has no security at all', () async {
      localAuth.deviceSupported = false;

      expect(await service.authenticate(), isFalse);
      expect(localAuth.authenticateCalls, 0);
    });

    test('successful authentication clears the pause record (next check requires auth)', () async {
      await service.updateLastPausedTime();
      expect(await service.shouldRequireAuthentication(), isFalse);

      expect(await service.authenticate(), isTrue);
      expect(await service.shouldRequireAuthentication(), isTrue);
    });

    test('failed authentication keeps the pause record', () async {
      localAuth.authenticateResult = false;

      await service.updateLastPausedTime();
      expect(await service.authenticate(), isFalse);
      expect(await service.shouldRequireAuthentication(), isFalse);
    });
  });

  group('shouldRequireAuthentication', () {
    test('returns false when no wallet exists', () async {
      settingsService.hasWallet = false;

      expect(await service.shouldRequireAuthentication(), isFalse);
    });

    test('fails closed with no pause record (cold start / after process death)', () async {
      expect(await service.shouldRequireAuthentication(), isTrue);
    });

    test('returns false within the grace window after backgrounding', () async {
      await service.updateLastPausedTime();

      expect(await service.shouldRequireAuthentication(), isFalse);
    });

    test('returns true once the grace window has expired', () async {
      final shortTimeoutService = LocalAuthService.withDependencies(
        localAuth: localAuth,
        settingsService: settingsService,
        authTimeout: const Duration(milliseconds: 20),
      );

      await shortTimeoutService.updateLastPausedTime();
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(await shortTimeoutService.shouldRequireAuthentication(), isTrue);
    });

    test('updateLastPausedTime records nothing when no wallet exists', () async {
      settingsService.hasWallet = false;

      expect(await service.updateLastPausedTime(), isFalse);
      expect(await service.shouldRequireAuthentication(), isFalse);
    });
  });

  group('LocalAuthController', () {
    test('starts locked by default', () {
      final controller = LocalAuthController(service);

      expect(controller.state.isAuthenticated, isFalse);
      expect(controller.state.isAuthenticating, isFalse);
    });

    test('unlocks via prompt at cold start when a wallet exists', () async {
      final controller = LocalAuthController(service);

      await controller.checkAuthentication();
      await flushAsync();

      expect(localAuth.authenticateCalls, 1);
      expect(controller.state.isAuthenticated, isTrue);
    });

    test('stays locked when the cold-start prompt is cancelled', () async {
      localAuth.authenticateResult = false;
      final controller = LocalAuthController(service);

      await controller.checkAuthentication();
      await flushAsync();

      expect(controller.state.isAuthenticated, isFalse);
    });

    test('locked session is NOT silently unlocked by the grace window', () async {
      // Locked at cold start, user backgrounds from the lock screen and
      // resumes within the grace window: must prompt, not unlock.
      await service.updateLastPausedTime();
      localAuth.authenticateResult = false;
      final controller = LocalAuthController(service);

      await controller.checkAuthentication();
      await flushAsync();

      expect(localAuth.authenticateCalls, 1);
      expect(controller.state.isAuthenticated, isFalse);
    });

    test('unlocked session within the grace window stays unlocked without re-prompting', () async {
      final controller = LocalAuthController(service);
      await controller.authenticate();
      expect(localAuth.authenticateCalls, 1);

      await service.updateLastPausedTime();
      await controller.checkAuthentication();

      expect(localAuth.authenticateCalls, 1);
      expect(controller.state.isAuthenticated, isTrue);
    });

    test('unlocked session past the grace window re-locks and prompts', () async {
      final shortTimeoutService = LocalAuthService.withDependencies(
        localAuth: localAuth,
        settingsService: settingsService,
        authTimeout: const Duration(milliseconds: 20),
      );
      final controller = LocalAuthController(shortTimeoutService);
      await controller.authenticate();

      await shortTimeoutService.updateLastPausedTime();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await controller.checkAuthentication();
      await flushAsync();

      expect(localAuth.authenticateCalls, 2);
      expect(controller.state.isAuthenticated, isTrue);
    });
  });
}
