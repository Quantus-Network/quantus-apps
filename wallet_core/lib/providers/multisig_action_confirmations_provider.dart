import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What became of an approval, execution or cancellation this wallet sent.
enum MultisigActionConfirmation {
  /// Sent, and not yet seen to have done what it was sent to do.
  pending,

  /// Seen on the chain, done.
  confirmed,

  /// The proposal was executed, but not by this transaction: another signer
  /// most likely executed it first, and this one failed at the cost of its fee.
  executedByAnother,

  /// Not seen within the time the wallet watches for it. It may have been
  /// dropped or have failed, or only be late.
  unconfirmed,
}

/// What became of the approvals, executions and cancellations this wallet
/// sent, by the hash of the transaction each was sent in. One that is still
/// watched for is not here.
class MultisigActionConfirmationsNotifier extends Notifier<Map<String, MultisigActionConfirmation>> {
  @override
  Map<String, MultisigActionConfirmation> build() => const {};

  /// The action sent in [extrinsicHash] turned out as [outcome].
  void settle(String extrinsicHash, MultisigActionConfirmation outcome) => state = {...state, extrinsicHash: outcome};
}

final multisigActionConfirmationsProvider =
    NotifierProvider<MultisigActionConfirmationsNotifier, Map<String, MultisigActionConfirmation>>(
      MultisigActionConfirmationsNotifier.new,
    );

/// What became of the action sent in the transaction of this hash: pending
/// until the wallet has seen it done or has stopped watching for it.
final multisigActionConfirmationProvider = Provider.family<MultisigActionConfirmation, String>(
  (ref, extrinsicHash) =>
      ref.watch(multisigActionConfirmationsProvider.select((settled) => settled[extrinsicHash])) ??
      MultisigActionConfirmation.pending,
);
