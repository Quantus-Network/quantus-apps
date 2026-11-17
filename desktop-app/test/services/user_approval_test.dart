import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:quantus_desktop_wallet/providers/password_prompt_provider.dart';
import 'package:quantus_desktop_wallet/services/login_password.dart';
import 'package:quantus_desktop_wallet/services/pam/pam_session.dart';
import 'package:quantus_desktop_wallet/services/user_approval.dart';

import '../fakes.dart';

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

  group('PasswordApproval', () {
    late FakeLoginPassword loginPassword;
    late List<({String reason, LoginPasswordCheck check})> prompts;

    /// What the prompt answers; it may throw.
    late Future<bool> Function() promptAnswer;

    late PasswordApproval approval;

    setUp(() {
      loginPassword = FakeLoginPassword();
      prompts = [];
      promptAnswer = () async => true;
      approval = PasswordApproval(loginPassword, ({required reason, required check}) {
        prompts.add((reason: reason, check: check));
        return promptAnswer();
      });
    });

    test('is available where the login password check is set up, and not set up where it is not', () async {
      expect(await approval.availability(), ApprovalAvailability.available);

      loginPassword.isSetUpAnswer = false;

      expect(await approval.availability(), ApprovalAvailability.notSetUp);
    });

    test('a system that cannot check passwords at all is not hidden as "not set up"', () async {
      loginPassword.isSetUpError = ArgumentError('Failed to load dynamic library libpam.so.0');

      await expectLater(approval.availability(), throwsArgumentError);
    });

    test('prompts with the reason and the login password check, and is approved when the prompt is', () async {
      expect(await approval.approve(reason: 'Authenticate to see recovery phrase'), ApprovalResult.approved);

      expect(prompts.single.reason, 'Authenticate to see recovery phrase');
      await prompts.single.check('correct horse', onMessage: (_) {});
      expect(loginPassword.checked, ['correct horse']);
    });

    test('a cancelled prompt is declined', () async {
      promptAnswer = () async => false;

      expect(await approval.approve(reason: 'why'), ApprovalResult.declined);
    });

    test('a prompt that failed is not hidden', () async {
      promptAnswer = () async => throw const PamException(9, 'Authentication service cannot retrieve information');

      await expectLater(approval.approve(reason: 'why'), throwsA(isA<PamException>()));
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

    test(
      'asks for the login password on Linux, checked by the system and asked for in the app\'s own prompt',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.linux;
        final loginPassword = FakeLoginPassword();
        final container = ProviderContainer(overrides: [loginPasswordProvider.overrideWithValue(loginPassword)]);
        addTearDown(container.dispose);

        final approval = container.read(userApprovalProvider);
        expect(approval, isA<PasswordApproval>());

        final result = approval.approve(reason: 'Authenticate to see recovery phrase');
        final request = container.read(passwordPromptProvider)!;
        expect(request.reason, 'Authenticate to see recovery phrase');
        await request.check('correct horse', onMessage: (_) {});
        expect(loginPassword.checked, ['correct horse']);

        container.read(passwordPromptProvider.notifier).finish(approved: true);
        expect(await result, ApprovalResult.approved);
      },
    );
  });
}
