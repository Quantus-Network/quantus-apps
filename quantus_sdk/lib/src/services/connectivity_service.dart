import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:quantus_sdk/src/utils/print.dart';

enum NetworkStatus { online, offline }

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  final StreamController<NetworkStatus> _statusController = StreamController<NetworkStatus>.broadcast();
  final StreamController<List<ConnectivityResult>> _resultsController =
      StreamController<List<ConnectivityResult>>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  NetworkStatus _currentStatus = NetworkStatus.online;
  List<ConnectivityResult> _currentResults = const [];
  bool _initialized = false;

  Stream<NetworkStatus> get statusStream => _statusController.stream;
  NetworkStatus get currentStatus => _currentStatus;

  /// Every interface the platform reports, so a caller can name which radio is
  /// still on. Empty until the first platform answer.
  Stream<List<ConnectivityResult>> get resultsStream => _resultsController.stream;
  List<ConnectivityResult> get currentResults => _currentResults;

  ConnectivityService() {
    _initialize();
  }

  Future<void> _initialize() async {
    if (_initialized) return;
    _initialized = true;

    final initialResult = await _connectivity.checkConnectivity();
    _updateStatus(initialResult, emitInitial: true);

    _subscription = _connectivity.onConnectivityChanged.listen(_onConnectivityChanged, onError: _onError);
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    quantusPrint('Connectivity changed: $results');
    _updateStatus(results);
  }

  void _onError(dynamic error) {
    quantusPrint('Connectivity error: $error');
  }

  void _updateStatus(List<ConnectivityResult> results, {bool emitInitial = false}) {
    _currentResults = results;
    _resultsController.add(results);
    final newStatus = results.contains(ConnectivityResult.none) ? NetworkStatus.offline : NetworkStatus.online;

    if (emitInitial || newStatus != _currentStatus) {
      _currentStatus = newStatus;
      _statusController.add(newStatus);
      quantusPrint('Network status: $newStatus');
    }
  }

  void dispose() {
    _subscription?.cancel();
    _statusController.close();
    _resultsController.close();
  }
}
