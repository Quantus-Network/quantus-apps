import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/services/account_activity_reconciliation.dart';

/// Refreshes proposal-related state after indexer confirms proposal creation.
Future<void> reconcileIndexedProposalCreation(
  Ref ref,
  MultisigAccount msig,
  MultisigProposalCreatedEvent indexed,
) async {
  invalidateMultisigProposals(ref, msig);

  await appendConfirmedEventToHistory(
    ref: ref,
    accountId: indexed.proposerId,
    event: indexed,
    includeForFilter: (filter) => filter != TransactionFilter.receive,
    isDuplicate: (tx) => tx is MultisigProposalCreatedEvent && tx.isSameCreationAs(indexed),
  );
}
