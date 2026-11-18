import 'package:resonance_network_wallet/services/local_auth_service.dart';
import 'package:wallet_core/services/user_approval.dart';

/// The phone's own way to ask for approval, for wallet_core's [UserApproval]:
/// its biometrics or screen lock, through [LocalAuthService].
///
/// A phone with no screen lock has nothing to ask with and is approved
/// without being asked, as this app has always done; see
/// [LocalAuthService.authenticate].
class LocalAuthUserApproval implements UserApproval {
  const LocalAuthUserApproval(this._auth);

  final LocalAuthService _auth;

  @override
  Future<ApprovalAvailability> availability() async =>
      await _auth.isDeviceSecure() ? ApprovalAvailability.available : ApprovalAvailability.notSetUp;

  @override
  Future<ApprovalResult> approve({required String reason}) async =>
      await _auth.authenticate(localizedReason: reason) ? ApprovalResult.approved : ApprovalResult.declined;
}
