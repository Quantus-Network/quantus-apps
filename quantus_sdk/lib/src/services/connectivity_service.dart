import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:quantus_sdk/src/utils/print.dart';

enum NetworkStatus { online, offline }

/// Whether any network path is up, as connectivity_plus reports it.
///
/// An online answer is trusted until the change stream says otherwise. An
/// offline answer is re-read with `checkConnectivity` every [retryInterval]
/// until the platform answers online, because the stream can end on a stale
/// `none`: iOS cancels its path monitor whenever the stream has no listener
/// (a hot restart, for one) and the re-created monitor answers `none` until
/// its first update, which is dropped when it beats the handler.
class ConnectivityService {
  static const Duration defaultRetryInterval = Duration(seconds: 3);

  static final ConnectivityService instance = ConnectivityService();

  final Connectivity _connectivity;
  final Duration _retryInterval;
  final _statusController = StreamController<NetworkStatus>.broadcast();
  final _resultsController = StreamController<List<ConnectivityResult>>.broadcast();
  late final StreamSubscription<List<ConnectivityResult>> _subscription;
  Timer? _retry;
  List<ConnectivityResult> _results = const [];
  NetworkStatus _status = NetworkStatus.online;

  /// Online until the platform answers, so a caller that must fail closed
  /// treats an unknown state as connected.
  NetworkStatus get currentStatus => _status;

  /// Every transport the platform reports, so a caller can name what is up.
  List<ConnectivityResult> get currentResults => _results;

  /// The current status, then every change.
  Stream<NetworkStatus> get statusStream async* {
    yield _status;
    yield* _statusController.stream;
  }

  /// The current results, then every change.
  Stream<List<ConnectivityResult>> get resultsStream async* {
    yield _results;
    yield* _resultsController.stream;
  }

  ConnectivityService({Connectivity? connectivity, Duration retryInterval = defaultRetryInterval})
    : _connectivity = connectivity ?? Connectivity(),
      _retryInterval = retryInterval {
    // Listening first keeps the platform monitor alive, so the check reads a
    // live path rather than one just created for it.
    _subscription = _connectivity.onConnectivityChanged.listen(_apply, onError: _onError);
    unawaited(_check());
  }

  Future<void> _check() async => _apply(await _connectivity.checkConnectivity());

  void _onError(Object error) => quantusPrint('Connectivity error: $error');

  void _apply(List<ConnectivityResult> results) {
    final status = results.contains(ConnectivityResult.none) ? NetworkStatus.offline : NetworkStatus.online;
    _retry?.cancel();
    _retry = status == NetworkStatus.offline ? Timer(_retryInterval, _check) : null;
    if (!listEquals(results, _results)) {
      _results = results;
      _resultsController.add(results);
      quantusPrint('Connectivity: $results');
    }
    if (status == _status) return;
    _status = status;
    _statusController.add(status);
    quantusPrint('Network status: $status');
  }

  void dispose() {
    _retry?.cancel();
    _subscription.cancel();
    _statusController.close();
    _resultsController.close();
  }
}
