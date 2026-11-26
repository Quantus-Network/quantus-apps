import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/global_toast_provider.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/multisig_action_confirmations_provider.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
import 'package:wallet_core/providers/pending_multisig_approvals_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/services/extrinsic_indexer_polling_service.dart';
import 'package:wallet_core/services/multisig_approval_reconciliation.dart';
import 'package:wallet_core/services/wallet_session.dart';
import 'package:wallet_core/utils/polling_refresh_scope.dart';

typedef MultisigApprovalPollingService = ExtrinsicIndexerPollingService<PendingMultisigApprovalEvent, MultisigAccount>;

Future<bool> _confirmIndexedApproval(Ref ref, MultisigAccount msig, PendingMultisigApprovalEvent pending) async {
  final hash = pending.extrinsicHash;
  if (hash == null) return false;

  final session = ref.read(walletSessionProvider);
  final ticket = session.ticket;
  final multisigService = ref.read(multisigServiceProvider);
  final proposal = await multisigService.getProposal(msig, pending.proposalId);
  if (proposal == null || !proposal.didApprove(pending.approverId)) return false;

  final historyService = ref.read(chainHistoryServiceProvider);
  final indexed = await historyService.searchSignerApprovedByExtrinsicHash(extrinsicHash: hash);
  if (indexed == null) return false;
  if (!await session.survivesReset(ticket, dropping: 'confirming approval ${pending.id}')) return true;

  await rereadMultisigProposals(ref, msig);
  if (!await session.survivesReset(ticket, dropping: 'confirming approval ${pending.id}')) return true;
  removePendingMultisigApproval(ref, pending.id);
  _settle(ref, hash, MultisigActionConfirmation.confirmed);
  await reconcileIndexedApproval(ref, msig, indexed);
  return true;
}

/// When the indexer account event lags but the proposal already reflects the
/// approval, clear pending state and refresh without a timeout toast.
Future<bool> _tryResolveApprovalTimeout(Ref ref, MultisigAccount msig, PendingMultisigApprovalEvent pending) async {
  final session = ref.read(walletSessionProvider);
  final ticket = session.ticket;
  final dropping = 'resolving approval ${pending.id}';
  final multisigService = ref.read(multisigServiceProvider);
  final proposal = await multisigService.getProposal(msig, pending.proposalId);
  if (proposal == null || !proposal.didApprove(pending.approverId)) {
    return false;
  }
  if (!await session.survivesReset(ticket, dropping: dropping)) return true;

  await rereadMultisigProposals(ref, msig);
  if (!await session.survivesReset(ticket, dropping: dropping)) return true;
  removePendingMultisigApproval(ref, pending.id);

  // The proposal shows this approver's approval, so it went through.
  final hash = pending.extrinsicHash;
  if (hash != null) _settle(ref, hash, MultisigActionConfirmation.confirmed);
  if (hash != null) {
    try {
      final indexed = await ref
          .read(chainHistoryServiceProvider)
          .searchSignerApprovedByExtrinsicHash(extrinsicHash: hash);
      if (!await session.survivesReset(ticket, dropping: dropping)) return true;
      if (indexed != null) {
        await reconcileIndexedApproval(ref, msig, indexed);
        return true;
      }
    } catch (e) {
      quantusPrint('[MultisigApprovalPoller] soft timeout reconcile error: $e');
    }
  }
  if (!await session.survivesReset(ticket, dropping: dropping)) return true;

  invalidateAccountBalances(ref, {pending.approverId});
  return true;
}

/// Stops watching for an approval the indexer never showed.
void _giveUpOnApproval(Ref ref, String id) {
  final hash = findPendingMultisigApproval(ref, id)?.extrinsicHash;
  if (hash != null) _settle(ref, hash, MultisigActionConfirmation.unconfirmed);
  removePendingMultisigApproval(ref, id);
}

void _settle(Ref ref, String hash, MultisigActionConfirmation outcome) =>
    ref.read(multisigActionConfirmationsProvider.notifier).settle(hash, outcome);

final multisigApprovalPollingServiceProvider = Provider<MultisigApprovalPollingService>((ref) {
  final service = ExtrinsicIndexerPollingService<PendingMultisigApprovalEvent, MultisigAccount>(
    ref,
    ExtrinsicIndexerPollingConfig(
      logPrefix: '[MultisigApprovalPoller]',
      getId: (pending) => pending.id,
      getExtrinsicHash: (pending) => pending.extrinsicHash,
      isStillPending: (ref, id) => findPendingMultisigApproval(ref, id) != null,
      removePending: _giveUpOnApproval,
      showTimeoutToast: (ref) {
        ref.read(globalToastProvider.notifier).showError(ref.read(l10nProvider).multisigApprovalTimeoutToast);
      },
      confirmIfIndexed: _confirmIndexedApproval,
      tryResolveTimeout: _tryResolveApprovalTimeout,
    ),
  );
  ref.onDispose(service.dispose);
  return service;
});
