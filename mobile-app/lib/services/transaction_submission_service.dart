// mobile-app/lib/services/transaction_submission_service.dart

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:polkadart/polkadart.dart' as p;
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/pending_transactions_provider.dart';

class TransactionSubmissionService {
  final Ref _ref;
  TransactionSubmissionService(this._ref);

  Future<void> balanceTransfer(
    Account account,
    String targetAddress,
    BigInt amount,
    BigInt fee,
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
    );

    // B. Immediately add it to the state so the UI can update
    _ref.read(pendingTransactionsProvider.notifier).add(pendingTx);

    // C. Define the function that performs the submission
    // ignore: prefer_function_declarations_over_variables
    final submissionCall = (Function(p.ExtrinsicStatus) onStatus) =>
        BalancesService().balanceTransfer(
          account,
          targetAddress,
          amount,
          onStatus,
        );

    // D. Submit and track the transaction
    await _submitAndTrack(submissionCall, pendingTx);
  }

  Future<void> scheduleReversibleTransferWithDelaySeconds({
    required Account account,
    required String recipientAddress,
    required BigInt amount,
    required int delaySeconds,
    required BigInt feeEstimate,
    int maxRetries = 3,
  }) async {
    final pending = createPendingTransaction(
      from: account.accountId,
      to: recipientAddress,
      amount: amount,
      fee: feeEstimate,
      isReversible: true,
    );

    await _submitAndTrack(
      (onStatus) => ReversibleTransfersService()
          .scheduleReversibleTransferWithDelaySeconds(
            account: account,
            recipientAddress: recipientAddress,
            amount: amount,
            delaySeconds: delaySeconds,
            onStatus: onStatus,
          ),
      pending,
    );
  }

  PendingTransactionEvent createPendingTransaction({
    required String from,
    required String to,
    required BigInt amount,
    DateTime? scheduledAt,
    bool isOutgoing = true,
    bool isReversible = false,
    required BigInt fee,
  }) {
    final tempId = 'pending_${DateTime.now().millisecondsSinceEpoch}';
    final timestamp = DateTime.now();
    final pending = PendingTransactionEvent(
      tempId: tempId,
      from: from,
      to: to,
      amount: amount,
      timestamp: timestamp,
      isReversible: isReversible,
      fee: fee,
      scheduledAtTime: scheduledAt,
    );
    return pending;
  }

  // This is the generic tracking logic, extracted from WalletStateManager
  Future<void> _submitAndTrack(
    Future<StreamSubscription<p.ExtrinsicStatus>> Function(
      void Function(p.ExtrinsicStatus),
    )
    submission,
    PendingTransactionEvent pendingTx, {
    int maxRetries = 3,
  }) async {
    void onStatus(p.ExtrinsicStatus status) {
      String? hash;
      TransactionState newState;
      switch (status.type) {
        case 'ready':
          newState = TransactionState.ready;
          break;
        case 'broadcast':
          newState = TransactionState.broadcast;
          break;
        case 'inBlock':
          newState = TransactionState.inBlock;
          hash = status.value;
          break;
        case 'finalized':
          // This status is not expected here because we should unsubscribe
          // after 'inBlock' to let the history poller take over.
          newState = TransactionState.inBlock;
          break;
        default:
          newState = TransactionState.failed;
          pendingTx.error = 'Unknown status: ${status.type}';
      }
      _ref
          .read(pendingTransactionsProvider.notifier)
          .updateState(
            pendingTx.id,
            newState,
            blockHash: hash,
            error: pendingTx.error,
          );
    }

    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        await submission(onStatus);
        return; // Success, exit the retry loop.
      } catch (e, stackTrace) {
        attempts++;
        if (attempts >= maxRetries) {
          // TODO the UI should show an alert that the tx failed, and then remove
          // the failed tx from pending.
          _ref
              .read(pendingTransactionsProvider.notifier)
              .updateState(
                pendingTx.id,
                TransactionState.failed,
                error: e.toString(),
              );
          print('Failed to submit transaction after $maxRetries attempts: $e');
          print('Stack trace: $stackTrace');
          rethrow;
        } else {
          print('Transaction attempt $attempts failed: $e. Retrying...');
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }
    await submission(onStatus);
  }
}

// Provider for the service
final transactionSubmissionServiceProvider =
    Provider<TransactionSubmissionService>((ref) {
      return TransactionSubmissionService(ref);
    });
