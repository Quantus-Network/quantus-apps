import 'dart:async';
import 'dart:io';

import 'package:polkadart/polkadart.dart';
import 'package:quantus_sdk/src/constants/app_constants.dart';
import 'package:quantus_sdk/src/services/connection_status.dart';

class ProviderManager {
  static final ProviderManager _instance = ProviderManager._internal();
  factory ProviderManager() => _instance;
  ProviderManager._internal();

  static const Duration _idleTtl = Duration(seconds: 90);
  static const Duration _heartbeatInterval = Duration(seconds: 12);
  static const Duration _heartbeatTimeout = Duration(seconds: 4);
  static const String _rpcEndpoint = AppConstants.rpcEndpoint;

  Provider? _provider;
  DateTime? _lastSuccessfulUseAt;
  Timer? _heartbeatTimer;
  Timer? _idleTimer;
  bool _unhealthy = false;
  Future<void>? _ongoingConnect;

  final _statusController = StreamController<ConnectionStatus>.broadcast();
  Stream<ConnectionStatus> get connectionStatus => _statusController.stream;

  Future<void> ensureConnected() async {
    await _ensureConnected();
  }

  Future<T> withProvider<T>(
    Future<T> Function(Provider provider) action, {
    Duration? operationTimeout,
  }) async {
    print('withProvider called');
    await _ensureConnected();
    try {
      final provider = _provider!;
      final op = action(provider);
      final result = operationTimeout == null
          ? await op
          : await op.timeout(operationTimeout);
      _markSuccessfulUse();
      return result;
    } on TimeoutException {
      _markUnhealthy();
      await _reconnectWithBackoff();
      final provider = _provider!;
      final retried = action(provider);
      final result = operationTimeout == null
          ? await retried
          : await retried.timeout(operationTimeout);
      _markSuccessfulUse();
      return result;
    } on SocketException {
      _markUnhealthy();
      await _reconnectWithBackoff();
      final provider = _provider!;
      final result = await (operationTimeout == null
          ? action(provider)
          : action(provider).timeout(operationTimeout));
      _markSuccessfulUse();
      return result;
    } catch (e) {
      print('withProvider error: $e');
      rethrow;
    }
  }

  Future<void> _ensureConnected() async {
    if (_provider != null && !_unhealthy) {
      _startTimers();
      return;
    }
    if (_ongoingConnect != null) {
      await _ongoingConnect;
      return;
    }
    final c = _connect();
    _ongoingConnect = c;
    try {
      await c;
    } finally {
      _ongoingConnect = null;
    }
  }

  Future<void> _connect() async {
    _statusController.add(ConnectionStatus.connecting);
    try {
      final uri = Uri.parse(_rpcEndpoint);
      Provider newProvider;
      if (uri.scheme == 'ws' || uri.scheme == 'wss') {
        newProvider = WsProvider(uri, autoConnect: false);
      } else {
        newProvider = Provider.fromUri(uri);
      }
      _provider = newProvider;
      await _provider!.connect().timeout(const Duration(seconds: 15));
      _unhealthy = false;
      _markSuccessfulUse();
      _startTimers();
      _statusController.add(ConnectionStatus.connected);
    } catch (e) {
      _statusController.add(ConnectionStatus.error);
      rethrow;
    }
  }

  void _markSuccessfulUse() {
    _lastSuccessfulUseAt = DateTime.now();
    _unhealthy = false;
  }

  void _markUnhealthy() {
    _unhealthy = true;
    _statusController.add(ConnectionStatus.disconnected);
  }

  void _startTimers() {
    _heartbeatTimer ??= Timer.periodic(_heartbeatInterval, (_) async {
      await _heartbeat();
    });
    _idleTimer ??= Timer.periodic(const Duration(seconds: 15), (_) {
      _checkIdle();
    });
  }

  Future<void> _heartbeat() async {
    if (_provider == null) return;
    try {
      await _provider!.send('chain_getHeader', []).timeout(_heartbeatTimeout);
    } catch (e) {
      print('heartbeat faiure: $e');
      _markUnhealthy();
    }
  }

  void _checkIdle() {
    if (_provider == null) return;
    final last = _lastSuccessfulUseAt;
    if (last == null) return;
    if (DateTime.now().difference(last) >= _idleTtl) {
      _disposeProvider();
      _statusController.add(ConnectionStatus.disconnected);
    }
  }

  Future<void> _reconnectWithBackoff() async {
    if (_ongoingConnect != null) {
      await _ongoingConnect;
      return;
    }
    Duration backoff = const Duration(milliseconds: 500);
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        await _connect();
        return;
      } catch (e) {
        print('reconnectWithBackoff failure: $e');
        await Future.delayed(backoff);
        backoff = Duration(milliseconds: backoff.inMilliseconds * 2);
      }
    }
    await _connect();
  }

  Future<void> reconnect() async {
    _disposeProvider();
    await _connect();
  }

  Future<void> reset() async {
    await reconnect();
  }

  void _disposeProvider() {
    _provider = null;
    _unhealthy = true;
  }

  Provider? get provider => _provider;

  void dispose() {
    _heartbeatTimer?.cancel();
    _idleTimer?.cancel();
    _statusController.close();
    _provider = null;
  }
}
