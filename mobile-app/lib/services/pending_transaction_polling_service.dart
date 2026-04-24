import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/account_id_list_cache.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/all_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/filtered_all_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/pending_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';

class PendingTransactionPollingService {
  final Ref _ref;
  final Map<String, Timer> _timers = {};
  static const _searchInterval = Duration(seconds: 5);
  static const _timeout = Duration(minutes: 5);

  PendingTransactionPollingService(this._ref);

  void startPolling(
    PendingTransactionEvent pendingTx, {
    bool isReversible = false,
    int blockHeightAfter = 0,
    int limit = 10,
    void Function(TransactionEvent result)? onFound,
  }) {
    stopPolling(pendingTx.id);
    final startTime = DateTime.now();

    final timer = Timer.periodic(_searchInterval, (_) {
      if (DateTime.now().difference(startTime) > _timeout) {
        print('[PendingTxPoller] Timeout for ${pendingTx.id}, deferring to reconciliation');
        stopPolling(pendingTx.id);
        _ref.read(pendingTransactionsProvider.notifier).remove(pendingTx.id);
        return;
      }
      _search(pendingTx, isReversible: isReversible, blockHeightAfter: blockHeightAfter, limit: limit, onFound: onFound);
    });

    _timers[pendingTx.id] = timer;
    _search(pendingTx, isReversible: isReversible, blockHeightAfter: blockHeightAfter, limit: limit, onFound: onFound);
  }

  void stopPolling(String id) {
    _timers.remove(id)?.cancel();
  }

  Future<void> _search(
    PendingTransactionEvent pendingTx, {
    required bool isReversible,
    required int blockHeightAfter,
    required int limit,
    void Function(TransactionEvent result)? onFound,
  }) async {
    try {
      final historyService = _ref.read(chainHistoryServiceProvider);
      final result = await historyService.searchForPendingTransaction(
        from: pendingTx.from,
        to: pendingTx.to,
        amount: pendingTx.amount,
        isReversible: isReversible,
        blockHeightAfter: blockHeightAfter,
        limit: limit,
      );

      if (result != null) {
        print('[PendingTxPoller] Found matching tx for ${pendingTx.id}');
        stopPolling(pendingTx.id);

        triggerSilentHistoryRefresh(
          _ref,
          affectedAccountIds: {pendingTx.from, pendingTx.to},
          newTransaction: result,
        );

        _ref
            .read(pendingTransactionsProvider.notifier)
            .updateState(pendingTx.id, TransactionState.inHistory, blockHash: result.blockHash);

        onFound?.call(result);

        _ref.read(pendingTransactionsProvider.notifier).remove(pendingTx.id);
        _ref.invalidate(balanceProviderFamily);
      }
    } catch (e) {
      print('[PendingTxPoller] Search error for ${pendingTx.id}: $e');
    }
  }

  void dispose() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }
}

final pendingTransactionPollingServiceProvider = Provider<PendingTransactionPollingService>((ref) {
  final service = PendingTransactionPollingService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});

void triggerSilentHistoryRefresh(
  Ref ref, {
  required Set<String> affectedAccountIds,
  TransactionEvent? newTransaction,
}) {
  try {
    final mainController = ref.read(paginationControllerProvider.notifier);
    if (newTransaction != null) mainController.addTransactionToHistory(newTransaction);
    mainController.silentRefresh();

    final targets = <String>{...affectedAccountIds};
    final active = ref.read(activeAccountProvider).value;
    if (active != null) targets.add(active.account.accountId);

    for (final accountId in targets) {
      final controller = ref.read(
        filteredPaginationControllerProviderFamily(AccountIdListCache.get([accountId])).notifier,
      );
      if (newTransaction != null) controller.addTransactionToHistory(newTransaction);
      controller.silentRefresh();
    }

    final accountIds = ref.read(accountsProvider).value?.map((a) => a.accountId).toList() ?? [];
    final allController = ref.read(
      filteredPaginationControllerProviderFamily(AccountIdListCache.get(accountIds)).notifier,
    );
    if (newTransaction != null) allController.addTransactionToHistory(newTransaction);
    allController.silentRefresh();
  } catch (e) {
    print('[SilentHistoryRefresh] Error: $e');
  }
}
