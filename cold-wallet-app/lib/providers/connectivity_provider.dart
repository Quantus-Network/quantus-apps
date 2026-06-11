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
