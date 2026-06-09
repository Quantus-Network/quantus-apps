import 'package:quantus_sdk/src/models/multisig_account.dart';
import 'package:quantus_sdk/src/models/multisig_proposal.dart';
import 'package:quantus_sdk/src/models/transaction_event.dart';

/// An execution submitted on-chain but not yet reflected in the indexer.
class PendingMultisigExecutionEvent extends TransactionEvent {
  final String multisigAddress;
  final int proposalId;
  final String executorId;
  final String recipient;
  final BigInt? fee;

  PendingMultisigExecutionEvent({
    required String tempId,
    required this.multisigAddress,
    required this.proposalId,
    required this.executorId,
    required this.recipient,
    required super.amount,
    this.fee,
    super.extrinsicHash,
    DateTime? timestamp,
  }) : super(id: tempId, from: executorId, to: recipient, timestamp: timestamp ?? DateTime.now(), blockNumber: 0);

  DateTime get submittedAt => timestamp;

  /// Estimated network fee for the executor at submit time.
  BigInt get memberCost => fee ?? BigInt.zero;

  /// Stable key for swapping this pending row with an indexed execution event.
  String get activityDedupKey => extrinsicHash != null ? 'hash:$extrinsicHash' : 'pending:$id';

  PendingMultisigExecutionEvent copyWith({String? extrinsicHash, BigInt? fee}) {
    return PendingMultisigExecutionEvent(
      tempId: id,
      multisigAddress: multisigAddress,
      proposalId: proposalId,
      executorId: executorId,
      recipient: recipient,
      amount: amount,
      fee: fee ?? this.fee,
      extrinsicHash: extrinsicHash ?? this.extrinsicHash,
      timestamp: timestamp,
    );
  }

  factory PendingMultisigExecutionEvent.create({
    required String multisigAddress,
    required int proposalId,
    required String executorId,
    required String recipient,
    required BigInt amount,
    BigInt? fee,
  }) {
    return PendingMultisigExecutionEvent(
      tempId: 'pending_execution_${DateTime.now().millisecondsSinceEpoch}',
      multisigAddress: multisigAddress,
      proposalId: proposalId,
      executorId: executorId,
      recipient: recipient,
      amount: amount,
      fee: fee,
    );
  }

  factory PendingMultisigExecutionEvent.fromProposal({
    required MultisigAccount msig,
    required MultisigProposal proposal,
    required String executorId,
    BigInt? fee,
  }) {
    return PendingMultisigExecutionEvent.create(
      multisigAddress: msig.accountId,
      proposalId: proposal.id,
      executorId: executorId,
      recipient: proposal.recipient,
      amount: proposal.amount,
      fee: fee,
    );
  }

  @override
  String toString() {
    return 'PendingMultisigExecutionEvent{id: $id, multisig: $multisigAddress, '
        'proposalId: $proposalId, executor: $executorId}';
  }
}
