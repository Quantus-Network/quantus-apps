import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/combined_transactions_list.dart';
import 'package:resonance_network_wallet/providers/pending_multisig_proposals_provider.dart';
import 'package:resonance_network_wallet/services/transaction_service.dart';

/// Multisig account transfers for the activity feed, newest first.
///
/// Outgoing multisig transfers are omitted because executed proposals
/// already represent them in the Past Proposals feed.
List<TransactionEvent> multisigActivityTransfers({
  required TransactionService txService,
  required CombinedTransactionsList data,
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

  final filtered = transfers.where((t) {
    return t is! TransferEvent || t.from != multisigAccountId;
  });

  return filtered.toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));
}
