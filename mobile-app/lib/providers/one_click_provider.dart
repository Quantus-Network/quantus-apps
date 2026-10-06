import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/remote_config_provider.dart';

final oneClickServiceProvider = Provider<OneClickService>(
  (ref) => OneClickService(apiKey: ref.watch(remoteConfigProvider.select((c) => c.nearPartnerJwt))),
);

/// Whether [address] is a 1Click deposit address, once remote config has had
/// its say: false without a lookup when `enableOneClickNearWarning` is off.
/// The history route is invite-only, so a lookup that races the config fetch,
/// or follows a failed one, is refused: this waits for the refresh in flight
/// and, when the partner key is still missing, asks quersi once more.
Future<bool> isOneClickDepositAddress(WidgetRef ref, String address) async {
  final config = ref.read(remoteConfigProvider.notifier);
  await config.settled;
  if (!ref.read(remoteConfigProvider).enableOneClickNearWarning) return false;
  if (ref.read(remoteConfigProvider).nearPartnerJwt == null) await config.syncConfig();
  return ref.read(oneClickServiceProvider).isDepositAddress(address);
}
