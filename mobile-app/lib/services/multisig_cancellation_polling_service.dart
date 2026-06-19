import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/global_toast_provider.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/providers/pending_multisig_cancellations_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/services/extrinsic_indexer_polling_service.dart';
import 'package:resonance_network_wallet/services/multisig_cancellation_reconciliation.dart';
import 'package:resonance_network_wallet/shared/utils/polling_refresh_scope.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';

typedef MultisigCancellationPollingService =
    ExtrinsicIndexerPollingService<PendingMultisigCancellationEvent, MultisigAccount>;

Future<bool> _confirmIndexedCancellation(
  Ref ref,
  MultisigAccount msig,
  PendingMultisigCancellationEvent pending,
) async {
  final hash = pending.extrinsicHash;
  if (hash == null) return false;

  final multisigService = ref.read(multisigServiceProvider);
  final proposal = await multisigService.getProposal(msig, pending.proposalId);
  if (proposal == null || proposal.status != MultisigProposalStatus.cancelled) return false;

  final historyService = ref.read(chainHistoryServiceProvider);
  final indexed = await historyService.searchCancelledByExtrinsicHash(extrinsicHash: hash);
  if (indexed == null) return false;

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
  final multisigService = ref.read(multisigServiceProvider);
  final proposal = await multisigService.getProposal(msig, pending.proposalId);
  if (proposal == null || proposal.status != MultisigProposalStatus.cancelled) {
    return false;
  }

  removePendingMultisigCancellation(ref, pending.id);
  invalidateMultisigProposals(ref, msig);

  final hash = pending.extrinsicHash;
  if (hash != null) {
    try {
      final indexed = await ref.read(chainHistoryServiceProvider).searchCancelledByExtrinsicHash(extrinsicHash: hash);
      if (indexed != null) {
        await reconcileIndexedCancellation(ref, msig, indexed);
        return true;
      }
    } catch (e) {
      quantusDebugPrint('[MultisigCancellationPoller] soft timeout reconcile error: $e');
    }
  }

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
