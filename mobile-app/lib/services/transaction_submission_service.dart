// mobile-app/lib/services/transaction_submission_service.dart

import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/notification_provider.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/providers/pending_multisig_approvals_provider.dart';
import 'package:resonance_network_wallet/providers/pending_multisig_cancellations_provider.dart';
import 'package:resonance_network_wallet/providers/pending_multisig_executions_provider.dart';
import 'package:resonance_network_wallet/providers/pending_multisig_proposals_provider.dart';
import 'package:resonance_network_wallet/providers/pending_transactions_provider.dart';
import 'package:resonance_network_wallet/services/multisig_approval_polling_service.dart';
import 'package:resonance_network_wallet/services/multisig_cancellation_polling_service.dart';
import 'package:resonance_network_wallet/services/multisig_execution_polling_service.dart';
import 'package:resonance_network_wallet/services/multisig_proposal_polling_service.dart';
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

  /// Submits a multisig transfer proposal and tracks it optimistically.
  ///
  /// Awaits acceptance of the extrinsic by the chain before completing;
  /// indexer polling then continues in the background. Rethrows on submission
  /// failure so callers can surface the error instead of optimistically
  /// navigating away.
  Future<void> proposeTransfer({
    required MultisigAccount msig,
    required Account signer,
    required String recipient,
    required BigInt amount,
    required int expiryBlock,
    required ProposeFeeBreakdown feeBreakdown,
  }) async {
    final pending = PendingMultisigProposalEvent.create(
      msig: msig,
      proposerId: signer.accountId,
      recipient: recipient,
      amount: amount,
      expiryBlock: expiryBlock,
      fee: feeBreakdown.networkFee,
      deposit: feeBreakdown.deposit,
      palletFee: feeBreakdown.creationFee,
    );

    addPendingMultisigProposal(_ref, pending);

    TelemetryService().sendEvent('multisig_propose');

    await _submitProposal(
      msig: msig,
      signer: signer,
      recipient: recipient,
      amount: amount,
      expiryBlock: expiryBlock,
      pending: pending,
    );
  }

  /// Submits a multisig proposal approval and tracks it optimistically.
  ///
  /// Awaits acceptance of the extrinsic by the chain before completing;
  /// indexer polling then continues in the background. Rethrows on submission
  /// failure so callers can surface the error.
  Future<void> approveProposal({
    required MultisigAccount msig,
    required Account signer,
    required MultisigProposal proposal,
  }) async {
    final pending = PendingMultisigApprovalEvent.create(
      multisigAddress: msig.accountId,
      proposalId: proposal.id,
      approverId: signer.accountId,
    );

    addPendingMultisigApproval(_ref, pending);

    TelemetryService().sendEvent('multisig_approve');

    await _submitApprove(msig: msig, signer: signer, proposalId: proposal.id, pending: pending);
  }

  Future<void> _submitApprove({
    required MultisigAccount msig,
    required Account signer,
    required int proposalId,
    required PendingMultisigApprovalEvent pending,
  }) async {
    try {
      final service = _ref.read(multisigServiceProvider);
      final hashBytes = await service.submitApproveExtrinsic(msig: msig, signer: signer, proposalId: proposalId);
      final extrinsicHash = '0x${hex.encode(hashBytes)}';
      quantusDebugPrint('[Approve] submitted: $extrinsicHash');

      updatePendingMultisigApproval(_ref, pending.id, extrinsicHash: extrinsicHash);
      final updated = findPendingMultisigApproval(_ref, pending.id) ?? pending.copyWith(extrinsicHash: extrinsicHash);
      _ref.read(multisigApprovalPollingServiceProvider).startPolling(msig, updated);
    } catch (e, stackTrace) {
      quantusDebugPrint('[Approve] submit failed: $e\n$stackTrace');
      removePendingMultisigApproval(_ref, pending.id);
      rethrow;
    }
  }

  /// Submits a multisig proposal execution and tracks it optimistically.
  ///
  /// Awaits acceptance of the extrinsic by the chain before completing;
  /// indexer polling then continues in the background. Rethrows on submission
  /// failure so callers can surface the error.
  Future<void> executeProposal({
    required MultisigAccount msig,
    required Account signer,
    required MultisigProposal proposal,
    BigInt? fee,
  }) async {
    final pending = PendingMultisigExecutionEvent.fromProposal(
      msig: msig,
      proposal: proposal,
      executorId: signer.accountId,
      fee: fee,
    );

    addPendingMultisigExecution(_ref, pending);

    TelemetryService().sendEvent('multisig_execute');

    await _submitExecute(msig: msig, signer: signer, proposalId: proposal.id, pending: pending);
  }

  Future<void> _submitExecute({
    required MultisigAccount msig,
    required Account signer,
    required int proposalId,
    required PendingMultisigExecutionEvent pending,
  }) async {
    try {
      final service = _ref.read(multisigServiceProvider);
      final hashBytes = await service.submitExecuteExtrinsic(msig: msig, signer: signer, proposalId: proposalId);
      final extrinsicHash = '0x${hex.encode(hashBytes)}';
      quantusDebugPrint('[Execute] submitted: $extrinsicHash');

      updatePendingMultisigExecution(_ref, pending.id, extrinsicHash: extrinsicHash);
      final updated = findPendingMultisigExecution(_ref, pending.id) ?? pending.copyWith(extrinsicHash: extrinsicHash);
      _ref.read(multisigExecutionPollingServiceProvider).startPolling(msig, updated);
    } catch (e, stackTrace) {
      quantusDebugPrint('[Execute] submit failed: $e\n$stackTrace');
      removePendingMultisigExecution(_ref, pending.id);
      rethrow;
    }
  }

  /// Submits a multisig proposal cancellation and tracks it optimistically.
  ///
  /// Awaits acceptance of the extrinsic by the chain before completing;
  /// indexer polling then continues in the background. Rethrows on submission
  /// failure so callers can surface the error.
  Future<void> cancelProposal({
    required MultisigAccount msig,
    required Account proposer,
    required MultisigProposal proposal,
    BigInt? fee,
  }) async {
    final pending = PendingMultisigCancellationEvent.fromProposal(
      msig: msig,
      proposal: proposal,
      proposerId: proposer.accountId,
      fee: fee,
    );

    addPendingMultisigCancellation(_ref, pending);

    TelemetryService().sendEvent('multisig_cancel');

    await _submitCancel(msig: msig, proposer: proposer, proposalId: proposal.id, pending: pending);
  }

  Future<void> _submitCancel({
    required MultisigAccount msig,
    required Account proposer,
    required int proposalId,
    required PendingMultisigCancellationEvent pending,
  }) async {
    try {
      final service = _ref.read(multisigServiceProvider);
      final hashBytes = await service.submitCancelExtrinsic(msig: msig, signer: proposer, proposalId: proposalId);
      final extrinsicHash = '0x${hex.encode(hashBytes)}';
      quantusDebugPrint('[Cancel] submitted: $extrinsicHash');

      updatePendingMultisigCancellation(_ref, pending.id, extrinsicHash: extrinsicHash);
      final updated =
          findPendingMultisigCancellation(_ref, pending.id) ?? pending.copyWith(extrinsicHash: extrinsicHash);
      _ref.read(multisigCancellationPollingServiceProvider).startPolling(msig, updated);
    } catch (e, stackTrace) {
      quantusDebugPrint('[Cancel] submit failed: $e\n$stackTrace');
      removePendingMultisigCancellation(_ref, pending.id);
      rethrow;
    }
  }

  Future<void> _submitProposal({
    required MultisigAccount msig,
    required Account signer,
    required String recipient,
    required BigInt amount,
    required int expiryBlock,
    required PendingMultisigProposalEvent pending,
  }) async {
    try {
      final service = _ref.read(multisigServiceProvider);
      final hashBytes = await service.propose(
        msig: msig,
        signer: signer,
        recipient: recipient,
        amount: amount,
        expiryBlock: expiryBlock,
      );
      final extrinsicHash = '0x${hex.encode(hashBytes)}';
      quantusDebugPrint('[Propose] submitted: $extrinsicHash');

      updatePendingMultisigProposal(_ref, pending.id, extrinsicHash: extrinsicHash);
      final updated = findPendingMultisigProposal(_ref, pending.id) ?? pending.copyWith(extrinsicHash: extrinsicHash);
      _ref.read(multisigProposalPollingServiceProvider).startPolling(msig, updated);
    } catch (e, stackTrace) {
      // Retries live in SubstrateService.submitExtrinsic; avoid outer retries
      // here because each attempt fetches a fresh nonce and can duplicate
      // deposit-reserving proposals if a prior submit already landed.
      quantusDebugPrint('[Propose] submit failed: $e\n$stackTrace');
      removePendingMultisigProposal(_ref, pending.id);
      rethrow;
    }
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

  /// Submits a transaction, awaiting the network's acceptance and the returned
  /// extrinsic hash before completing. Tracking/polling then continues in the
  /// background. Rethrows on submission failure so callers can surface the
  /// error instead of optimistically navigating away.
  ///
  /// Retries live in SubstrateService.submitExtrinsic, which resubmits the
  /// same signed bytes. Outer retries would re-sign with a fresh nonce and can
  /// double spend if a prior submit already reached the network.
  Future<void> submitAndTrackTransaction(Future<Uint8List> Function() submit, PendingTransactionEvent pendingTx) async {
    try {
      quantusDebugPrint('Submitting transaction: ${pendingTx.id}');

      final extrinsicHashBytes = await submit();
      final extrinsicHash = '0x${hex.encode(extrinsicHashBytes)}';
      quantusDebugPrint('submission hash: $extrinsicHash');

      _ref
          .read(pendingTransactionsProvider.notifier)
          .updateState(pendingTx.id, TransactionState.pending, error: pendingTx.error, extrinsicHash: extrinsicHash);

      _startPollingForTransaction(pendingTx.copyWith(extrinsicHash: extrinsicHash));
    } catch (e, stackTrace) {
      quantusDebugPrint('Failed to submit transaction ${pendingTx.id}: $e');
      quantusDebugPrint('Stack trace: $stackTrace');

      _ref.read(pendingTransactionsProvider.notifier).remove(pendingTx.id);
      rethrow;
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
