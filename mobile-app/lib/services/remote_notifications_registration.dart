import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/remote_config_provider.dart';
import 'package:wallet_core/services/push_registration.dart';
import 'package:wallet_core/services/telemetry.dart';
import 'package:wallet_core/utils/provider_reader.dart';

/// Registers this device (or one new address) for push notifications, and
/// never throws: registration must not fail the account flow that calls it.
///
/// When [insertAddress] is non-null, the address is registered for push
/// notifications on the existing device; otherwise the device itself is
/// registered for the first time.
Future<void> registerForRemoteNotificationsBestEffort(ProviderReader read, {String? insertAddress}) async {
  try {
    if (!read(remoteConfigProvider).enableRemoteNotifications) return;
    final pushRegistration = read(pushRegistrationProvider);
    if (insertAddress != null) {
      await pushRegistration.registerAddress(insertAddress);
    } else {
      await pushRegistration.registerDevice();
    }
  } catch (e) {
    quantusPrint('Failed to register for remote notifications: $e');
    read(telemetryProvider).sendError('registerForRemoteNotifications', error: e);
  }
}
