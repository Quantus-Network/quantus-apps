import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/services/account_activity_reconciliation.dart';

/// Refreshes proposal-related state after a proposal is confirmed on-chain.
Future<void> reconcileConfirmedProposal(
  Ref ref,
  MultisigAccount msig, {
  required PendingMultisigProposalEvent pending,
  required MultisigProposal proposal,
}) async {
  ref.invalidate(multisigProposalsProvider(msig));
  ref.invalidate(multisigCurrentBlockProvider);

  final created = MultisigProposalCreatedEvent.fromPending(
    pending,
    proposal: proposal,
    accountEventId: 'ae-ms-proposal-created-${proposal.entityId}',
    timestamp: proposal.createdAt,
    extrinsicHash: pending.extrinsicHash,
  );

  await appendConfirmedEventToHistory(
    ref: ref,
    accountId: pending.proposerId,
    event: created,
    includeForFilter: (filter) => filter != TransactionFilter.receive,
    isDuplicate: (tx) =>
        tx is MultisigProposalCreatedEvent &&
        tx.proposerId == pending.proposerId &&
        tx.multisigAddress == pending.multisigAddress &&
        tx.recipient == pending.recipient &&
        tx.amount == pending.amount,
  );
}
