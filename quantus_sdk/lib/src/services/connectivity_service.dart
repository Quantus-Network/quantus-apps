import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:quantus_sdk/src/utils/print.dart';

enum NetworkStatus { online, offline }

/// Whether any network path is up, as connectivity_plus reports it, with the
/// platform re-read on every resume and, while a stream has a listener and the
/// app is in the foreground, every [verifyInterval].
///
/// The change stream alone can end on a stale value. Android re-reads the
/// active network 500 ms after a loss, before a cellular network has finished
/// tearing down, and some OEM builds never report the loss at all. On iOS the
/// path monitor is cancelled whenever the stream has no listener (a hot
/// restart, for one) and the re-created monitor answers `none` until its first
/// update, which is dropped when it beats the handler. `checkConnectivity`
/// reads the live state, so re-reading it converges on the truth.
class ConnectivityService {
  static const Duration defaultVerifyInterval = Duration(seconds: 3);

  static final ConnectivityService instance = ConnectivityService();

  final Connectivity _connectivity;
  final Duration _verifyInterval;
  final _statusController = StreamController<NetworkStatus>.broadcast();
  final _resultsController = StreamController<List<ConnectivityResult>>.broadcast();
  late final StreamSubscription<List<ConnectivityResult>> _subscription;
  late final AppLifecycleListener _lifecycle;
  Timer? _verifyTimer;
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

  ConnectivityService({Connectivity? connectivity, Duration verifyInterval = defaultVerifyInterval})
    : _connectivity = connectivity ?? Connectivity(),
      _verifyInterval = verifyInterval {
    // Listening first keeps the platform monitor alive, so the check reads a
    // live path rather than one just created for it.
    _subscription = _connectivity.onConnectivityChanged.listen(_apply, onError: _onError);
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycleState);
    for (final controller in [_statusController, _resultsController]) {
      controller.onListen = _syncVerifyTimer;
      controller.onCancel = _syncVerifyTimer;
    }
    unawaited(_verify());
  }

  void _onLifecycleState(AppLifecycleState state) {
    _syncVerifyTimer();
    if (state == AppLifecycleState.resumed) unawaited(_verify());
  }

  void _syncVerifyTimer() {
    final state = WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
    final foreground = state == AppLifecycleState.resumed || state == AppLifecycleState.inactive;
    final run = foreground && (_statusController.hasListener || _resultsController.hasListener);
    if (run == (_verifyTimer != null)) return;
    _verifyTimer?.cancel();
    _verifyTimer = run ? Timer.periodic(_verifyInterval, (_) => unawaited(_verify())) : null;
  }

  Future<void> _verify() async => _apply(await _connectivity.checkConnectivity());

  void _onError(Object error) => quantusPrint('Connectivity error: $error');

  void _apply(List<ConnectivityResult> results) {
    final status = results.contains(ConnectivityResult.none) ? NetworkStatus.offline : NetworkStatus.online;
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
    _verifyTimer?.cancel();
    _lifecycle.dispose();
    _subscription.cancel();
    _statusController.close();
    _resultsController.close();
  }
}
