import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/remote_config_provider.dart';

final oneClickServiceProvider = Provider<OneClickService>((ref) {
  final (endpoint, apiKey) = ref.watch(remoteConfigProvider.select((c) => (c.oneClickEndpoint, c.nearPartnerJwt)));
  return OneClickService(endpoint: endpoint, apiKey: apiKey);
});

/// Whether [address] is a 1Click deposit address, once remote config has had
/// its say: false without a lookup when `enableOneClickNearWarning` is off;
/// a refresh in flight is waited for.
Future<bool> isOneClickDepositAddress(WidgetRef ref, String address) async {
  final config = ref.read(remoteConfigProvider.notifier);
  await config.settled;
  if (!ref.read(remoteConfigProvider).enableOneClickNearWarning) return false;
  return ref.read(oneClickServiceProvider).isDepositAddress(address);
}
