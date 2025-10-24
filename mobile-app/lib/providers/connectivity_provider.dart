import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  
  ref.onDispose(() => service.dispose());
  
  return service;
});

final networkStatusProvider = StreamProvider<NetworkStatus>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.statusStream;
});

final isOnlineProvider = Provider<bool>((ref) {
  final statusAsync = ref.watch(networkStatusProvider);
  return statusAsync.when(
    data: (status) => status == NetworkStatus.online,
    loading: () => true,
    error: (_, _) => false,
  );
});

