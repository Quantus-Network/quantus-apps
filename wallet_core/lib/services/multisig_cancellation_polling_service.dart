import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/global_toast_provider.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
import 'package:wallet_core/providers/pending_multisig_cancellations_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/services/extrinsic_indexer_polling_service.dart';
import 'package:wallet_core/services/multisig_cancellation_reconciliation.dart';
import 'package:wallet_core/services/wallet_session.dart';
import 'package:wallet_core/utils/polling_refresh_scope.dart';

typedef MultisigCancellationPollingService =
    ExtrinsicIndexerPollingService<PendingMultisigCancellationEvent, MultisigAccount>;

Future<bool> _confirmIndexedCancellation(
  Ref ref,
  MultisigAccount msig,
  PendingMultisigCancellationEvent pending,
) async {
  final hash = pending.extrinsicHash;
  if (hash == null) return false;

  final session = ref.read(walletSessionProvider);
  final ticket = session.ticket;
  final multisigService = ref.read(multisigServiceProvider);
  final proposal = await multisigService.getProposal(msig, pending.proposalId);
  if (proposal == null || proposal.status != MultisigProposalStatus.cancelled) return false;

  final historyService = ref.read(chainHistoryServiceProvider);
  final indexed = await historyService.searchCancelledByExtrinsicHash(extrinsicHash: hash);
  if (indexed == null) return false;
  if (!await session.survivesReset(ticket, dropping: 'confirming cancellation ${pending.id}')) return true;

  removePendingMultisigCancellation(ref, pending.id);
  await reconcileIndexedCancellation(ref, msig, indexed);
  return true;
}

/// When the indexer account event lags but the proposal already reflects the
/// cancellation, clear pending state and refresh without a timeout toast.
Future<bool> _tryResolveCancellationTimeout(
  Ref ref,
  MultisigAccount msig,
  PendingMultisigCancellationEvent pending,
) async {
  final session = ref.read(walletSessionProvider);
  final ticket = session.ticket;
  final dropping = 'resolving cancellation ${pending.id}';
  final multisigService = ref.read(multisigServiceProvider);
  final proposal = await multisigService.getProposal(msig, pending.proposalId);
  if (proposal == null || proposal.status != MultisigProposalStatus.cancelled) {
    return false;
  }
  if (!await session.survivesReset(ticket, dropping: dropping)) return true;

  removePendingMultisigCancellation(ref, pending.id);
  invalidateMultisigProposals(ref, msig);

  final hash = pending.extrinsicHash;
  if (hash != null) {
    try {
      final indexed = await ref.read(chainHistoryServiceProvider).searchCancelledByExtrinsicHash(extrinsicHash: hash);
      if (!await session.survivesReset(ticket, dropping: dropping)) return true;
      if (indexed != null) {
        await reconcileIndexedCancellation(ref, msig, indexed);
        return true;
      }
    } catch (e) {
      quantusPrint('[MultisigCancellationPoller] soft timeout reconcile error: $e');
    }
  }
  if (!await session.survivesReset(ticket, dropping: dropping)) return true;

  invalidateAccountBalances(ref, {pending.proposerId, msig.accountId});
  return true;
}

final multisigCancellationPollingServiceProvider = Provider<MultisigCancellationPollingService>((ref) {
  final service = ExtrinsicIndexerPollingService<PendingMultisigCancellationEvent, MultisigAccount>(
    ref,
    ExtrinsicIndexerPollingConfig(
      logPrefix: '[MultisigCancellationPoller]',
      getId: (pending) => pending.id,
      getExtrinsicHash: (pending) => pending.extrinsicHash,
      isStillPending: (ref, id) => findPendingMultisigCancellation(ref, id) != null,
      removePending: removePendingMultisigCancellation,
      showTimeoutToast: (ref) {
        ref.read(globalToastProvider.notifier).showError(ref.read(l10nProvider).multisigCancelTimeoutToast);
      },
      confirmIfIndexed: _confirmIndexedCancellation,
      tryResolveTimeout: _tryResolveCancellationTimeout,
    ),
  );
  ref.onDispose(service.dispose);
  return service;
});
