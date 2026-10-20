import 'dart:async';

import 'package:quantus_sdk/src/models/pending_transfer_event.dart';
import 'package:quantus_sdk/src/models/transaction_event.dart';
import 'package:quantus_sdk/src/services/chain_history_service.dart';
import 'package:quantus_sdk/src/utils/print.dart';

/// Polls the indexer until a submitted transaction shows up in history.
class PendingTransactionTracker {
  final ChainHistoryService _history;
  final Duration interval;
  final Duration timeout;
  final Map<String, Timer> _timers = {};
  final Map<String, Completer<TransactionEvent?>> _completers = {};

  PendingTransactionTracker({
    ChainHistoryService? history,
    this.interval = const Duration(seconds: 5),
    this.timeout = const Duration(minutes: 5),
  }) : _history = history ?? ChainHistoryService();

  /// Resolves with the indexed event, or null once [timeout] passes. Matches by
  /// extrinsic hash when the event carries one, otherwise by (from, to, amount)
  /// after its block. A tracked id that is tracked again or [cancel]led never
  /// resolves its earlier future.
  Future<TransactionEvent?> track(PendingTransactionEvent pendingTx) {
    if (pendingTx.extrinsicHash == null && pendingTx.blockNumber == 0) {
      throw ArgumentError('Cannot track ${pendingTx.id}: no extrinsic hash and no block number');
    }
    cancel(pendingTx.id);
    final completer = Completer<TransactionEvent?>();
    _completers[pendingTx.id] = completer;
    var elapsed = Duration.zero;

    Future<void> search() async {
      try {
        final result = await _search(pendingTx);
        if (result != null && _completers[pendingTx.id] == completer) _finish(pendingTx.id, result);
      } catch (e) {
        quantusPrint('[PendingTxTracker] search error for ${pendingTx.id}: $e');
      }
    }

    _timers[pendingTx.id] = Timer.periodic(interval, (_) {
      elapsed += interval;
      if (elapsed >= timeout) {
        quantusPrint('[PendingTxTracker] timeout for ${pendingTx.id}');
        _finish(pendingTx.id, null);
        return;
      }
      unawaited(search());
    });
    unawaited(search());
    return completer.future;
  }

  Future<TransactionEvent?> _search(PendingTransactionEvent pendingTx) {
    final hash = pendingTx.extrinsicHash;
    if (hash != null) return _history.searchByExtrinsicHash(extrinsicHash: hash, isReversible: pendingTx.isReversible);
    return _history.searchForPendingTransaction(
      from: pendingTx.from,
      to: pendingTx.to,
      amount: pendingTx.amount,
      isReversible: pendingTx.isReversible,
      blockHeightAfter: pendingTx.blockNumber,
    );
  }

  void _finish(String id, TransactionEvent? result) {
    _timers.remove(id)?.cancel();
    _completers.remove(id)?.complete(result);
  }

  void cancel(String id) {
    _timers.remove(id)?.cancel();
    _completers.remove(id);
  }

  void dispose() {
    for (final id in _timers.keys.toList()) {
      cancel(id);
    }
  }
}
