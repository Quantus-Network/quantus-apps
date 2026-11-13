import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/global_toast_provider.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/pending_multisig_proposals_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/services/extrinsic_indexer_polling_service.dart';
import 'package:wallet_core/services/multisig_proposal_reconciliation.dart';
import 'package:wallet_core/utils/polling_refresh_scope.dart';

typedef MultisigProposalPollingService = ExtrinsicIndexerPollingService<PendingMultisigProposalEvent, MultisigAccount>;

Future<bool> _confirmIndexedProposal(Ref ref, MultisigAccount msig, PendingMultisigProposalEvent pending) async {
  final hash = pending.extrinsicHash;
  if (hash == null) return false;

  final historyService = ref.read(chainHistoryServiceProvider);
  final indexed = await historyService.searchProposalCreatedByExtrinsicHash(extrinsicHash: hash);
  if (indexed == null) return false;

  removePendingMultisigProposal(ref, pending.id);
  await reconcileIndexedProposalCreation(ref, msig, indexed);
  invalidateAccountBalances(ref, {pending.proposerId});
  return true;
}

final multisigProposalPollingServiceProvider = Provider<MultisigProposalPollingService>((ref) {
  final service = ExtrinsicIndexerPollingService<PendingMultisigProposalEvent, MultisigAccount>(
    ref,
    ExtrinsicIndexerPollingConfig(
      logPrefix: '[MultisigProposalPoller]',
      getId: (pending) => pending.id,
      getExtrinsicHash: (pending) => pending.extrinsicHash,
      isStillPending: (ref, id) => findPendingMultisigProposal(ref, id) != null,
      removePending: removePendingMultisigProposal,
      showTimeoutToast: (ref) {
        ref.read(globalToastProvider.notifier).showError(ref.read(l10nProvider).multisigProposeTimeoutToast);
      },
      confirmIfIndexed: _confirmIndexedProposal,
    ),
  );
  ref.onDispose(service.dispose);
  return service;
});
