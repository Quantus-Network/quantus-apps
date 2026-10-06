import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/remote_config_provider.dart';

final oneClickServiceProvider = Provider<OneClickService>(
  (ref) => OneClickService(apiKey: ref.watch(remoteConfigProvider.select((c) => c.nearPartnerJwt))),
);

/// The 1Click client once the partner key has had its chance to arrive. The
/// history route is invite-only, so a lookup that races the remote-config
/// fetch, or follows a failed one, is refused: this waits for the refresh in
/// flight and, when the key is still missing, asks quersi once more.
Future<OneClickService> partnerOneClickService(WidgetRef ref) async {
  final config = ref.read(remoteConfigProvider.notifier);
  await config.settled;
  if (ref.read(remoteConfigProvider).nearPartnerJwt == null) await config.syncConfig();
  return ref.read(oneClickServiceProvider);
}
