import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:quantus_desktop_wallet/services/user_approval.dart';

/// The system's authentication, answering as a test says.
class _FakeLocalAuthentication extends Fake implements LocalAuthentication {
  bool deviceSupported = true;

  /// What a request answers: a result, or an error to throw.
  Future<bool> Function() answer = () async => true;

  final requests = <({String reason, bool biometricOnly, bool sensitiveTransaction})>[];

  @override
  Future<bool> isDeviceSupported() async => deviceSupported;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    // Wider than the plugin's own type, which the plugin does not export.
    Iterable<Object> authMessages = const [],
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) {
    requests.add((reason: localizedReason, biometricOnly: biometricOnly, sensitiveTransaction: sensitiveTransaction));
    return answer();
  }
}

void main() {
  group('LocalAuthApproval', () {
    late _FakeLocalAuthentication auth;
    late LocalAuthApproval approval;

    setUp(() {
      auth = _FakeLocalAuthentication();
      approval = LocalAuthApproval(auth);
    });

    test('is available when the device can authenticate its owner, and not set up when it cannot', () async {
      expect(await approval.availability(), ApprovalAvailability.available);

      auth.deviceSupported = false;

      expect(await approval.availability(), ApprovalAvailability.notSetUp);
    });

    test('asks with the reason, accepting the password as well as biometrics, as a sensitive request', () async {
      expect(await approval.approve(reason: 'Authenticate to see recovery phrase'), ApprovalResult.approved);

      expect(auth.requests.single, (
        reason: 'Authenticate to see recovery phrase',
        biometricOnly: false,
        sensitiveTransaction: true,
      ));
    });

    test('a refused request is declined', () async {
      auth.answer = () async => false;

      expect(await approval.approve(reason: 'why'), ApprovalResult.declined);
    });

    for (final code in [
      LocalAuthExceptionCode.userCanceled,
      LocalAuthExceptionCode.timeout,
      LocalAuthExceptionCode.systemCanceled,
    ]) {
      test('a request ended by ${code.name} is declined', () async {
        auth.answer = () async => throw LocalAuthException(code: code);

        expect(await approval.approve(reason: 'why'), ApprovalResult.declined);
      });
    }

    test('a device with no credentials set is not set up', () async {
      auth.answer = () async => throw const LocalAuthException(code: LocalAuthExceptionCode.noCredentialsSet);

      expect(await approval.approve(reason: 'why'), ApprovalResult.notSetUp);
    });

    test('any other failure is not hidden', () async {
      auth.answer = () async => throw const LocalAuthException(code: LocalAuthExceptionCode.uiUnavailable);

      await expectLater(
        approval.approve(reason: 'why'),
        throwsA(isA<LocalAuthException>().having((e) => e.code, 'code', LocalAuthExceptionCode.uiUnavailable)),
      );
    });
  });

  group('UnsupportedApproval', () {
    test('reports itself unsupported, and refuses to be asked', () async {
      const approval = UnsupportedApproval();

      expect(await approval.availability(), ApprovalAvailability.unsupported);
      await expectLater(approval.approve(reason: 'why'), throwsStateError);
    });
  });

  group('userApprovalProvider', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    for (final platform in [TargetPlatform.macOS, TargetPlatform.windows]) {
      test('uses the system authentication on ${platform.name}', () {
        debugDefaultTargetPlatformOverride = platform;
        final container = ProviderContainer();
        addTearDown(container.dispose);

        expect(container.read(userApprovalProvider), isA<LocalAuthApproval>());
      });
    }

    test('has no approval on Linux yet', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(userApprovalProvider), isA<UnsupportedApproval>());
    });
  });
}
