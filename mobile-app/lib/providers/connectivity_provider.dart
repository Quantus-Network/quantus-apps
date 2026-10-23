import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

final connectivityServiceProvider = Provider<ConnectivityService>((ref) => ConnectivityService.instance);

final networkStatusProvider = StreamProvider<NetworkStatus>(
  (ref) => ref.watch(connectivityServiceProvider).statusStream,
);

final isOnlineProvider = Provider<bool>((ref) {
  final statusAsync = ref.watch(networkStatusProvider);
  return statusAsync.when(
    data: (status) => status == NetworkStatus.online,
    loading: () => true,
    error: (_, _) => false,
  );
});
