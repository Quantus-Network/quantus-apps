// mobile-app/lib/services/transaction_submission_service.dart

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:polkadart/polkadart.dart' as p;
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/pending_transactions_provider.dart';

class TransactionSubmissionService {
  final Ref _ref;
  StreamSubscription<p.ExtrinsicStatus>? activeSubscription;

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
  }) async {
    final pending = createPendingTransaction(
      from: account.accountId,
      to: recipientAddress,
      amount: amount,
      fee: feeEstimate,
      delaySeconds: delaySeconds,
      isReversible: true,
    );

    // Add to pending transactions so UI can show it immediately
    _ref.read(pendingTransactionsProvider.notifier).add(pending);

    // Define the builder function that creates fresh submissions on each retry

    // ignore: prefer_function_declarations_over_variables
    final submissionBuilder = () =>
        (onStatus) => ReversibleTransfersService()
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
            // Unsubscribe after inBlock to let the history poller take over
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
            activeSubscription?.cancel();
            activeSubscription = null;
        }

        // Update state for all non-retry cases
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
}

// Provider for the service
final transactionSubmissionServiceProvider =
    Provider<TransactionSubmissionService>((ref) {
      return TransactionSubmissionService(ref);
    });
