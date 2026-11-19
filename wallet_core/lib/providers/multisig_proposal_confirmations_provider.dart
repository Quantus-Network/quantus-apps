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

/// What became of the proposal sent in the transaction of this hash: pending
/// until the wallet has seen it created or has stopped watching for it.
final multisigProposalConfirmationProvider = Provider.family<SendConfirmation, String>(
  (ref, extrinsicHash) =>
      ref.watch(multisigProposalConfirmationsProvider.select((settled) => settled[extrinsicHash])) ??
      SendConfirmation.pending,
);
