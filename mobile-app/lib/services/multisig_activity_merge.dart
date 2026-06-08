import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/combined_transactions_list.dart';
import 'package:resonance_network_wallet/providers/pending_multisig_proposals_provider.dart';
import 'package:resonance_network_wallet/services/transaction_service.dart';

/// Merges past proposals with transfers, newest first.
///
/// Outgoing multisig transfers are omitted because executed proposals
/// already represent them.
List<TransactionEvent> mergeMultisigActivity({
  required TransactionService txService,
  required CombinedTransactionsList data,
  required List<MultisigProposal> pastProposals,
  required String multisigAccountId,
}) {
  final transfers = txService.combineAndDeduplicateTransactions(
    pendingCancellationIds: data.pendingCancellationIds,
    pendingTransactions: data.pendingTransactions,
    pendingMultisigCreations: data.pendingMultisigCreations,
    pendingMultisigProposals: pendingProposalsExcludingMultisig(data.pendingMultisigProposals, multisigAccountId),
    scheduledReversibleTransfers: data.scheduledReversibleTransfers,
    otherTransfers: data.otherTransfers,
  );

  final terminalProposals = pastProposals.map((p) => MultisigProposalEvent(proposal: p)).toList();
  final filteredTransfers = transfers.where((t) {
    return t is! TransferEvent || t.from != multisigAccountId;
  });

  final merged = <TransactionEvent>[...terminalProposals, ...filteredTransfers]
    ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  return merged;
}
