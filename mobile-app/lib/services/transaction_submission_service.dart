// mobile-app/lib/services/transaction_submission_service.dart

import 'dart:async';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/all_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/notification_provider.dart';
import 'package:resonance_network_wallet/providers/pending_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/services/telemetry_service.dart';
import 'package:resonance_network_wallet/shared/utils/tx_filter_family_provider.dart';

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
    final submissionBuilder = () => BalancesService().balanceTransfer(account, targetAddress, amount);

    TelemetryService().sendEvent('send_transfer');

    // D. Submit and track the transaction
    await submitAndTrackTransaction(submissionBuilder, pendingTx);
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
    final submissionBuilder = () => ReversibleTransfersService().scheduleReversibleTransferWithDelaySeconds(
      account: account,
      recipientAddress: recipientAddress,
      amount: amount,
      delaySeconds: delaySeconds,
    );

    TelemetryService().sendEvent('send_reversible');

    await submitAndTrackTransaction(submissionBuilder, pending, maxRetries: maxRetries);
  }

  Future<void> scheduleTransfer({
    required Account account,
    required String recipientAddress,
    required BigInt amount,
    required BigInt fee,
    required int blockHeight,
  }) async {
    // A. Create the initial pending transaction event
    final pendingTx = PendingTransactionEvent(
      tempId: 'pending_${DateTime.now().millisecondsSinceEpoch}',
      from: account.accountId,
      to: recipientAddress,
      amount: amount,
      timestamp: DateTime.now(),
      transactionState: TransactionState.created,
      fee: fee,
      blockNumber: blockHeight,
      isReversible: true,
    );

    // B. Immediately add it to the state so the UI can update
    _ref.read(pendingTransactionsProvider.notifier).add(pendingTx);

    // C. Define the builder function that creates fresh submissions on each retry
    Future<Uint8List> submissionBuilder() async {
      return ReversibleTransfersService().scheduleReversibleTransfer(
        account: account,
        recipientAddress: recipientAddress,
        amount: amount,
      );
    }

    TelemetryService().sendEvent('send_high_security_reversible');

    await submitAndTrackTransaction(submissionBuilder, pendingTx);
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
  Future<void> submitAndTrackTransaction(
    Future<Uint8List> Function() submissionBuilder,
    PendingTransactionEvent pendingTx, {
    int maxRetries = 3,
  }) async {
    // Start the submission process in the background
    // This allows the UI to continue immediately
    unawaited(_submitAndTrackBackground(submissionBuilder, pendingTx, maxRetries: maxRetries));
  }

  /// Background submission with retry logic - runs asynchronously
  Future<void> _submitAndTrackBackground(
    Future<Uint8List> Function() submissionBuilder,
    PendingTransactionEvent pendingTx, {
    required int maxRetries,
    int attempt = 1,
  }) async {
    try {
      print('Submitting transaction attempt $attempt/$maxRetries: ${pendingTx.id}');

      // Build a fresh submission for this attempt (gets fresh nonce,
      // block headers, etc.)
      final extrinsicHash = await submissionBuilder();

      // Convert to hex string for better readability
      final hexString = hex.encode(extrinsicHash);
      print('submission hash: 0x$hexString');

      final newState = TransactionState.pending;
      // Update state for all non-retry cases
      print('updating tx ${pendingTx.amount} to $newState');
      _ref.read(pendingTransactionsProvider.notifier).updateState(pendingTx.id, newState, error: pendingTx.error);

      _startSearchingForBroadcastTransaction(pendingTx);
    } catch (e, stackTrace) {
      print('Failed submitting transaction attempt $attempt: $e');

      if (attempt < maxRetries) {
        print('Retrying due to submission error, attempt ${attempt + 1}/$maxRetries');
        // Brief delay before retry
        await Future.delayed(const Duration(seconds: 2));
        await _submitAndTrackBackground(submissionBuilder, pendingTx, maxRetries: maxRetries, attempt: attempt + 1);
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
        _ref.read(pendingTransactionsProvider.notifier).remove(pendingTx.id);
      }
    }
  }

  /// Starts searching for a broadcast transaction in blockchain history
  void _startSearchingForBroadcastTransaction(PendingTransactionEvent pendingTx) {
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

    const timeoutDuration = Duration(minutes: 5);
    final startTime = DateTime.now();

    // Start periodic search
    final timer = Timer.periodic(_searchInterval, (_) {
      if (DateTime.now().difference(startTime) > timeoutDuration) {
        print(
          'Search timed out for transaction: ${pendingTx.id} - removing from pending but not marking as failed since we cannot verify failure on-chain',
        );

        _stopSearchingForBroadcastTransaction(pendingTx.id);
        _ref.read(pendingTransactionsProvider.notifier).remove(pendingTx.id);
        return;
      }

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
  Future<void> _searchForBroadcastTransaction(PendingTransactionEvent pendingTx) async {
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
        _triggerSilentHistoryRefresh(affectedAccountIds: {pendingTx.from, pendingTx.to}, newTransaction: result);

        // Update to inHistory state
        _ref
            .read(pendingTransactionsProvider.notifier)
            .updateState(pendingTx.id, TransactionState.inHistory, blockHash: result.blockHash);

        final account = _ref.read(accountsProvider.notifier).getAccountWithId(pendingTx.from);

        if (result is TransferEvent) {
          _ref.read(notificationProvider.notifier).addTokenSent(account: account, transactionData: result);
        } else if (result is ReversibleTransferEvent) {
          _ref
              .read(notificationProvider.notifier)
              .addReversibleTransactionReminder(account: account, transactionData: result);
        }

        // Remove immediately to prevent duplication/glitches as we've already added it to history
        _ref.read(pendingTransactionsProvider.notifier).remove(pendingTx.id);

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
  void _triggerSilentHistoryRefresh({Set<String>? affectedAccountIds, TransactionEvent? newTransaction}) {
    print('Triggering silent history refresh for found transaction');

    try {
      // Trigger silent refresh on the main pagination controller (all accounts)
      final mainController = _ref.read(paginationControllerProvider.notifier);
      if (newTransaction != null) {
        mainController.addTransactionToHistory(newTransaction);
      }
      mainController.silentRefresh();

      final targets = affectedAccountIds?.map((id) => [id]).toList() ?? [];
      final active = _ref.read(activeAccountProvider).value;

      if (active != null) {
        targets.add([active.account.accountId]);
      }

      final accountIds = _ref.read(accountsProvider).value?.map((a) => a.accountId).toList() ?? [];
      if (accountIds.isNotEmpty) {
        targets.add(accountIds);
      }

      for (final targetIds in targets) {
        if (newTransaction != null) {
          updatePaginationFiltersFor(_ref.read, targetIds, (notifier, filter) {
            if (filter != TransactionFilter.receive) {
              notifier.addTransactionToHistory(newTransaction);
            }
          });
        }

        updatePaginationFiltersFor(_ref.read, targetIds, (notifier, _) {
          notifier.silentRefresh();
        });
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
final transactionSubmissionServiceProvider = Provider<TransactionSubmissionService>((ref) {
  final service = TransactionSubmissionService(ref);

  // Clean up when provider is disposed
  ref.onDispose(() => service.dispose());

  return service;
});
