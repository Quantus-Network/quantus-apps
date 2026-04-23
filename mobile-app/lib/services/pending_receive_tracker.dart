import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/account_id_list_cache.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/all_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/filtered_all_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/pending_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';

class PendingReceiveTracker {
  final Ref _ref;
  final Map<String, Timer> _searchTimers = {};
  static const _searchInterval = Duration(seconds: 5);
  static const _timeout = Duration(minutes: 5);

  PendingReceiveTracker(this._ref);

  void trackIncomingTransfer({
    required String from,
    required String to,
    required BigInt amount,
    String? extrinsicHash,
  }) {
    final pendingTx = PendingTransactionEvent(
      tempId: 'pending_recv_${DateTime.now().millisecondsSinceEpoch}',
      from: from,
      to: to,
      amount: amount,
      timestamp: DateTime.now(),
      transactionState: TransactionState.pending,
      isReversible: false,
      fee: null,
      extrinsicHash: extrinsicHash,
    );

    _ref.read(pendingTransactionsProvider.notifier).add(pendingTx);
    _startSearching(pendingTx);
  }

  void _startSearching(PendingTransactionEvent pendingTx) {
    _stopSearching(pendingTx.id);

    final startTime = DateTime.now();

    final timer = Timer.periodic(_searchInterval, (_) {
      if (DateTime.now().difference(startTime) > _timeout) {
        print('[PendingReceiveTracker] Timeout for ${pendingTx.id}, deferring to reconciliation');
        _stopSearching(pendingTx.id);
        _ref.read(pendingTransactionsProvider.notifier).remove(pendingTx.id);
        return;
      }
      _search(pendingTx);
    });

    _searchTimers[pendingTx.id] = timer;
    _search(pendingTx);
  }

  void _stopSearching(String id) {
    _searchTimers.remove(id)?.cancel();
  }

  Future<void> _search(PendingTransactionEvent pendingTx) async {
    try {
      final historyService = _ref.read(chainHistoryServiceProvider);
      final result = await historyService.searchForPendingTransaction(
        from: pendingTx.from,
        to: pendingTx.to,
        amount: pendingTx.amount,
        isReversible: false,
        blockHeightAfter: 0,
      );

      if (result != null) {
        print('[PendingReceiveTracker] Found matching tx for ${pendingTx.id}');
        _stopSearching(pendingTx.id);

        _triggerSilentHistoryRefresh(affectedAccountIds: {pendingTx.from, pendingTx.to}, newTransaction: result);

        _ref
            .read(pendingTransactionsProvider.notifier)
            .updateState(pendingTx.id, TransactionState.inHistory, blockHash: result.blockHash);

        _ref.read(pendingTransactionsProvider.notifier).remove(pendingTx.id);
        _ref.invalidate(balanceProviderFamily);
      }
    } catch (e) {
      print('[PendingReceiveTracker] Search error for ${pendingTx.id}: $e');
    }
  }

  void _triggerSilentHistoryRefresh({required Set<String> affectedAccountIds, TransactionEvent? newTransaction}) {
    try {
      final mainController = _ref.read(paginationControllerProvider.notifier);
      if (newTransaction != null) mainController.addTransactionToHistory(newTransaction);
      mainController.silentRefresh();

      final targets = <String>{...affectedAccountIds};
      final active = _ref.read(activeAccountProvider).value;
      if (active != null) targets.add(active.account.accountId);

      for (final accountId in targets) {
        final controller = _ref.read(
          filteredPaginationControllerProviderFamily(AccountIdListCache.get([accountId])).notifier,
        );
        if (newTransaction != null) controller.addTransactionToHistory(newTransaction);
        controller.silentRefresh();
      }

      final accountIds = _ref.read(accountsProvider).value?.map((a) => a.accountId).toList() ?? [];
      final allController = _ref.read(
        filteredPaginationControllerProviderFamily(AccountIdListCache.get(accountIds)).notifier,
      );
      if (newTransaction != null) allController.addTransactionToHistory(newTransaction);
      allController.silentRefresh();
    } catch (e) {
      print('[PendingReceiveTracker] Silent refresh error: $e');
    }
  }

  void dispose() {
    for (final timer in _searchTimers.values) {
      timer.cancel();
    }
    _searchTimers.clear();
  }
}

final pendingReceiveTrackerProvider = Provider<PendingReceiveTracker>((ref) {
  final tracker = PendingReceiveTracker(ref);
  ref.onDispose(() => tracker.dispose());
  return tracker;
});
