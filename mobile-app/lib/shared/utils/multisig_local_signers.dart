import 'package:quantus_sdk/quantus_sdk.dart';

/// Local wallet accounts that are members of [msig].
///
/// A single device can hold more than one signer of the same multisig. Callers
/// should use this (rather than only [MultisigAccount.myMemberAccountId]) when
/// deciding who can approve or when rendering "you" state.
List<Account> localSignersForMultisig(MultisigAccount msig, List<Account> accounts) {
  final signerIds = msig.signers.toSet();
  return accounts.where((a) => signerIds.contains(a.accountId)).toList();
}

/// Local signers that still need to approve [proposal].
///
/// [pendingApproverIds] are local accounts that already have an in-flight
/// approval extrinsic for this proposal and should not be offered again.
List<Account> eligibleApproversForProposal(
  MultisigAccount msig,
  MultisigProposal proposal,
  List<Account> accounts, {
  Set<String> pendingApproverIds = const {},
}) {
  return localSignersForMultisig(msig, accounts)
      .where((a) => !proposal.didApprove(a.accountId) && !pendingApproverIds.contains(a.accountId))
      .toList();
}

/// Approver ids among [localSignerIds] that already have a pending approval
/// for the given multisig proposal.
Set<String> pendingApproverIdsForProposal(
  List<PendingMultisigApprovalEvent> pendingApprovals,
  String multisigAddress,
  int proposalId,
  Iterable<String> localSignerIds,
) {
  final local = localSignerIds.toSet();
  if (local.isEmpty) return const {};

  final result = <String>{};
  for (final event in pendingApprovals) {
    if (event.multisigAddress == multisigAddress &&
        event.proposalId == proposalId &&
        local.contains(event.approverId)) {
      result.add(event.approverId);
    }
  }
  return result;
}
