import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wallet_core/send/send_strategy.dart';

/// What became of the proposals this wallet broadcast, by the hash of the
/// transaction each was sent in: confirmed once the indexer has the proposal
/// it created, unconfirmed once the wallet stops watching for it. One that is
/// still watched for is not here.
class MultisigProposalConfirmationsNotifier extends Notifier<Map<String, SendConfirmation>> {
  @override
  Map<String, SendConfirmation> build() => const {};

  /// The proposal sent in [extrinsicHash] turned out as [outcome].
  void settle(String extrinsicHash, SendConfirmation outcome) => state = {...state, extrinsicHash: outcome};
}

final multisigProposalConfirmationsProvider =
    NotifierProvider<MultisigProposalConfirmationsNotifier, Map<String, SendConfirmation>>(
      MultisigProposalConfirmationsNotifier.new,
    );

/// The proposals this wallet broadcast that the indexer has shown created:
/// the indexer's id of each (`MultisigProposal.entityId`), by the hash of the
/// transaction it was sent in.
class MultisigCreatedProposalsNotifier extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() => const {};

  /// The proposal sent in [extrinsicHash] was created as [entityId].
  void record(String extrinsicHash, String entityId) => state = {...state, extrinsicHash: entityId};
}

final multisigCreatedProposalsProvider = NotifierProvider<MultisigCreatedProposalsNotifier, Map<String, String>>(
  MultisigCreatedProposalsNotifier.new,
);

/// The indexer's id of the proposal sent in the transaction of this hash,
/// once it has shown it created; null before, and for one it never showed.
final multisigCreatedProposalIdProvider = Provider.family<String?, String>(
  (ref, extrinsicHash) => ref.watch(multisigCreatedProposalsProvider.select((created) => created[extrinsicHash])),
);

/// What became of the proposal sent in the transaction of this hash: pending
/// until the wallet has seen it created or has stopped watching for it.
final multisigProposalConfirmationProvider = Provider.family<SendConfirmation, String>(
  (ref, extrinsicHash) =>
      ref.watch(multisigProposalConfirmationsProvider.select((settled) => settled[extrinsicHash])) ??
      SendConfirmation.pending,
);
