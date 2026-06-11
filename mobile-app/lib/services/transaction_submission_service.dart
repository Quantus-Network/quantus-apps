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

    TelemetryService().sendEvent('send_transfer');

    // C. Submit and track the transaction
    await submitAndTrackTransaction(() => BalancesService().balanceTransfer(account, targetAddress, amount), pendingTx);
  }

  Future<void> scheduleReversibleTransferWithDelaySeconds({
    required Account account,
    required String recipientAddress,
    required BigInt amount,
    required int delaySeconds,
    required BigInt feeEstimate,
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

    TelemetryService().sendEvent('send_reversible');

    await submitAndTrackTransaction(
      () => ReversibleTransfersService().scheduleReversibleTransferWithDelaySeconds(
        account: account,
        recipientAddress: recipientAddress,
        amount: amount,
        delaySeconds: delaySeconds,
      ),
      pending,
    );
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

    TelemetryService().sendEvent('send_high_security_reversible');

    await submitAndTrackTransaction(
      () => ReversibleTransfersService().scheduleReversibleTransfer(
        account: account,
        recipientAddress: recipientAddress,
        amount: amount,
      ),
      pendingTx,
    );
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

  /// Submits a transaction in the background and tracks its status. Returns
  /// immediately without waiting.
  ///
  /// Retries live in SubstrateService.submitExtrinsic, which resubmits the
  /// same signed bytes. Outer retries would re-sign with a fresh nonce and can
  /// double spend if a prior submit already reached the network.
  Future<void> submitAndTrackTransaction(Future<Uint8List> Function() submit, PendingTransactionEvent pendingTx) async {
    unawaited(_submitAndTrackBackground(submit, pendingTx));
  }

  Future<void> _submitAndTrackBackground(Future<Uint8List> Function() submit, PendingTransactionEvent pendingTx) async {
    try {
      quantusDebugPrint('Submitting transaction: ${pendingTx.id}');

      final extrinsicHashBytes = await submit();
      final extrinsicHash = '0x${hex.encode(extrinsicHashBytes)}';
      quantusDebugPrint('submission hash: $extrinsicHash');

      final newState = TransactionState.pending;
      quantusDebugPrint('updating tx ${pendingTx.amount} to $newState');
      _ref
          .read(pendingTransactionsProvider.notifier)
          .updateState(pendingTx.id, newState, error: pendingTx.error, extrinsicHash: extrinsicHash);

      _startPollingForTransaction(pendingTx.copyWith(extrinsicHash: extrinsicHash));
    } catch (e, stackTrace) {
      quantusDebugPrint('Failed to submit transaction ${pendingTx.id}: $e');
      quantusDebugPrint('Stack trace: $stackTrace');

      _ref
          .read(pendingTransactionsProvider.notifier)
          .updateState(pendingTx.id, TransactionState.failed, error: 'Failed to submit: $e');
      _ref.read(pendingTransactionsProvider.notifier).remove(pendingTx.id);
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
