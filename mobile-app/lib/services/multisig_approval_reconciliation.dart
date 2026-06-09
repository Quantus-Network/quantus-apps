import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/services/account_activity_reconciliation.dart';
import 'package:resonance_network_wallet/shared/utils/polling_refresh_scope.dart';

/// Refreshes proposal state and appends the approval to the approver's activity.
Future<void> reconcileIndexedApproval(Ref ref, MultisigAccount msig, MultisigProposalApprovedEvent indexed) async {
  invalidateMultisigProposals(ref, msig);

  await appendConfirmedEventToHistory(
    ref: ref,
    accountId: indexed.approverId,
    event: indexed,
    includeForFilter: (filter) => filter != TransactionFilter.receive,
    isDuplicate: (tx) => tx is MultisigProposalApprovedEvent && tx.isSameApprovalAs(indexed),
  );

  invalidateAccountBalances(ref, {indexed.approverId});
}
