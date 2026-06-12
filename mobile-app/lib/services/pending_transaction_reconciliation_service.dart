// ignore_for_file: lines_longer_than_80_chars

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/filtered_transactions_params.dart';
import 'package:resonance_network_wallet/providers/account_id_list_cache.dart';
import 'package:resonance_network_wallet/providers/filtered_all_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/pending_cancellations_provider.dart';
import 'package:resonance_network_wallet/providers/pending_transactions_provider.dart';
import 'package:resonance_network_wallet/services/transaction_service.dart';
import 'package:resonance_network_wallet/shared/utils/polling_refresh_scope.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';

/// Service that reconciles pending transactions with confirmed transactions
/// from blockchain history. This handles cases where the inBlock status
/// event is missed, preventing transactions from being stuck in pending state.
class PendingTransactionReconciliationService {
  final Ref _ref;

  // Configuration constants
  static const Duration _stalePendingThreshold = Duration(minutes: 2); // More aggressive
  static const Duration _maxPendingAge = Duration(minutes: 30); // Much more aggressive

  PendingTransactionReconciliationService(this._ref);

  /// Immediately triggers reconciliation (useful for testing or manual cleanup)
  Future<void> forceReconciliation() async {
    quantusDebugPrint('PendingReconciliation: Force reconciliation triggered');
    await reconcilePendingTransactions();
  }

  /// Reconciles pending transactions with confirmed transactions from history.
  /// This should be called during history polling to clean up stale pending
  /// transactions.
  Future<void> reconcilePendingTransactions() async {
    final txService = _ref.read(transactionServiceProvider);

    try {
      final pendingTxs = _ref.read(pendingTransactionsProvider);

      if (pendingTxs.isEmpty) return;

      quantusDebugPrint(
        'PendingReconciliation: Checking ${pendingTxs.length} '
        'pending transactions',
      );
      final activeId = activeAccountId(_ref);
      final accountIds = reconciliationAccountIds(activeId: activeId, pendingTxs: pendingTxs);

      for (final accountId in accountIds) {
        await refreshAccountsPagination(
          _ref,
          accountIds: [accountId],
          action: (notifier) => notifier.silentRefresh(),
          isAccountInactive: accountId != activeId,
        );
      }

      final confirmedTransactions = _loadConfirmedTransactions(txService, accountIds);

      if (confirmedTransactions.isEmpty) {
        quantusDebugPrint('PendingReconciliation: No confirmed transactions to match against');
        return;
      }

      final now = DateTime.now();
      final stalePendingTxs = pendingTxs.where((tx) => _isStalePendingTransaction(tx, now)).toList();

      if (stalePendingTxs.isEmpty) {
        quantusDebugPrint('PendingReconciliation: No stale pending transactions found');
        return;
      }

      quantusDebugPrint(
        'PendingReconciliation: Found ${stalePendingTxs.length} stale '
        'pending transactions',
      );

      // Check each stale pending transaction for matches
      for (final pendingTx in stalePendingTxs) {
        await _reconcilePendingTransaction(pendingTx, confirmedTransactions, now);
      }
    } catch (e, stackTrace) {
      quantusDebugPrint('PendingReconciliation: Error during reconciliation: $e');
      quantusDebugPrint('Stack trace: $stackTrace');
    }
  }

  List<TransactionEvent> _loadConfirmedTransactions(TransactionService txService, Set<String> accountIds) {
    final pendingCancellationIds = _ref.read(pendingCancellationsProvider);
    final confirmedById = <String, TransactionEvent>{};

    for (final accountId in accountIds) {
      final params = FilteredTransactionsParams(
        accountIds: AccountIdListCache.get([accountId]),
        filter: TransactionFilter.all,
      );
      final pagination = _ref.read(filteredPaginationControllerProviderFamily(params));
      if (!pagination.hasLoadedChainData) continue;

      final combined = txService.combineAndDeduplicateTransactions(
        pendingCancellationIds: pendingCancellationIds,
        pendingTransactions: [],
        pendingMultisigCreations: [],
        pendingMultisigProposals: const [],
        pendingMultisigExecutions: const [],
        pendingMultisigCancellations: const [],
        scheduledReversibleTransfers: pagination.scheduledReversibleTransfers,
        otherTransfers: pagination.otherTransfers,
      );

      for (final tx in combined) {
        confirmedById[tx.id] = tx;
      }
    }

    return confirmedById.values.toList();
  }

  /// Determines if a pending transaction is stale and should be checked for
  /// reconciliation
  bool _isStalePendingTransaction(PendingTransactionEvent pendingTx, DateTime now) {
    final age = now.difference(pendingTx.timestamp);

    quantusDebugPrint(
      'PendingReconciliation: Checking tx ${pendingTx.id}: '
      'age=${age.inMinutes}min, state=${pendingTx.transactionState}',
    );

    // Check if transaction has been pending for too long
    if (age > _maxPendingAge) {
      quantusDebugPrint(
        'PendingReconciliation: Transaction ${pendingTx.id} is too '
        'old (${age.inMinutes} minutes), will be removed',
      );
      return true;
    }

    // Check if transaction is stale (been in broadcast/inBlock state for too long)
    if (age > _stalePendingThreshold &&
        (pendingTx.transactionState == TransactionState.pending ||
            pendingTx.transactionState == TransactionState.inBlock)) {
      quantusDebugPrint(
        'PendingReconciliation: Transaction ${pendingTx.id} is'
        ' stale (${age.inMinutes} minutes in ${pendingTx.transactionState} '
        'state)',
      );
      return true;
    }

    quantusDebugPrint(
      'PendingReconciliation: Transaction ${pendingTx.id} not '
      'considered stale yet',
    );
    return false;
  }

  /// Reconciles a single pending transaction against confirmed transactions
  Future<void> _reconcilePendingTransaction(
    PendingTransactionEvent pendingTx,
    List<TransactionEvent> confirmedTransactions,
    DateTime now,
  ) async {
    try {
      final age = now.difference(pendingTx.timestamp);

      // If transaction is extremely old, just remove it
      if (age > _maxPendingAge) {
        quantusDebugPrint(
          'PendingReconciliation: Removing expired transaction'
          ' ${pendingTx.id} (age: ${age.inMinutes} minutes)',
        );
        await _removePendingTransaction(pendingTx, 'Transaction expired after ${age.inMinutes} minutes');
        return;
      }

      // Look for matching confirmed transaction
      final matchingTransaction = _findMatchingConfirmedTransaction(pendingTx, confirmedTransactions);

      if (matchingTransaction != null) {
        quantusDebugPrint(
          'PendingReconciliation: Found matching confirmed transaction for'
          ' ${pendingTx.id}',
        );
        quantusDebugPrint('  Pending: ${pendingTx.from} → ${pendingTx.to}, amount: ${pendingTx.amount}');
        quantusDebugPrint(
          '  Confirmed: ${matchingTransaction.from} → ${matchingTransaction.to}, amount: ${matchingTransaction.amount}',
        );

        await _removePendingTransaction(pendingTx, 'Found matching confirmed transaction in history');

        invalidateAccountBalances(_ref, {pendingTx.from, pendingTx.to});
      } else {
        quantusDebugPrint('PendingReconciliation: No matching confirmed transaction found for ${pendingTx.id}');

        // If it's been stale for a very long time, consider it failed
        if (age > const Duration(minutes: 30)) {
          quantusDebugPrint('PendingReconciliation: Marking long-stale transaction ${pendingTx.id} as failed');
          await _markFailedAndRemove(pendingTx, 'Transaction not found in blockchain after ${age.inMinutes} minutes');
        }
      }
    } catch (e, stackTrace) {
      quantusDebugPrint('PendingReconciliation: Error reconciling transaction ${pendingTx.id}: $e');
      quantusDebugPrint('Stack trace: $stackTrace');
    }
  }

  /// Finds a confirmed transaction that matches the pending transaction
  TransactionEvent? _findMatchingConfirmedTransaction(
    PendingTransactionEvent pendingTx,
    List<TransactionEvent> confirmedTransactions,
  ) {
    for (final confirmedTx in confirmedTransactions) {
      if (_isMatchingTransaction(pendingTx, confirmedTx)) {
        return confirmedTx;
      }
    }
    return null;
  }

  /// Determines if a confirmed transaction matches a pending transaction
  /// Uses the same logic as the transaction tracking service but more lenient on timing
  bool _isMatchingTransaction(PendingTransactionEvent pendingTx, TransactionEvent confirmedTx) {
    // Match by amount (must be exact)
    if (pendingTx.amount != confirmedTx.amount) return false;

    // Match by from address (must be exact)
    if (pendingTx.from != confirmedTx.from) return false;

    // Match by to address (must be exact)
    if (pendingTx.to != confirmedTx.to) return false;

    // Match by reversible status if it's a reversible transfer
    if (confirmedTx is ReversibleTransferEvent) {
      if (!pendingTx.isReversible) return false;
    } else {
      if (pendingTx.isReversible) return false;
    }

    // If we have a block hash and it matches, that's a strong indicator
    if (pendingTx.blockHash != null && confirmedTx.blockHash != null) {
      if (pendingTx.blockHash == confirmedTx.blockHash) {
        return true;
      }
    }

    // Match by timestamp (more lenient than the tracking service)
    // Transactions can sometimes have different timestamps due to network delays
    final timeDiff = pendingTx.timestamp.difference(confirmedTx.timestamp).abs();
    if (timeDiff > const Duration(minutes: 30)) return false;

    // If all criteria match, consider it a match
    return true;
  }

  /// Removes a pending transaction with logging
  Future<void> _removePendingTransaction(PendingTransactionEvent pendingTx, String reason) async {
    quantusDebugPrint('PendingReconciliation: Removing pending transaction ${pendingTx.id} - $reason');

    // Update to inHistory state first to show completion
    _ref.read(pendingTransactionsProvider.notifier).updateState(pendingTx.id, TransactionState.inHistory);

    // Remove after a short delay to let UI show the completion
    Timer(const Duration(seconds: 1), () {
      _ref.read(pendingTransactionsProvider.notifier).remove(pendingTx.id);
      quantusDebugPrint('PendingReconciliation: Removed pending transaction ${pendingTx.id}');
    });
  }

  /// Marks a pending transaction as failed
  Future<void> _markFailedAndRemove(PendingTransactionEvent pendingTx, String reason) async {
    quantusDebugPrint('PendingReconciliation: Marking transaction ${pendingTx.id} as failed - $reason');

    _ref.read(pendingTransactionsProvider.notifier).updateState(pendingTx.id, TransactionState.failed, error: reason);

    // Remove failed transaction after a delay to let user see the failure
    Timer(const Duration(seconds: 5), () {
      _ref.read(pendingTransactionsProvider.notifier).remove(pendingTx.id);
      quantusDebugPrint('PendingReconciliation: Removed failed transaction ${pendingTx.id}');
    });
  }
}

/// Provider for the pending transaction reconciliation service
final pendingTransactionReconciliationServiceProvider = Provider<PendingTransactionReconciliationService>((ref) {
  return PendingTransactionReconciliationService(ref);
});
