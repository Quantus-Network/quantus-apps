import 'package:quantus_sdk/src/models/multisig_account.dart';
import 'package:quantus_sdk/src/models/multisig_proposal.dart';
import 'package:quantus_sdk/src/models/transaction_event.dart';

/// A cancellation submitted on-chain but not yet reflected in the indexer.
class PendingMultisigCancellationEvent extends TransactionEvent {
  final String multisigAddress;
  final int proposalId;
  final String proposerId;
  final String recipient;
  final BigInt? fee;

  PendingMultisigCancellationEvent({
    required String tempId,
    required this.multisigAddress,
    required this.proposalId,
    required this.proposerId,
    required this.recipient,
    required super.amount,
    this.fee,
    super.extrinsicHash,
    DateTime? timestamp,
  }) : super(id: tempId, from: proposerId, to: recipient, timestamp: timestamp ?? DateTime.now(), blockNumber: 0);

  DateTime get submittedAt => timestamp;

  /// Estimated network fee for the proposer at submit time.
  BigInt get memberCost => fee ?? BigInt.zero;

  /// Stable key for swapping this pending row with an indexed cancellation event.
  String get activityDedupKey => extrinsicHash != null ? 'hash:$extrinsicHash' : 'pending:$id';

  PendingMultisigCancellationEvent copyWith({String? extrinsicHash, BigInt? fee}) {
    return PendingMultisigCancellationEvent(
      tempId: id,
      multisigAddress: multisigAddress,
      proposalId: proposalId,
      proposerId: proposerId,
      recipient: recipient,
      amount: amount,
      fee: fee ?? this.fee,
      extrinsicHash: extrinsicHash ?? this.extrinsicHash,
      timestamp: timestamp,
    );
  }

  factory PendingMultisigCancellationEvent.create({
    required String multisigAddress,
    required int proposalId,
    required String proposerId,
    required String recipient,
    required BigInt amount,
    BigInt? fee,
  }) {
    return PendingMultisigCancellationEvent(
      tempId: 'pending_cancellation_${DateTime.now().millisecondsSinceEpoch}',
      multisigAddress: multisigAddress,
      proposalId: proposalId,
      proposerId: proposerId,
      recipient: recipient,
      amount: amount,
      fee: fee,
    );
  }

  factory PendingMultisigCancellationEvent.fromProposal({
    required MultisigAccount msig,
    required MultisigProposal proposal,
    required String proposerId,
    BigInt? fee,
  }) {
    return PendingMultisigCancellationEvent.create(
      multisigAddress: msig.accountId,
      proposalId: proposal.id,
      proposerId: proposerId,
      recipient: proposal.recipient,
      amount: proposal.amount,
      fee: fee,
    );
  }

  @override
  String toString() {
    return 'PendingMultisigCancellationEvent{id: $id, multisig: $multisigAddress, '
        'proposalId: $proposalId, proposer: $proposerId}';
  }
}
