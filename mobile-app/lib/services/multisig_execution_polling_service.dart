import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/global_toast_provider.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/providers/pending_multisig_executions_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/services/extrinsic_indexer_polling_service.dart';
import 'package:resonance_network_wallet/services/multisig_execution_reconciliation.dart';
import 'package:resonance_network_wallet/shared/utils/polling_refresh_scope.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';

typedef MultisigExecutionPollingService =
    ExtrinsicIndexerPollingService<PendingMultisigExecutionEvent, MultisigAccount>;

Future<bool> _confirmIndexedExecution(Ref ref, MultisigAccount msig, PendingMultisigExecutionEvent pending) async {
  final hash = pending.extrinsicHash;
  if (hash == null) return false;

  final multisigService = ref.read(multisigServiceProvider);
  final proposal = await multisigService.getProposal(msig, pending.proposalId);
  if (proposal == null || proposal.status != MultisigProposalStatus.executed) return false;

  final historyService = ref.read(chainHistoryServiceProvider);
  final indexed = await historyService.searchExecutedByExtrinsicHash(extrinsicHash: hash);
  if (indexed == null) return false;

  removePendingMultisigExecution(ref, pending.id);
  await reconcileIndexedExecution(ref, msig, indexed);
  return true;
}

/// When the indexer account event lags but the proposal already shows as
/// executed, clear pending state and refresh without a timeout toast.
Future<bool> _tryResolveExecutionTimeout(Ref ref, MultisigAccount msig, PendingMultisigExecutionEvent pending) async {
  final multisigService = ref.read(multisigServiceProvider);
  final proposal = await multisigService.getProposal(msig, pending.proposalId);
  if (proposal == null || proposal.status != MultisigProposalStatus.executed) {
    return false;
  }

  removePendingMultisigExecution(ref, pending.id);
  invalidateMultisigProposals(ref, msig);

  final hash = pending.extrinsicHash;
  if (hash != null) {
    try {
      final indexed = await ref.read(chainHistoryServiceProvider).searchExecutedByExtrinsicHash(extrinsicHash: hash);
      if (indexed != null) {
        await reconcileIndexedExecution(ref, msig, indexed);
        return true;
      }
    } catch (e) {
      quantusDebugPrint('[MultisigExecutionPoller] soft timeout reconcile error: $e');
    }
  }

  // The proposal is executed but this user's own extrinsic was never indexed:
  // another signer most likely executed first and this user's submission
  // failed on-chain. Surface that instead of resolving silently.
  quantusDebugPrint(
    '[MultisigExecutionPoller] proposal ${pending.proposalId} executed but extrinsic '
    '${hash ?? '(no hash)'} not indexed; likely executed by another signer',
  );
  ref.read(globalToastProvider.notifier).showInfo(ref.read(l10nProvider).multisigExecutedByOtherToast);

  invalidateAccountBalances(ref, {pending.executorId, msig.accountId});
  return true;
}

final multisigExecutionPollingServiceProvider = Provider<MultisigExecutionPollingService>((ref) {
  final service = ExtrinsicIndexerPollingService<PendingMultisigExecutionEvent, MultisigAccount>(
    ref,
    ExtrinsicIndexerPollingConfig(
      logPrefix: '[MultisigExecutionPoller]',
      getId: (pending) => pending.id,
      getExtrinsicHash: (pending) => pending.extrinsicHash,
      isStillPending: (ref, id) => findPendingMultisigExecution(ref, id) != null,
      removePending: removePendingMultisigExecution,
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
