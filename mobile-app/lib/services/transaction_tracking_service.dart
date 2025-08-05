import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/all_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/pending_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';

/// Service that tracks individual transactions after they enter 'inBlock' state
/// It polls the blockchain until the transaction appears in history, then
/// updates the transaction state and removes it from pending transactions.
class TransactionTrackingService {
  final Ref _ref;
  final Map<String, Timer> _activeTrackers = {};
  static const Duration _pollInterval = Duration(seconds: 10);

  TransactionTrackingService(this._ref) {
    _listenToPendingTransactions();
  }

  void _listenToPendingTransactions() {
    _ref.listen(pendingTransactionsProvider, (previous, current) {
      _handlePendingTransactionsChange(previous ?? [], current);
    });
  }

  void _handlePendingTransactionsChange(
    List<PendingTransactionEvent> previous,
    List<PendingTransactionEvent> current,
  ) {
    // Find transactions that just entered inBlock state
    final nowInBlock = current.where(
      (tx) =>
          tx.transactionState == TransactionState.inBlock &&
          !_activeTrackers.containsKey(tx.id),
    );

    // Start tracking newly inBlock transactions
    for (final tx in nowInBlock) {
      _startTrackingTransaction(tx);
    }

    final trackersToRemove = <String>[];

    for (final id in _activeTrackers.keys) {
      final tx = current.where((t) => t.id == id).firstOrNull;
      if (tx == null || tx.transactionState != TransactionState.inBlock) {
        trackersToRemove.add(id);
      }
    }

    for (final id in trackersToRemove) {
      _stopTrackingTransaction(id);
    }
  }

  void _startTrackingTransaction(PendingTransactionEvent tx) {
    print('Starting to track transaction: ${tx.id} (${tx.blockHash})');

    // Create a timer that polls for this specific transaction
    final timer = Timer.periodic(_pollInterval, (_) {
      _checkTransactionInHistory(tx);
    });

    _activeTrackers[tx.id] = timer;

    // Also check immediately
    _checkTransactionInHistory(tx);
  }

  void _stopTrackingTransaction(String transactionId) {
    final timer = _activeTrackers.remove(transactionId);
    timer?.cancel();
    print('Stopped tracking transaction: $transactionId');
  }

  Future<void> _checkTransactionInHistory(
    PendingTransactionEvent pendingTx,
  ) async {
    try {
      final historyService = _ref.read(chainHistoryServiceProvider);
      final blockHash = pendingTx.blockHash;
      if (blockHash == null) {
        print(
          'Error: blockHash is null for pending transaction ${pendingTx.id}',
        );
        return;
      }

      // Query for the block and transaction in one go
      final response = await historyService.getTransactionsInBlock(
        blockHash: blockHash,
        from: pendingTx.from,
        to: pendingTx.to,
        isReversible: pendingTx.isReversible,
      );

      // If block is not yet indexed, just wait for the next poll cycle.
      if (!response.blockExists) {
        print('Block $blockHash not indexed yet, waiting for next poll.');
        return;
      }

      // If the block is indexed, but our transaction is not in it,
      // mark as failed.
      if (response.transactions.isEmpty) {
        print(
          // ignore: lines_longer_than_80_chars
          'Transaction ${pendingTx.id} not found in block $blockHash. Marking as failed.',
        );
        _ref
            .read(pendingTransactionsProvider.notifier)
            .updateState(
              pendingTx.id,
              TransactionState.failed,
              blockHash: pendingTx.blockHash,
            );
        Timer(const Duration(seconds: 2), () {
          _ref.read(pendingTransactionsProvider.notifier).remove(pendingTx.id);
        });
        _stopTrackingTransaction(pendingTx.id);
        return;
      }

      final foundInHistory = _findMatchingTransaction(
        pendingTx,
        response.transactions,
      );

      if (foundInHistory != null) {
        print('Transaction found in history: ${pendingTx.id}');

        // Update the pending transaction to inHistory state
        _ref
            .read(pendingTransactionsProvider.notifier)
            .updateState(
              pendingTx.id,
              TransactionState.inHistory,
              blockHash: pendingTx.blockHash,
            );

        // Remove the transaction from pending after a short delay
        // This allows the UI to show the "inHistory" state briefly
        Timer(const Duration(seconds: 2), () {
          _ref.read(pendingTransactionsProvider.notifier).remove(pendingTx.id);
        });

        // Stop tracking this transaction
        _stopTrackingTransaction(pendingTx.id);

        // Refresh balance since transaction completion changes balance
        _ref.invalidate(balanceProviderFamily);

        // Silently refresh history to show the new transaction
        await _ref.read(paginationControllerProvider.notifier).silentRefresh();
      }
    } catch (e) {
      print('Error checking transaction in history: $e');
      // Continue polling despite errors
    }
  }

  /// Finds a matching transaction in the history based on the pending
  /// transaction.
  /// This matches by amount, from/to addresses, and proximity in time.
  TransactionEvent? _findMatchingTransaction(
    PendingTransactionEvent pendingTx,
    List<TransactionEvent> history,
  ) {
    // Look for transactions that match our pending transaction
    for (final historyTx in history) {
      if (_isMatchingTransaction(pendingTx, historyTx)) {
        return historyTx;
      }
    }

    return null;
  }

  /// Determines if a history transaction matches a pending transaction
  bool _isMatchingTransaction(
    PendingTransactionEvent pendingTx,
    TransactionEvent historyTx,
  ) {
    print('matching history for ${pendingTx.id} ${pendingTx.blockHash}');
    // Match by amount
    if (pendingTx.amount != historyTx.amount) return false;

    // Match by from address
    if (pendingTx.from != historyTx.from) return false;

    // Match by to address
    if (pendingTx.to != historyTx.to) return false;

    print('checking block hash ${pendingTx.blockHash}');
    // If we have a block hash, try to match it
    if (pendingTx.blockHash != null && historyTx.blockHash != null) {
      if (pendingTx.blockHash == historyTx.blockHash) {
        print('found block hash ${pendingTx.id}');
      }
      return pendingTx.blockHash == historyTx.blockHash;
    }

    // Match by timestamp (within reasonable range
    final timeDiff = pendingTx.timestamp.difference(historyTx.timestamp).abs();
    if (timeDiff > const Duration(minutes: 10)) return false;

    // If all other criteria match, consider it a match
    return true;
  }

  /// Manually check all currently tracked transactions (useful for debugging)
  Future<void> forceCheckAllTrackedTransactions() async {
    final pendingTxs = _ref.read(pendingTransactionsProvider);
    for (final tx in pendingTxs) {
      if (tx.transactionState == TransactionState.inBlock) {
        await _checkTransactionInHistory(tx);
      }
    }
  }

  void dispose() {
    // Cancel all active trackers
    for (final timer in _activeTrackers.values) {
      timer.cancel();
    }
    _activeTrackers.clear();
  }
}

/// Provider for the transaction tracking service
final transactionTrackingServiceProvider = Provider<TransactionTrackingService>(
  (ref) {
    final service = TransactionTrackingService(ref);

    // Clean up when provider is disposed
    ref.onDispose(() => service.dispose());

    return service;
  },
);
