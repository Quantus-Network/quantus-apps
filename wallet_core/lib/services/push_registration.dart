import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wallet_core/utils/unbound_seam.dart';

/// Registers this device and its addresses with the push notification backend.
/// Each app binds its own implementation through `walletCoreOverrides`,
/// because the push transport differs per platform.
abstract interface class PushRegistration {
  /// Registers this device. Called once a wallet exists on it.
  Future<void> registerDevice();

  /// Registers [address] for push notifications on this device.
  Future<void> registerAddress(String address);

  /// Removes this device from the push backend, e.g. on wallet reset.
  Future<void> unregister();
}

final pushRegistrationProvider = Provider<PushRegistration>((ref) => throw unboundSeam('pushRegistrationProvider'));
