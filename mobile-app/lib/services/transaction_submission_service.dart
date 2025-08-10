// mobile-app/lib/services/transaction_submission_service.dart

import 'dart:async';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/account_id_list_cache.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
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
        BalancesService().balanceTransfer(account, targetAddress, amount);

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
        ReversibleTransfersService().scheduleReversibleTransferWithDelaySeconds(
          account: account,
          recipientAddress: recipientAddress,
          amount: amount,
          delaySeconds: delaySeconds,
        );

    await _submitAndTrack(submissionBuilder, pending, maxRetries: maxRetries);
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
    Future<Uint8List> Function() submissionBuilder,
    PendingTransactionEvent pendingTx, {
    int maxRetries = 3,
  }) async {
    // Start the submission process in the background
    // This allows the UI to continue immediately
    unawaited(
      _submitAndTrackBackground(
        submissionBuilder,
        pendingTx,
        maxRetries: maxRetries,
      ),
    );
  }

  /// Background submission with retry logic - runs asynchronously
  Future<void> _submitAndTrackBackground(
    Future<Uint8List> Function() submissionBuilder,
    PendingTransactionEvent pendingTx, {
    required int maxRetries,
    int attempt = 1,
  }) async {
    try {
      print(
        'Submitting transaction attempt $attempt/$maxRetries: ${pendingTx.id}',
      );

      // Build a fresh submission for this attempt (gets fresh nonce,
      // block headers, etc.)
      final extrinsicHash = await submissionBuilder();

      // Convert to hex string for better readability
      final hexString = hex.encode(extrinsicHash);
      print('submission hash: 0x$hexString');

      final newState = TransactionState.broadcast;
      // Update state for all non-retry cases
      print('updating tx ${pendingTx.amount} to $newState');
      _ref
          .read(pendingTransactionsProvider.notifier)
          .updateState(pendingTx.id, newState, error: pendingTx.error);

      _startSearchingForBroadcastTransaction(pendingTx);
    } catch (e, stackTrace) {
      print('Failed submitting transaction attempt $attempt: $e');

      if (attempt < maxRetries) {
        print(
          'Retrying due to submission error, attempt ${attempt + 1}/$maxRetries',
        );
        // Brief delay before retry
        await Future.delayed(const Duration(seconds: 2));
        await _submitAndTrackBackground(
          submissionBuilder,
          pendingTx,
          maxRetries: maxRetries,
          attempt: attempt + 1,
        );
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
        _triggerSilentHistoryRefresh(
          affectedAccountIds: {pendingTx.from, pendingTx.to},
        );

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
      }
    } catch (e, stackTrace) {
      print('Error searching for broadcast transaction ${pendingTx.id}: $e');
      print('Stack trace: $stackTrace');
    }
  }

  /// Triggers silent refresh on relevant history providers
  void _triggerSilentHistoryRefresh({Set<String>? affectedAccountIds}) {
    print('Triggering silent history refresh for found transaction');

    try {
      // Trigger silent refresh on the main pagination controller (all accounts)
      _ref.read(paginationControllerProvider.notifier).silentRefresh();

      final targets = <String>{...?(affectedAccountIds)};
      final active = _ref.read(activeAccountProvider).value;
      if (active != null) {
        targets.add(active.accountId);
      }

      for (final accountId in targets) {
        _ref
            .read(
              filteredPaginationControllerProviderFamily(
                AccountIdListCache.get([accountId]),
              ).notifier,
            )
            .silentRefresh();
      }

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
