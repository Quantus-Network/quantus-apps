import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/remote_config_provider.dart';

final oneClickServiceProvider = Provider<OneClickService>(
  (ref) => OneClickService(apiKey: ref.watch(remoteConfigProvider.select((c) => c.nearPartnerJwt))),
);
