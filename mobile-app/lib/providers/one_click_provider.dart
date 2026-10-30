import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/remote_config_provider.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';

final oneClickServiceProvider = Provider<OneClickService>((_) => OneClickService());

/// Whether 1Click confirmed [address] as one of its deposit addresses, once
/// remote config has had its say (a refresh in flight is waited for). Only a
/// yes blocks a send: no lookup when `enableOneClickNearWarning` is off, and a
/// lookup that fails for any reason is logged and counts as no, so a backend
/// that is down or refusing never holds up a send.
Future<bool> isOneClickDepositAddress(WidgetRef ref, String address) async {
  final config = ref.read(remoteConfigProvider.notifier);
  await config.settled;
  if (!ref.read(remoteConfigProvider).enableOneClickNearWarning) return false;
  try {
    return await ref.read(oneClickServiceProvider).isDepositAddress(address);
  } catch (e) {
    quantusPrint('1Click deposit lookup for $address failed, sending anyway: $e');
    return false;
  }
}
