import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/global_toast_provider.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/multisig_action_confirmations_provider.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
import 'package:wallet_core/providers/pending_multisig_executions_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/services/extrinsic_indexer_polling_service.dart';
import 'package:wallet_core/services/multisig_execution_reconciliation.dart';
import 'package:wallet_core/services/wallet_session.dart';
import 'package:wallet_core/utils/polling_refresh_scope.dart';

typedef MultisigExecutionPollingService =
    ExtrinsicIndexerPollingService<PendingMultisigExecutionEvent, MultisigAccount>;

Future<bool> _confirmIndexedExecution(Ref ref, MultisigAccount msig, PendingMultisigExecutionEvent pending) async {
  final hash = pending.extrinsicHash;
  if (hash == null) return false;

  final session = ref.read(walletSessionProvider);
  final ticket = session.ticket;
  final multisigService = ref.read(multisigServiceProvider);
  final proposal = await multisigService.getProposal(msig, pending.proposalId);
  if (proposal == null || proposal.status != MultisigProposalStatus.executed) return false;

  final historyService = ref.read(chainHistoryServiceProvider);
  final indexed = await historyService.searchExecutedByExtrinsicHash(extrinsicHash: hash);
  if (indexed == null) return false;
  if (!await session.survivesReset(ticket, dropping: 'confirming execution ${pending.id}')) return true;

  await rereadMultisigProposals(ref, msig);
  if (!await session.survivesReset(ticket, dropping: 'confirming execution ${pending.id}')) return true;
  removePendingMultisigExecution(ref, pending.id);
  _settle(ref, hash, MultisigActionConfirmation.confirmed);
  await reconcileIndexedExecution(ref, msig, indexed);
  return true;
}

/// When the indexer account event lags but the proposal already shows as
/// executed, clear pending state and refresh without a timeout toast.
Future<bool> _tryResolveExecutionTimeout(Ref ref, MultisigAccount msig, PendingMultisigExecutionEvent pending) async {
  final session = ref.read(walletSessionProvider);
  final ticket = session.ticket;
  final dropping = 'resolving execution ${pending.id}';
  final multisigService = ref.read(multisigServiceProvider);
  final proposal = await multisigService.getProposal(msig, pending.proposalId);
  if (proposal == null || proposal.status != MultisigProposalStatus.executed) {
    return false;
  }
  if (!await session.survivesReset(ticket, dropping: dropping)) return true;

  await rereadMultisigProposals(ref, msig);
  if (!await session.survivesReset(ticket, dropping: dropping)) return true;
  removePendingMultisigExecution(ref, pending.id);

  final hash = pending.extrinsicHash;
  if (hash != null) {
    try {
      final indexed = await ref.read(chainHistoryServiceProvider).searchExecutedByExtrinsicHash(extrinsicHash: hash);
      if (!await session.survivesReset(ticket, dropping: dropping)) return true;
      if (indexed != null) {
        _settle(ref, hash, MultisigActionConfirmation.confirmed);
        await reconcileIndexedExecution(ref, msig, indexed);
        return true;
      }
    } catch (e) {
      quantusPrint('[MultisigExecutionPoller] soft timeout reconcile error: $e');
    }
  }
  if (!await session.survivesReset(ticket, dropping: dropping)) return true;

  // The proposal is executed but this user's own extrinsic was never indexed:
  // another signer most likely executed first and this user's submission
  // failed on-chain. Surface that instead of resolving silently.
  quantusPrint(
    '[MultisigExecutionPoller] proposal ${pending.proposalId} executed but extrinsic '
    '${hash ?? '(no hash)'} not indexed; likely executed by another signer',
  );
  if (hash != null) _settle(ref, hash, MultisigActionConfirmation.executedByAnother);
  ref.read(globalToastProvider.notifier).showInfo(ref.read(l10nProvider).multisigExecutedByOtherToast);

  invalidateAccountBalances(ref, {pending.executorId, msig.accountId});
  return true;
}

/// Stops watching for an execution the indexer never showed.
void _giveUpOnExecution(Ref ref, String id) {
  final hash = findPendingMultisigExecution(ref, id)?.extrinsicHash;
  if (hash != null) _settle(ref, hash, MultisigActionConfirmation.unconfirmed);
  removePendingMultisigExecution(ref, id);
}

void _settle(Ref ref, String hash, MultisigActionConfirmation outcome) =>
    ref.read(multisigActionConfirmationsProvider.notifier).settle(hash, outcome);

final multisigExecutionPollingServiceProvider = Provider<MultisigExecutionPollingService>((ref) {
  final service = ExtrinsicIndexerPollingService<PendingMultisigExecutionEvent, MultisigAccount>(
    ref,
    ExtrinsicIndexerPollingConfig(
      logPrefix: '[MultisigExecutionPoller]',
      getId: (pending) => pending.id,
      getExtrinsicHash: (pending) => pending.extrinsicHash,
      isStillPending: (ref, id) => findPendingMultisigExecution(ref, id) != null,
      removePending: _giveUpOnExecution,
      showTimeoutToast: (ref) {
        ref.read(globalToastProvider.notifier).showError(ref.read(l10nProvider).multisigExecutionTimeoutToast);
      },
      confirmIfIndexed: _confirmIndexedExecution,
      tryResolveTimeout: _tryResolveExecutionTimeout,
    ),
  );
  ref.onDispose(service.dispose);
  return service;
});
