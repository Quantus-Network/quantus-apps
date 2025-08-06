// mobile-app/lib/services/transaction_submission_service.dart

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:polkadart/polkadart.dart' as p;
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/all_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/filtered_all_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/pending_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';

class TransactionSubmissionService {
  final Ref _ref;
  final Map<String, Timer> _broadcastSearchTimers = {};
  static const Duration _searchInterval = Duration(seconds: 5);

  TransactionSubmissionService(this._ref);

  Future<void> balanceTransfer(
    Account account,
    String targetAddress,
    BigInt amount,
    BigInt fee,
    int blockHeight,
  ) async {
    // A. Create the initial pending transaction event
    final pendingTx = PendingTransactionEvent(
      tempId: 'pending_${DateTime.now().millisecondsSinceEpoch}',
      from: account.accountId,
      to: targetAddress,
      amount: amount,
      timestamp: DateTime.now(),
      transactionState: TransactionState.created,
      fee: fee,
      blockNumber: blockHeight,
    );

    // B. Immediately add it to the state so the UI can update
    _ref.read(pendingTransactionsProvider.notifier).add(pendingTx);

    // C. Define the builder function that creates fresh submissions on each
    // retry

    // ignore: prefer_function_declarations_over_variables
    final submissionBuilder = () =>
        (Function(p.ExtrinsicStatus) onStatus) => BalancesService()
            .balanceTransfer(account, targetAddress, amount, onStatus);

    // D. Submit and track the transaction
    await _submitAndTrack(submissionBuilder, pendingTx);
  }

  Future<void> scheduleReversibleTransferWithDelaySeconds({
    required Account account,
    required String recipientAddress,
    required BigInt amount,
    required int delaySeconds,
    required BigInt feeEstimate,
    int maxRetries = 3,
    required int blockHeight,
  }) async {
    final pending = createPendingTransaction(
      from: account.accountId,
      to: recipientAddress,
      amount: amount,
      fee: feeEstimate,
      delaySeconds: delaySeconds,
      isReversible: true,
      blockHeight: blockHeight,
    );

    // Add to pending transactions so UI can show it immediately
    _ref.read(pendingTransactionsProvider.notifier).add(pending);

    // Define the builder function that creates fresh submissions on each retry

    // ignore: prefer_function_declarations_over_variables
    final submissionBuilder = () =>
        (Function(p.ExtrinsicStatus) onStatus) => ReversibleTransfersService()
            .scheduleReversibleTransferWithDelaySeconds(
              account: account,
              recipientAddress: recipientAddress,
              amount: amount,
              delaySeconds: delaySeconds,
              onStatus: onStatus,
            );

    await _submitAndTrack(submissionBuilder, pending);
  }

  PendingTransactionEvent createPendingTransaction({
    required String from,
    required String to,
    required BigInt amount,
    required int blockHeight,
    int delaySeconds = 0,
    bool isOutgoing = true,
    bool isReversible = false,
    required BigInt fee,
  }) {
    final tempId = 'pending_${DateTime.now().millisecondsSinceEpoch}';
    final pending = PendingTransactionEvent(
      tempId: tempId,
      from: from,
      to: to,
      amount: amount,
      timestamp: DateTime.now(),
      isReversible: isReversible,
      fee: fee,
      delaySeconds: delaySeconds,
      blockNumber: blockHeight,
    );
    return pending;
  }

  // This is the generic tracking logic, extracted from WalletStateManager
  /// Submits a transaction and tracks its status. Returns immediately without
  /// waiting.
  /// Handles retries in the background for 'invalid' status.
  /// submissionBuilder: Function that creates fresh submission on each retry
  Future<void> _submitAndTrack(
    Future<StreamSubscription<p.ExtrinsicStatus>> Function(
      void Function(p.ExtrinsicStatus),
    )
    Function()
    submissionBuilder,
    PendingTransactionEvent pendingTx, {
    int maxRetries = 3,
  }) async {
    // Start the submission process but don't wait for it to complete
    // This allows the UI to continue immediately
    _submitAndTrackBackground(
      submissionBuilder,
      pendingTx,
      maxRetries: maxRetries,
    );
  }

  StreamSubscription<p.ExtrinsicStatus>? activeSubscription;

  /// Background submission with retry logic - runs asynchronously
  void _submitAndTrackBackground(
    Future<StreamSubscription<p.ExtrinsicStatus>> Function(
      void Function(p.ExtrinsicStatus),
    )
    Function()
    submissionBuilder,
    PendingTransactionEvent pendingTx, {
    required int maxRetries,
    int attempt = 1,
  }) async {
    try {
      print(
        'Submitting transaction attempt $attempt/$maxRetries: ${pendingTx.id}',
      );

      void onStatus(p.ExtrinsicStatus status) {
        String? hash;
        TransactionState newState;

        print('got status ${status.type} value: ${status.value} - $status');
        print(
          ' activeSubscription for ${pendingTx.id}: '
          '${identityHashCode(activeSubscription)}',
        );

        switch (status.type) {
          case 'ready':
            newState = TransactionState.ready;
            break;
          case 'broadcast':
            newState = TransactionState.broadcast;
            // Start searching for the transaction in blockchain history
            _startSearchingForBroadcastTransaction(pendingTx);
            break;
          case 'inBlock':
            newState = TransactionState.inBlock;
            hash = status.value;
            activeSubscription?.cancel();
            activeSubscription = null;
            break;
          case 'finalized':
            // This status is not expected here because we should unsubscribe
            // after 'inBlock' to let the history poller take over.
            newState = TransactionState.inBlock;
            activeSubscription?.cancel();
            activeSubscription = null;
            break;

          case 'invalid':
            print('tx invalid: ${status.type} ${status.value}');
            print('Invalid status detected - transaction data is stale');
            _stopSearchingForBroadcastTransaction(pendingTx.id);
            activeSubscription?.cancel();
            activeSubscription = null;

            // Retry in background if we haven't exceeded max attempts
            if (attempt < maxRetries) {
              print(
                'Retrying transaction with fresh data, attempt ${attempt + 1}/$maxRetries',
              );
              // Brief delay to let blockchain state update
              Timer(const Duration(seconds: 1), () {
                _submitAndTrackBackground(
                  submissionBuilder,
                  pendingTx,
                  maxRetries: maxRetries,
                  attempt: attempt + 1,
                );
              });
            } else {
              print(
                'Max retry attempts reached, marking transaction as failed',
              );
              pendingTx.error = 'Transaction failed after $maxRetries';
              _ref
                  .read(pendingTransactionsProvider.notifier)
                  .updateState(
                    pendingTx.id,
                    TransactionState.failed,
                    error: pendingTx.error,
                  );

              // Remove after delay
              Timer(const Duration(seconds: 3), () {
                _ref
                    .read(pendingTransactionsProvider.notifier)
                    .remove(pendingTx.id);
                print(
                  'Removed failed transaction from pending: ${pendingTx.id}',
                );
              });
            }
            return; // Don't update state for retries

          default:
            print('unknown status: ${status.type} ${status.value}');
            newState = TransactionState.failed;
            pendingTx.error = 'Unknown status: ${status.type}';
            _stopSearchingForBroadcastTransaction(pendingTx.id);
            activeSubscription?.cancel();
            activeSubscription = null;
        }

        // Update state for all non-retry cases
        print('updating tx ${pendingTx.amount} to $newState');
        _ref
            .read(pendingTransactionsProvider.notifier)
            .updateState(
              pendingTx.id,
              newState,
              blockHash: hash,
              error: pendingTx.error,
            );

        // Remove failed transactions after a delay to let user see the failure
        if (newState == TransactionState.failed) {
          Timer(const Duration(seconds: 3), () {
            _ref
                .read(pendingTransactionsProvider.notifier)
                .remove(pendingTx.id);
            print('Removed failed transaction from pending: ${pendingTx.id}');
          });
        }
      }

      // Build a fresh submission for this attempt (gets fresh nonce,
      // block headers, etc.)
      final submission = submissionBuilder();
      activeSubscription = await submission(onStatus);
      print(
        'Assigned activeSubscription for ${pendingTx.id}: '
        '${identityHashCode(activeSubscription)}',
      );
    } catch (e, stackTrace) {
      print('Failed submitting transaction attempt $attempt: $e');

      if (attempt < maxRetries) {
        print(
          'Retrying due to submission error, attempt ${attempt + 1}/$maxRetries',
        );
        // Brief delay before retry
        Timer(const Duration(seconds: 2), () {
          _submitAndTrackBackground(
            submissionBuilder,
            pendingTx,
            maxRetries: maxRetries,
            attempt: attempt + 1,
          );
        });
      } else {
        print('Failed to submit transaction after $maxRetries attempts: $e');
        print('Stack trace: $stackTrace');

        // Mark as permanently failed
        _ref
            .read(pendingTransactionsProvider.notifier)
            .updateState(
              pendingTx.id,
              TransactionState.failed,
              error: 'Failed to submit after $maxRetries attempts: $e',
            );

        // Remove after delay
        Timer(const Duration(seconds: 3), () {
          _ref.read(pendingTransactionsProvider.notifier).remove(pendingTx.id);
          print('Removed failed transaction from pending: ${pendingTx.id}');
        });
      }
    }
  }

  /// Starts searching for a broadcast transaction in blockchain history
  void _startSearchingForBroadcastTransaction(
    PendingTransactionEvent pendingTx,
  ) {
    print('Starting broadcast search for transaction: ${pendingTx.id}');

    if (pendingTx.blockNumber == 0) {
      print(
        'No block number available for transaction ${pendingTx.id},'
        ' cannot search',
      );
      return;
    }

    // Cancel any existing timer for this transaction
    _stopSearchingForBroadcastTransaction(pendingTx.id);

    // Start periodic search
    final timer = Timer.periodic(_searchInterval, (_) {
      _searchForBroadcastTransaction(pendingTx);
    });

    _broadcastSearchTimers[pendingTx.id] = timer;

    // Also search immediately
    _searchForBroadcastTransaction(pendingTx);
  }

  /// Stops searching for a broadcast transaction
  void _stopSearchingForBroadcastTransaction(String transactionId) {
    final timer = _broadcastSearchTimers.remove(transactionId);
    if (timer != null) {
      timer.cancel();
      print('Stopped broadcast search for transaction: $transactionId');
    }
  }

  /// Searches for a broadcast transaction in blockchain history
  Future<void> _searchForBroadcastTransaction(
    PendingTransactionEvent pendingTx,
  ) async {
    try {
      print(
        'Searching blockchain history for broadcast transaction:'
        ' ${pendingTx.id}',
      );

      final historyService = _ref.read(chainHistoryServiceProvider);
      final result = await historyService.searchForPendingTransaction(
        from: pendingTx.from,
        to: pendingTx.to,
        amount: pendingTx.amount,
        isReversible: pendingTx.isReversible,
        blockHeightAfter: pendingTx.blockNumber,
        limit: 5,
      );

      if (result != null) {
        print('Found matching transaction in blockchain for ${pendingTx.id}!');

        // Stop searching since we found it
        _stopSearchingForBroadcastTransaction(pendingTx.id);

        // Trigger silent refresh of history to include the new transaction
        _triggerSilentHistoryRefresh();

        // Update to inHistory state
        _ref
            .read(pendingTransactionsProvider.notifier)
            .updateState(
              pendingTx.id,
              TransactionState.inHistory,
              blockHash: result.blockHash,
            );

        // Remove after a short delay to show completion
        Timer(const Duration(seconds: 2), () {
          _ref.read(pendingTransactionsProvider.notifier).remove(pendingTx.id);
        });

        // Refresh balance since transaction was completed
        _ref.invalidate(balanceProviderFamily);

        print('Successfully completed broadcast transaction: ${pendingTx.id}');
      } else {
        print('No matching transaction found yet for ${pendingTx.id}');
      }
    } catch (e, stackTrace) {
      print('Error searching for broadcast transaction ${pendingTx.id}: $e');
      print('Stack trace: $stackTrace');
    }
  }

  /// Triggers silent refresh on all relevant history providers
  void _triggerSilentHistoryRefresh() {
    print('Triggering silent history refresh for found transaction');

    try {
      // Trigger silent refresh on the main pagination controller (all accounts)
      _ref.read(paginationControllerProvider.notifier).silentRefresh();

      // Invalidate the filtered pagination controller family
      // This will cause all active filtered instances to refresh automatically
      _ref.invalidate(filteredPaginationControllerProviderFamily);

      print('Silent history refresh triggered successfully');
    } catch (e, stackTrace) {
      print('Error triggering silent history refresh: $e');
      print('Stack trace: $stackTrace');
    }
  }

  /// Cleanup method to stop all searches
  void dispose() {
    for (final timer in _broadcastSearchTimers.values) {
      timer.cancel();
    }
    _broadcastSearchTimers.clear();
  }
}

// Provider for the service
final transactionSubmissionServiceProvider =
    Provider<TransactionSubmissionService>((ref) {
      final service = TransactionSubmissionService(ref);

      // Clean up when provider is disposed
      ref.onDispose(() => service.dispose());

      return service;
    });
