import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

/// Whether this computer can confirm that its owner is at it.
enum ApprovalAvailability {
  available,

  /// The system could, but its owner has set nothing up to prove it with: no
  /// login password on a Mac, no Windows Hello on Windows.
  notSetUp,

  /// The app has no way to ask on this system yet (Linux).
  unsupported,
}

/// How a request for approval ended.
enum ApprovalResult { approved, declined, notSetUp }

/// Asks the person at the computer to prove they own it before the app does
/// something that hands the wallet over, such as showing its recovery phrase.
///
/// Nothing is let through unasked: a system with no way to ask says so, and
/// the action stays unavailable.
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

/// The approval of a system the app cannot ask yet. Linux gets its own once
/// the app can check the login password there.
class UnsupportedApproval implements UserApproval {
  const UnsupportedApproval();

  @override
  Future<ApprovalAvailability> availability() async => ApprovalAvailability.unsupported;

  @override
  Future<ApprovalResult> approve({required String reason}) async =>
      throw StateError('There is no way to ask for approval on this system.');
}

final userApprovalProvider = Provider<UserApproval>(
  (ref) => switch (defaultTargetPlatform) {
    TargetPlatform.macOS || TargetPlatform.windows => LocalAuthApproval(LocalAuthentication()),
    TargetPlatform.linux => const UnsupportedApproval(),
    final platform => throw UnsupportedError('The desktop app does not run on ${platform.name}.'),
  },
);
