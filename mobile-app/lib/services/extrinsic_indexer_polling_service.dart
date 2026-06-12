import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/services/telemetry_service.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';

/// Configuration for polling the indexer until a submitted extrinsic appears.
class ExtrinsicIndexerPollingConfig<TPending, TContext> {
  const ExtrinsicIndexerPollingConfig({
    required this.logPrefix,
    required this.getId,
    required this.getExtrinsicHash,
    required this.isStillPending,
    required this.removePending,
    required this.showTimeoutToast,
    required this.confirmIfIndexed,
    this.tryResolveTimeout,
  });

  final String logPrefix;
  final String Function(TPending pending) getId;
  final String? Function(TPending pending) getExtrinsicHash;
  final bool Function(Ref ref, String id) isStillPending;
  final void Function(Ref ref, String id) removePending;
  final void Function(Ref ref) showTimeoutToast;
  final Future<bool> Function(Ref ref, TContext context, TPending pending) confirmIfIndexed;

  /// When polling times out, attempt to reconcile from chain state without a
  /// timeout toast. Return true when resolved.
  final Future<bool> Function(Ref ref, TContext context, TPending pending)? tryResolveTimeout;
}

/// Polls the indexer on an interval until [confirmIfIndexed] succeeds or times out.
class ExtrinsicIndexerPollingService<TPending, TContext> {
  ExtrinsicIndexerPollingService(this._ref, this._config);

  final Ref _ref;
  final ExtrinsicIndexerPollingConfig<TPending, TContext> _config;
  final Map<String, Timer> _timers = {};
  final Set<String> _inFlight = {};
  static const _searchInterval = Duration(seconds: 5);
  static const _timeout = Duration(minutes: 5);

  void startPolling(TContext context, TPending pending) {
    final key = _config.getId(pending);
    if (_config.getExtrinsicHash(pending) == null) {
      quantusDebugPrint(
        '${_config.logPrefix} ERROR: cannot poll $key — no extrinsicHash. '
        'Waiting for submission to complete.',
      );
      return;
    }

    quantusDebugPrint('${_config.logPrefix} startPolling $key hash=${_config.getExtrinsicHash(pending)}');

    stopPolling(key);
    final startTime = DateTime.now();

    final timer = Timer.periodic(_searchInterval, (_) {
      if (DateTime.now().difference(startTime) > _timeout) {
        quantusDebugPrint('${_config.logPrefix} timeout for $key');
        stopPolling(key);
        unawaited(_handleTimeout(context, pending));
        return;
      }
      unawaited(_search(context, pending));
    });

    _timers[key] = timer;
    unawaited(_search(context, pending));
  }

  void stopPolling(String id) {
    _timers.remove(id)?.cancel();
  }

  Future<void> _search(TContext context, TPending pending) async {
    final key = _config.getId(pending);
    if (_config.getExtrinsicHash(pending) == null) return;
    if (!_inFlight.add(key)) return;

    try {
      final confirmed = await _config.confirmIfIndexed(_ref, context, pending);
      if (confirmed) {
        stopPolling(key);
        return;
      }
      quantusDebugPrint('${_config.logPrefix} not indexed yet: $key');
    } catch (e) {
      quantusDebugPrint('${_config.logPrefix} search error for $key: $e');
    } finally {
      _inFlight.remove(key);
    }
  }

  Future<void> _handleTimeout(TContext context, TPending pending) async {
    final key = _config.getId(pending);
    try {
      quantusDebugPrint('${_config.logPrefix} final indexer check before timeout for $key');
      final confirmed = await _config.confirmIfIndexed(_ref, context, pending);
      if (confirmed) return;
    } catch (e) {
      quantusDebugPrint('${_config.logPrefix} final check error for $key: $e');
    }

    if (!_config.isStillPending(_ref, key)) return;

    final tryResolveTimeout = _config.tryResolveTimeout;
    if (tryResolveTimeout != null) {
      try {
        final resolved = await tryResolveTimeout(_ref, context, pending);
        if (resolved) {
          quantusDebugPrint('${_config.logPrefix} timeout resolved on-chain for $key');
          return;
        }
      } catch (e) {
        quantusDebugPrint('${_config.logPrefix} timeout resolve error for $key: $e');
      }
    }

    if (!_config.isStillPending(_ref, key)) return;

    quantusDebugPrint('${_config.logPrefix} giving up on $key');
    TelemetryService().sendError(
      'extrinsic_indexer_polling_timeout',
      error: '${_config.logPrefix} gave up on $key',
      stackTrace: StackTrace.current,
    );
    _config.removePending(_ref, key);
    _config.showTimeoutToast(_ref);
  }

  /// Cancels all active polling timers (e.g. on logout).
  void stopAll() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }

  void dispose() => stopAll();
}
