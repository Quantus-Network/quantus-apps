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

  static Duration _instanceRetryInterval = defaultRetryInterval;
  static ConnectivityService? _instance;

  /// One service per process, shared by the app's providers and the endpoint
  /// services. Created on first use with the configured retry interval.
  static ConnectivityService get instance => _instance ??= ConnectivityService(retryInterval: _instanceRetryInterval);

  /// How often [instance] re-reads the platform while offline. An app sets it
  /// once at startup, before anything reads [instance].
  static set instanceRetryInterval(Duration interval) {
    if (_instance != null) throw StateError('ConnectivityService.instance already created');
    _instanceRetryInterval = interval;
  }

  final Connectivity _connectivity;
  final Duration _retryInterval;
  final _statusController = StreamController<NetworkStatus>.broadcast();
  final _resultsController = StreamController<List<ConnectivityResult>>.broadcast();
  late final StreamSubscription<List<ConnectivityResult>> _subscription;
  Timer? _retry;
  int _generation = 0;
  List<ConnectivityResult> _results = const [];
  NetworkStatus _status = NetworkStatus.online;

  /// Online until the platform answers, so a caller that must fail closed
  /// treats an unknown state as connected.
  NetworkStatus get currentStatus => _status;

  /// Every transport the platform reports, so a caller can name what is up.
  List<ConnectivityResult> get currentResults => _results;

  /// The current status, then every change.
  Stream<NetworkStatus> get statusStream => _replay(() => _status, _statusController.stream);

  /// The current results, then every change.
  Stream<List<ConnectivityResult>> get resultsStream => _replay(() => _results, _resultsController.stream);

  /// Attaches to [changes] and reads the snapshot in one synchronous step, so
  /// no change can land between replay and subscription. Changes that arrive
  /// while the snapshot is being delivered wait in the buffer.
  static Stream<T> _replay<T>(T Function() snapshot, Stream<T> changes) async* {
    final buffer = StreamController<T>();
    final subscription = changes.listen(buffer.add, onError: buffer.addError, onDone: buffer.close);
    try {
      yield snapshot();
      yield* buffer.stream;
    } finally {
      // Not awaited: awaiting the cancel here deadlocks flutter_test's fake
      // async when a listener awaits a single event without pumping.
      unawaited(subscription.cancel());
    }
  }

  ConnectivityService({Connectivity? connectivity, Duration retryInterval = defaultRetryInterval})
    : _connectivity = connectivity ?? Connectivity(),
      _retryInterval = retryInterval {
    // Listening first keeps the platform monitor alive, so the check reads a
    // live path rather than one just created for it.
    _subscription = _connectivity.onConnectivityChanged.listen(_onChange, onError: _onError);
    unawaited(_check());
  }

  /// A stream event is newer than any check still in flight, so it moves the
  /// generation forward and the stale reply is dropped in [_check].
  void _onChange(List<ConnectivityResult> results) {
    _generation++;
    _apply(results);
  }

  Future<void> _check() async {
    final generation = _generation;
    final List<ConnectivityResult> results;
    try {
      results = await _connectivity.checkConnectivity();
    } catch (error) {
      quantusPrint('Connectivity check failed: $error');
      // Keep re-reading: a failed read must not end the offline retry loop.
      if (generation == _generation && _status == NetworkStatus.offline) {
        _retry?.cancel();
        _retry = Timer(_retryInterval, _check);
      }
      return;
    }
    if (generation == _generation) _apply(results);
  }

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
