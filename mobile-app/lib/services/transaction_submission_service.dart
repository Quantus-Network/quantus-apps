// mobile-app/lib/services/transaction_submission_service.dart

import 'dart:async';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/notification_provider.dart';
import 'package:resonance_network_wallet/providers/pending_transactions_provider.dart';
import 'package:resonance_network_wallet/services/pending_transaction_polling_service.dart';
import 'package:resonance_network_wallet/services/telemetry_service.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';

class TransactionSubmissionService {
  final Ref _ref;
  final PendingTransactionPollingService _poller;

  TransactionSubmissionService(this._ref) : _poller = PendingTransactionPollingService(_ref);

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
      quantusDebugPrint('Submitting transaction attempt $attempt/$maxRetries: ${pendingTx.id}');

      final extrinsicHashBytes = await submissionBuilder();
      final extrinsicHash = '0x${hex.encode(extrinsicHashBytes)}';
      quantusDebugPrint('submission hash: $extrinsicHash');

      final newState = TransactionState.pending;
      quantusDebugPrint('updating tx ${pendingTx.amount} to $newState');
      _ref
          .read(pendingTransactionsProvider.notifier)
          .updateState(pendingTx.id, newState, error: pendingTx.error, extrinsicHash: extrinsicHash);

      _startPollingForTransaction(pendingTx.copyWith(extrinsicHash: extrinsicHash));
    } catch (e, stackTrace) {
      quantusDebugPrint('Failed submitting transaction attempt $attempt: $e');

      if (attempt < maxRetries) {
        quantusDebugPrint('Retrying due to submission error, attempt ${attempt + 1}/$maxRetries');
        // Brief delay before retry
        await Future.delayed(const Duration(seconds: 2));
        await _submitAndTrackBackground(submissionBuilder, pendingTx, maxRetries: maxRetries, attempt: attempt + 1);
      } else {
        quantusDebugPrint('Failed to submit transaction after $maxRetries attempts: $e');
        quantusDebugPrint('Stack trace: $stackTrace');

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

  void _startPollingForTransaction(PendingTransactionEvent pendingTx) {
    _poller.startPolling(
      pendingTx,
      onFound: (result) {
        final account = _ref.read(accountsProvider.notifier).getAccountWithId(pendingTx.from);
        if (result is TransferEvent) {
          _ref.read(notificationProvider.notifier).addTokenSent(account: account, transactionData: result);
        } else if (result is ReversibleTransferEvent) {
          _ref
              .read(notificationProvider.notifier)
              .addReversibleTransactionReminder(account: account, transactionData: result);
        }
      },
    );
  }

  void dispose() => _poller.dispose();
}

// Provider for the service
final transactionSubmissionServiceProvider = Provider<TransactionSubmissionService>((ref) {
  final service = TransactionSubmissionService(ref);

  // Clean up when provider is disposed
  ref.onDispose(() => service.dispose());

  return service;
});
