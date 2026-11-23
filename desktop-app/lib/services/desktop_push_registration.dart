import 'package:wallet_core/services/push_registration.dart';

/// The desktop app has no push transport, so there is no device or address to
/// register: every call completes without doing anything.
class DesktopPushRegistration implements PushRegistration {
  const DesktopPushRegistration();

  @override
  Future<void> registerDevice() async {}

  @override
  Future<void> registerAddress(String address) async {}

  @override
  Future<void> unregister() async {}
}
