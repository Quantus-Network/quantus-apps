import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
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
  int cleanLastPausedTimeCalls = 0;

  @override
  Future<bool> getHasWallet() async => hasWallet;

  @override
  void cleanLastPausedTime() => cleanLastPausedTimeCalls++;
}

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
      expect(settingsService.cleanLastPausedTimeCalls, 0);
    });

    test('cleans last paused time only after a successful authentication', () async {
      localAuth.deviceSupported = true;

      expect(await service.authenticate(), isTrue);
      expect(settingsService.cleanLastPausedTimeCalls, 1);
    });

    test('fails closed without prompting when the device has no security at all', () async {
      localAuth.deviceSupported = false;

      expect(await service.authenticate(), isFalse);
      expect(localAuth.authenticateCalls, 0);
    });
  });
}
