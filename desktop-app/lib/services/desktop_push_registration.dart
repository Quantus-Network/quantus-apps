import 'package:wallet_core/services/push_registration.dart';

/// Windows and Linux have no push transport that reaches a closed app, so
/// there is no device or address to register: every call completes without
/// doing anything. A Mac registers through `MacPushRegistration`.
class DesktopPushRegistration implements PushRegistration {
  const DesktopPushRegistration();

  @override
  Future<void> registerDevice() async {}

  @override
  Future<void> registerAddress(String address) async {}

  @override
  Future<void> unregister() async {}
}
