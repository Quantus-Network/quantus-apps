import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:quantus_desktop_wallet/providers/password_prompt_provider.dart';
import 'package:quantus_desktop_wallet/services/login_password.dart';

/// Whether this computer can confirm that its owner is at it.
enum ApprovalAvailability {
  available,

  /// The system could, but nothing is set up to prove it with: no login
  /// password on a Mac, no Windows Hello on Windows, and on Linux no PAM
  /// service for the app to check the login password through.
  notSetUp,
}

/// How a request for approval ended.
enum ApprovalResult { approved, declined, notSetUp }

/// Asks the person at the computer to prove they own it before the app does
/// something that hands the wallet over, such as showing its recovery phrase.
///
/// Nothing is let through unasked: a system that cannot ask says so, and the
/// action stays unavailable.
abstract interface class UserApproval {
  Future<ApprovalAvailability> availability();

  /// Asks for approval, telling the person [reason].
  Future<ApprovalResult> approve({required String reason});
}

/// Approval through the system's own prompt: Touch ID or the login password
/// on macOS, Windows Hello on Windows.
class LocalAuthApproval implements UserApproval {
  const LocalAuthApproval(this._auth);

  final LocalAuthentication _auth;

  @override
  Future<ApprovalAvailability> availability() async =>
      await _auth.isDeviceSupported() ? ApprovalAvailability.available : ApprovalAvailability.notSetUp;

  @override
  Future<ApprovalResult> approve({required String reason}) async {
    try {
      final approved = await _auth.authenticate(
        localizedReason: reason,
        // The password is as good a proof as a fingerprint.
        biometricOnly: false,
        sensitiveTransaction: true,
      );
      return approved ? ApprovalResult.approved : ApprovalResult.declined;
    } on LocalAuthException catch (e) {
      switch (e.code) {
        case LocalAuthExceptionCode.userCanceled ||
            LocalAuthExceptionCode.timeout ||
            LocalAuthExceptionCode.systemCanceled:
          return ApprovalResult.declined;
        case LocalAuthExceptionCode.noCredentialsSet:
          return ApprovalResult.notSetUp;
        default:
          rethrow;
      }
    }
  }
}

/// Shows the app's own prompt for the login password, telling the person
/// [reason], and answers whether a password they typed passed [check]: false
/// if they gave up.
typedef PasswordPrompt = Future<bool> Function({required String reason, required LoginPasswordCheck check});

/// Approval through the login password, asked for in the app's own prompt
/// and checked by the system: Linux, which has no prompt of its own to ask
/// with.
class PasswordApproval implements UserApproval {
  const PasswordApproval(this._loginPassword, this._prompt);

  final LoginPassword _loginPassword;
  final PasswordPrompt _prompt;

  @override
  Future<ApprovalAvailability> availability() async =>
      await _loginPassword.isSetUp() ? ApprovalAvailability.available : ApprovalAvailability.notSetUp;

  @override
  Future<ApprovalResult> approve({required String reason}) async =>
      await _prompt(reason: reason, check: _loginPassword.check) ? ApprovalResult.approved : ApprovalResult.declined;
}

final userApprovalProvider = Provider<UserApproval>(
  (ref) => switch (defaultTargetPlatform) {
    TargetPlatform.macOS || TargetPlatform.windows => LocalAuthApproval(LocalAuthentication()),
    TargetPlatform.linux => PasswordApproval(
      ref.watch(loginPasswordProvider),
      ref.watch(passwordPromptProvider.notifier).ask,
    ),
    final platform => throw UnsupportedError('The desktop app does not run on ${platform.name}.'),
  },
);
