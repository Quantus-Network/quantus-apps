import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wallet_core/utils/unbound_seam.dart';

/// Whether this device can confirm that its owner is at it.
enum ApprovalAvailability {
  available,

  /// The system could, but nothing is set up to prove it with: no screen lock
  /// on a phone, no login password on a Mac, no Windows Hello on Windows, and
  /// on Linux no PAM service for the app to check the login password through.
  notSetUp,
}

/// How a request for approval ended.
enum ApprovalResult { approved, declined, notSetUp }

/// Asks the person at the device to prove they own it before the app does
/// something that hands the wallet over or moves its funds, such as showing
/// the recovery phrase or sending.
///
/// Each app binds its own implementation through `walletCoreOverrides`,
/// because the way to ask differs by platform. So does the answer where
/// nothing is set up to ask with, which is each app's own rule: the desktop
/// app answers [ApprovalResult.notSetUp] and the action stays unavailable,
/// while the mobile app answers [ApprovalResult.approved], as it always has
/// on a phone with no screen lock.
abstract interface class UserApproval {
  Future<ApprovalAvailability> availability();

  /// Asks for approval, telling the person [reason].
  Future<ApprovalResult> approve({required String reason});
}

final userApprovalProvider = Provider<UserApproval>((ref) => throw unboundSeam('userApprovalProvider'));
