import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/services/account_activity_reconciliation.dart';
import 'package:wallet_core/utils/polling_refresh_scope.dart';

/// Appends the approval to the approver's activity. The proposals were read again
/// before it, by `rereadMultisigProposals`.
Future<void> reconcileIndexedApproval(Ref ref, MultisigAccount msig, MultisigProposalApprovedEvent indexed) async {
  await appendConfirmedEventToHistory(
    ref: ref,
    accountId: indexed.approverId,
    event: indexed,
    includeForFilter: (filter) => filter != TransactionFilter.receive,
    isDuplicate: (tx) => tx is MultisigProposalApprovedEvent && tx.isSameApprovalAs(indexed),
  );

  invalidateAccountBalances(ref, {indexed.approverId});
}
