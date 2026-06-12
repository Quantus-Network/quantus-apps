import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/pending_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/utils/polling_refresh_scope.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:resonance_network_wallet/shared/utils/tx_filter_family_provider.dart';

class PendingTransactionPollingService {
  final Ref _ref;
  final Map<String, Timer> _timers = {};
  static const _searchInterval = Duration(seconds: 5);
  static const _timeout = Duration(minutes: 5);

  PendingTransactionPollingService(this._ref);

  /// Polls the indexer until [pendingTx] is found on-chain. Uses
  /// [PendingTransactionEvent.extrinsicHash] when available for an exact,
  /// globally-unique match; otherwise falls back to (from, to, amount,
  /// blockNumber) matching. Fails early if neither is usable.
  void startPolling(PendingTransactionEvent pendingTx, {void Function(TransactionEvent result)? onFound}) {
    if (pendingTx.extrinsicHash == null && pendingTx.blockNumber == 0) {
      quantusDebugPrint(
        '[PendingTxPoller] ERROR: cannot poll ${pendingTx.id} — no extrinsicHash and blockNumber is 0. '
        'This would search all historical blocks and risk false positives.',
      );
      return;
    }

    quantusDebugPrint(
      '[PendingTxPoller] startPolling id=${pendingTx.id} '
      'hash=${pendingTx.extrinsicHash} block=${pendingTx.blockNumber} '
      'reversible=${pendingTx.isReversible} from=${pendingTx.from} '
      'to=${pendingTx.to} amount=${pendingTx.amount}',
    );

    stopPolling(pendingTx.id);
    final startTime = DateTime.now();

    final timer = Timer.periodic(_searchInterval, (_) {
      if (DateTime.now().difference(startTime) > _timeout) {
        quantusDebugPrint('[PendingTxPoller] Timeout for ${pendingTx.id}, deferring to reconciliation');
        stopPolling(pendingTx.id);
        _ref.read(pendingTransactionsProvider.notifier).remove(pendingTx.id);
        return;
      }
      _search(pendingTx, onFound: onFound);
    });

    _timers[pendingTx.id] = timer;
    _search(pendingTx, onFound: onFound);
  }

  void stopPolling(String id) {
    _timers.remove(id)?.cancel();
  }

  Future<void> _search(PendingTransactionEvent pendingTx, {void Function(TransactionEvent result)? onFound}) async {
    try {
      final historyService = _ref.read(chainHistoryServiceProvider);
      final hash = pendingTx.extrinsicHash;
      final TransactionEvent? result;
      if (hash != null) {
        quantusDebugPrint('[PendingTxPoller] searching by extrinsic hash $hash for ${pendingTx.id}');
        result = await historyService.searchByExtrinsicHash(extrinsicHash: hash, isReversible: pendingTx.isReversible);
      } else {
        quantusDebugPrint(
          '[PendingTxPoller] searching fallback (from, to, amount, block>${pendingTx.blockNumber}) '
          'for ${pendingTx.id}',
        );
        result = await historyService.searchForPendingTransaction(
          from: pendingTx.from,
          to: pendingTx.to,
          amount: pendingTx.amount,
          isReversible: pendingTx.isReversible,
          blockHeightAfter: pendingTx.blockNumber,
        );
      }

      if (result != null) {
        quantusDebugPrint('[PendingTxPoller] Found matching tx for ${pendingTx.id} at block ${result.blockNumber}');
        stopPolling(pendingTx.id);

        triggerSilentHistoryRefresh(_ref, affectedAccountIds: {pendingTx.from, pendingTx.to}, newTransaction: result);

        _ref
            .read(pendingTransactionsProvider.notifier)
            .updateState(pendingTx.id, TransactionState.inHistory, blockHash: result.blockHash);

        onFound?.call(result);

        _ref.read(pendingTransactionsProvider.notifier).remove(pendingTx.id);
        invalidateAccountBalances(_ref, {pendingTx.from, pendingTx.to});
      } else {
        quantusDebugPrint('[PendingTxPoller] no match yet for ${pendingTx.id}, will retry');
      }
    } catch (e) {
      quantusDebugPrint('[PendingTxPoller] Search error for ${pendingTx.id}: $e');
    }
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

final pendingTransactionPollingServiceProvider = Provider<PendingTransactionPollingService>((ref) {
  final service = PendingTransactionPollingService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});

void triggerSilentHistoryRefresh(Ref ref, {required Set<String> affectedAccountIds, TransactionEvent? newTransaction}) {
  try {
    final targets = accountRefreshTargets(affectedAccountIds: affectedAccountIds, activeId: activeAccountId(ref));

    for (final targetIds in targets) {
      if (newTransaction != null) {
        updatePaginationFiltersFor(ref.read, targetIds, (notifier, filter) {
          if (filter != TransactionFilter.receive) {
            notifier.addTransactionToHistory(newTransaction);
          }
        });
      }

      updatePaginationFiltersFor(ref.read, targetIds, (notifier, _) {
        notifier.silentRefresh();
      });
    }
  } catch (e) {
    quantusDebugPrint('[SilentHistoryRefresh] Error: $e');
  }
}
