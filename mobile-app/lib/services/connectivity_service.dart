import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum NetworkStatus { online, offline }

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  final StreamController<NetworkStatus> _statusController =
      StreamController<NetworkStatus>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  NetworkStatus _currentStatus = NetworkStatus.online;
  bool _initialized = false;

  Stream<NetworkStatus> get statusStream => _statusController.stream;
  NetworkStatus get currentStatus => _currentStatus;

  ConnectivityService() {
    _initialize();
  }

  Future<void> _initialize() async {
    if (_initialized) return;
    _initialized = true;
    
    final initialResult = await _connectivity.checkConnectivity();
    _updateStatus(initialResult, emitInitial: true);
    
    _subscription = _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
      onError: _onError,
    );
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    print('Connectivity changed: $results');
    _updateStatus(results);
  }

  void _onError(dynamic error) {
    print('Connectivity error: $error');
  }

  void _updateStatus(List<ConnectivityResult> results, {bool emitInitial = false}) {
    final newStatus = results.contains(ConnectivityResult.none)
        ? NetworkStatus.offline
        : NetworkStatus.online;

    if (emitInitial || newStatus != _currentStatus) {
      _currentStatus = newStatus;
      _statusController.add(newStatus);
      print('Network status: $newStatus');
    }
  }

  void dispose() {
    _subscription?.cancel();
    _statusController.close();
  }
}

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

