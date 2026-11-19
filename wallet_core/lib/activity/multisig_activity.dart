import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/models/combined_transactions_list.dart';
import 'package:wallet_core/providers/pending_multisig_cancellations_provider.dart';
import 'package:wallet_core/providers/pending_multisig_executions_provider.dart';
import 'package:wallet_core/providers/pending_multisig_proposals_provider.dart';
import 'package:wallet_core/services/transaction_service.dart';
import 'package:wallet_core/utils/multisig_local_signers.dart';

/// A multisig's open proposals, in the order they are listed: the ones this
/// device is still proposing, then the open ones, last changed first.
({List<PendingMultisigProposalEvent> proposing, List<MultisigProposal> open}) openProposalsOf(
  MultisigAccount msig, {
  required List<PendingMultisigProposalEvent> proposing,
  required List<MultisigProposal> open,
}) => (
  proposing: pendingProposalsForMultisig(proposing, msig.accountId),
  open: [...open]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
);

/// What a proposal waits for, as this device sees it.
enum ProposalWait {
  /// An approval from this device is on its way to the chain, and so is one
  /// from every other signer here yet to approve.
  approving,

  /// Its execution, from this device, is on its way to the chain.
  executing,

  /// Its cancellation, from this device, is on its way to the chain.
  cancelling,

  /// Open, and every signer here has approved it.
  signed,

  /// Open, and a signer here has yet to approve it.
  proposed,

  /// No longer open.
  closed,
}

/// What [proposal] waits for, with [localSignerIds] the signers of its
/// multisig on this device and the steps this device has on their way:
/// [approvals], [executions] and [cancellations]. A step on its way is named
/// before where the proposal stands: an execution first, then an approval,
/// then a cancellation.
ProposalWait proposalWaitOf(
  MultisigProposal proposal, {
  required List<String> localSignerIds,
  required List<PendingMultisigApprovalEvent> approvals,
  required List<PendingMultisigExecutionEvent> executions,
  required List<PendingMultisigCancellationEvent> cancellations,
}) {
  final multisig = proposal.multisigAddress;
  final approving = pendingApproverIdsForProposal(approvals, multisig, proposal.id, localSignerIds);
  final yetToSign = localSignerIds.where((id) => !proposal.didApprove(id));
  final isApproving = yetToSign.isNotEmpty && yetToSign.every(approving.contains);
  final isExecuting = localSignerIds.any(
    (id) => findPendingExecutionForProposal(executions, multisig, proposal.id, id) != null,
  );
  final isCancelling = localSignerIds.any(
    (id) => findPendingCancellationForProposal(cancellations, multisig, proposal.id, id) != null,
  );

  if (isExecuting) return ProposalWait.executing;
  if (isApproving) return ProposalWait.approving;
  if (isCancelling) return ProposalWait.cancelling;
  if (!proposal.isOpen) return ProposalWait.closed;
  final hasEverySignature = localSignerIds.isNotEmpty && localSignerIds.every(proposal.didApprove);
  return hasEverySignature ? ProposalWait.signed : ProposalWait.proposed;
}

/// The signers of [msig] on this device, among the wallet's [accounts]. While
/// none has loaded, the member it was stored with.
List<String> localSignerIdsOf(MultisigAccount msig, List<Account> accounts) {
  final local = localSignersForMultisig(msig, accounts).map((account) => account.accountId).toList();
  return local.isEmpty ? [msig.myMemberAccountId] : local;
}

/// What [msig] has done, newest first: its [pastProposals], and its transfers
/// from [data] as [service] combines them. Its own proposal steps on their way
/// are left out, being among its open proposals, and so are the transfers it
/// sent, which its executed proposals stand for.
List<TransactionEvent> multisigActivityOf(
  TransactionService service,
  CombinedTransactionsList data,
  List<MultisigProposal> pastProposals,
  MultisigAccount msig,
) {
  final multisig = msig.accountId;
  final transfers = service.combineAndDeduplicateTransactions(
    pendingCancellationIds: data.pendingCancellationIds,
    pendingTransactions: data.pendingTransactions,
    pendingMultisigCreations: data.pendingMultisigCreations,
    pendingMultisigProposals: pendingProposalsExcludingMultisig(data.pendingMultisigProposals, multisig),
    pendingMultisigExecutions: pendingExecutionsExcludingMultisig(data.pendingMultisigExecutions, multisig),
    pendingMultisigCancellations: pendingCancellationsExcludingMultisig(data.pendingMultisigCancellations, multisig),
    scheduledReversibleTransfers: data.scheduledReversibleTransfers,
    otherTransfers: data.otherTransfers,
  );
  return [
    for (final proposal in pastProposals) MultisigProposalEvent(proposal: proposal),
    for (final transfer in transfers)
      if (transfer is! TransferEvent || transfer.from != multisig) transfer,
  ]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
}
