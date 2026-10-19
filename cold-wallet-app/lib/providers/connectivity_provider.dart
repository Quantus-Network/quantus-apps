import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  ref.onDispose(service.dispose);
  return service;
});

/// Emits the current network status, seeded immediately with the service's
/// current value. Defaults to [NetworkStatus.online] until proven offline, so
/// the app fails closed (blocked) rather than open.
final networkStatusProvider = StreamProvider<NetworkStatus>((ref) async* {
  final service = ref.watch(connectivityServiceProvider);
  yield service.currentStatus;
  yield* service.statusStream;
});

/// True while any network is reachable. Defaults to true (fail closed) until
/// the first status arrives.
final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(networkStatusProvider).maybeWhen(data: (s) => s == NetworkStatus.online, orElse: () => true);
});

/// Every interface the platform reports, so the offline gate can name which
/// radios are still on. Read here rather than through [ConnectivityService],
/// which reports only online or offline.
final connectivityResultsProvider = StreamProvider<List<ConnectivityResult>>((ref) async* {
  final connectivity = Connectivity();
  yield await connectivity.checkConnectivity();
  yield* connectivity.onConnectivityChanged;
});
