import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/multisig_approval_toast_provider.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/providers/pending_multisig_approvals_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/services/extrinsic_indexer_polling_service.dart';
import 'package:resonance_network_wallet/services/multisig_approval_reconciliation.dart';

typedef MultisigApprovalPollingService =
    ExtrinsicIndexerPollingService<PendingMultisigApprovalEvent, MultisigAccount>;

Future<bool> _confirmIndexedApproval(
  Ref ref,
  MultisigAccount msig,
  PendingMultisigApprovalEvent pending,
) async {
  final hash = pending.extrinsicHash;
  if (hash == null) return false;

  final multisigService = ref.read(multisigServiceProvider);
  final proposal = await multisigService.getProposal(msig, pending.proposalId);
  if (proposal == null || !proposal.didApprove(pending.approverId)) return false;

  final historyService = ref.read(chainHistoryServiceProvider);
  final indexed = await historyService.searchSignerApprovedByExtrinsicHash(extrinsicHash: hash);
  if (indexed == null) return false;

  removePendingMultisigApproval(ref, pending.id);
  await reconcileIndexedApproval(ref, msig, indexed);
  return true;
}

final multisigApprovalPollingServiceProvider = Provider<MultisigApprovalPollingService>((ref) {
  final service = ExtrinsicIndexerPollingService<PendingMultisigApprovalEvent, MultisigAccount>(
    ref,
    ExtrinsicIndexerPollingConfig(
      logPrefix: '[MultisigApprovalPoller]',
      getId: (pending) => pending.id,
      getExtrinsicHash: (pending) => pending.extrinsicHash,
      isStillPending: (ref, id) => findPendingMultisigApproval(ref, id) != null,
      removePending: removePendingMultisigApproval,
      showTimeoutToast: (ref) {
        ref.read(multisigApprovalToastProvider.notifier).show(MultisigApprovalToastKind.timeout);
      },
      confirmIfIndexed: _confirmIndexedApproval,
    ),
  );
  ref.onDispose(service.dispose);
  return service;
});
