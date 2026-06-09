import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/multisig_execution_toast_provider.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/providers/pending_multisig_executions_provider.dart';
import 'package:resonance_network_wallet/services/extrinsic_indexer_polling_service.dart';
import 'package:resonance_network_wallet/services/multisig_execution_reconciliation.dart';

typedef MultisigExecutionPollingService = ExtrinsicIndexerPollingService<PendingMultisigExecutionEvent, MultisigAccount>;

Future<bool> _confirmIndexedExecution(Ref ref, MultisigAccount msig, PendingMultisigExecutionEvent pending) async {
  final multisigService = ref.read(multisigServiceProvider);
  final proposal = await multisigService.getProposal(msig, pending.proposalId);
  if (proposal == null || proposal.status != MultisigProposalStatus.executed) return false;

  removePendingMultisigExecution(ref, pending.id);
  await reconcileIndexedExecution(ref, msig, pending);
  return true;
}

/// When the indexer lags but the proposal already shows as executed, clear
/// pending state and refresh without a timeout toast.
Future<bool> _tryResolveExecutionTimeout(Ref ref, MultisigAccount msig, PendingMultisigExecutionEvent pending) async {
  final multisigService = ref.read(multisigServiceProvider);
  final proposal = await multisigService.getProposal(msig, pending.proposalId);
  if (proposal == null || proposal.status != MultisigProposalStatus.executed) {
    return false;
  }

  removePendingMultisigExecution(ref, pending.id);
  await reconcileIndexedExecution(ref, msig, pending);
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
        ref.read(multisigExecutionToastProvider.notifier).show(MultisigExecutionToastKind.timeout);
      },
      confirmIfIndexed: _confirmIndexedExecution,
      tryResolveTimeout: _tryResolveExecutionTimeout,
    ),
  );
  ref.onDispose(service.dispose);
  return service;
});
