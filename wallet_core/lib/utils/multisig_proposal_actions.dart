import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/pending_multisig_cancellations_provider.dart';
import 'package:wallet_core/providers/pending_multisig_executions_provider.dart';
import 'package:wallet_core/utils/multisig_local_signers.dart';

/// The action a proposal still open to this wallet leads with.
enum ProposalPrimaryAction { approve, execute }

/// Whether an action on a proposal can be taken now.
enum ProposalActionState {
  offered,

  /// This device has sent it and the wallet is still watching for it.
  inFlight,
  unavailable,
}

/// Why a proposal's actions are as they are, when that needs saying.
enum ProposalActionNote {
  cancelled,
  executed,
  cancelling,
  executing,

  /// An approval from this device is under way and none of its other signers
  /// can still approve.
  approving,

  /// Past its expiry block: nothing can be done with it any more.
  expired,

  /// None of the multisig's signers is in this wallet.
  noSignerHere,

  /// Every signer this wallet holds has approved.
  alreadySigned,

  /// An approval from this device is under way: Cancel waits for it, while
  /// another signer here can still approve.
  cancelWaitsForApproval,
}

/// What this wallet can do with a proposal.
sealed class ProposalActions {
  const ProposalActions();

  ProposalActionNote? get note;
}

/// Nothing is left to do with the proposal here: it is over, cannot be read,
/// or every signer this wallet holds has approved and it is not ready.
final class ProposalOver extends ProposalActions {
  @override
  final ProposalActionNote? note;

  const ProposalOver(this.note);
}

/// The proposal is open to this wallet.
final class ProposalOpen extends ProposalActions {
  final ProposalPrimaryAction primary;
  final ProposalActionState primaryState;

  /// The signers this wallet holds that can approve it now.
  final List<Account> eligibleApprovers;

  /// The signers this wallet holds that can execute it, once it is ready:
  /// any signer may, the multisig's own member first. Empty before then.
  final List<Account> executors;

  /// Null when Cancel is not this wallet's to offer: only the proposal's
  /// proposer cancels, so it is offered when that is a signer this wallet holds.
  final ProposalActionState? cancel;

  /// The signer that cancels, the proposer, when this wallet holds it; null
  /// exactly when [cancel] is.
  final Account? canceller;

  @override
  final ProposalActionNote? note;

  const ProposalOpen({
    required this.primary,
    required this.primaryState,
    required this.eligibleApprovers,
    required this.executors,
    required this.cancel,
    required this.canceller,
    required this.note,
  });
}

/// What this wallet, holding [accounts], can do with [proposal] of [msig] at
/// [currentBlock] (null while it is not known), given the actions this device
/// has under way.
///
/// An action from this device under way blocks the others, otherwise the
/// extrinsics race on-chain and one fails with a wasted fee.
ProposalActions proposalActionsOf({
  required MultisigAccount msig,
  required MultisigProposal proposal,
  required List<Account> accounts,
  required int? currentBlock,
  required List<PendingMultisigApprovalEvent> pendingApprovals,
  required List<PendingMultisigExecutionEvent> pendingExecutions,
  required List<PendingMultisigCancellationEvent> pendingCancellations,
}) {
  final localSigners = localSignersForMultisig(msig, accounts);
  final pendingApproverIds = pendingApproverIdsForProposal(
    pendingApprovals,
    msig.accountId,
    proposal.id,
    localSigners.map((a) => a.accountId),
  );
  final eligibleApprovers = eligibleApproversForProposal(
    msig,
    proposal,
    localSigners,
    pendingApproverIds: pendingApproverIds,
  );
  // Any signer here executes it, whichever this device sent it from.
  final pendingExecution = localSigners
      .map((a) => findPendingExecutionForProposal(pendingExecutions, msig.accountId, proposal.id, a.accountId))
      .nonNulls
      .firstOrNull;
  // Only the proposer cancels: one under way from this device is its.
  final canceller = localSigners.where((a) => a.accountId == proposal.proposer).firstOrNull;
  final pendingCancellation = findPendingCancellationForProposal(
    pendingCancellations,
    msig.accountId,
    proposal.id,
    proposal.proposer,
  );
  // Another local member may still need to sign even if myMemberAccountId
  // already has.
  final allLocalApproved = localSigners.isNotEmpty && localSigners.every((a) => proposal.didApprove(a.accountId));
  final hasPendingApproval = pendingApproverIds.isNotEmpty;
  final hasLocalSigner = localSigners.isNotEmpty;
  final isActionable = currentBlock != null && proposal.isActionable(currentBlock);

  final note = _noteOf(
    proposal,
    allLocalApproved: allLocalApproved,
    hasEligibleApprover: eligibleApprovers.isNotEmpty,
    hasPendingApproval: hasPendingApproval,
    isExecuting: pendingExecution != null,
    isCancelling: pendingCancellation != null,
    hasLocalSigner: hasLocalSigner,
    isCancellable: canceller != null,
    currentBlock: currentBlock,
  );

  if (proposal.hasUndecodableCall || proposal.isTerminal || (allLocalApproved && !proposal.isReadyToExecute)) {
    return ProposalOver(note);
  }

  final ProposalActionState primaryState;
  if (proposal.isReadyToExecute) {
    final canExecute =
        isActionable &&
        pendingExecution == null &&
        !hasPendingApproval &&
        pendingCancellation == null &&
        hasLocalSigner;
    primaryState = pendingExecution != null
        ? ProposalActionState.inFlight
        : (canExecute ? ProposalActionState.offered : ProposalActionState.unavailable);
  } else {
    final canApprove = isActionable && eligibleApprovers.isNotEmpty && pendingCancellation == null;
    // In flight only when nothing else this wallet holds can still sign.
    primaryState = canApprove
        ? ProposalActionState.offered
        : (hasPendingApproval ? ProposalActionState.inFlight : ProposalActionState.unavailable);
  }

  ProposalActionState? cancel;
  if (canceller != null) {
    final canCancel = isActionable && pendingCancellation == null && !hasPendingApproval && pendingExecution == null;
    cancel = pendingCancellation != null
        ? ProposalActionState.inFlight
        : (canCancel ? ProposalActionState.offered : ProposalActionState.unavailable);
  }

  return ProposalOpen(
    primary: proposal.isReadyToExecute ? ProposalPrimaryAction.execute : ProposalPrimaryAction.approve,
    primaryState: primaryState,
    eligibleApprovers: eligibleApprovers,
    executors: proposal.isReadyToExecute
        ? [
            ...localSigners.where((a) => a.accountId == msig.myMemberAccountId),
            ...localSigners.where((a) => a.accountId != msig.myMemberAccountId),
          ]
        : const [],
    cancel: cancel,
    canceller: canceller,
    note: note,
  );
}

ProposalActionNote? _noteOf(
  MultisigProposal proposal, {
  required bool allLocalApproved,
  required bool hasEligibleApprover,
  required bool hasPendingApproval,
  required bool isExecuting,
  required bool isCancelling,
  required bool hasLocalSigner,
  required bool isCancellable,
  required int? currentBlock,
}) {
  if (proposal.hasUndecodableCall) return null;
  if (proposal.status == MultisigProposalStatus.cancelled) return ProposalActionNote.cancelled;
  if (proposal.status == MultisigProposalStatus.executed) return ProposalActionNote.executed;

  if (isCancelling) return ProposalActionNote.cancelling;
  if (isExecuting) return ProposalActionNote.executing;
  if (hasPendingApproval && !hasEligibleApprover) return ProposalActionNote.approving;

  if (currentBlock != null && proposal.expired(currentBlock)) return ProposalActionNote.expired;
  if (!hasLocalSigner) return ProposalActionNote.noSignerHere;
  if (proposal.isReadyToExecute) return null;
  if (allLocalApproved) return ProposalActionNote.alreadySigned;
  // While the chain's block is not known the actions wait, without a word.
  if (currentBlock == null) return null;
  if (hasPendingApproval && isCancellable) return ProposalActionNote.cancelWaitsForApproval;
  return null;
}
