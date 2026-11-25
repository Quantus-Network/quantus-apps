import 'package:quantus_sdk/src/models/multisig_account.dart';
import 'package:quantus_sdk/src/models/multisig_proposal.dart';
import 'package:quantus_sdk/src/models/transaction_event.dart';

/// An approval submitted on-chain but not yet reflected in the indexer, shown
/// in the approver's activity as the step under way.
///
/// [amount] and [recipient] are the proposal's (context), as on
/// `MultisigProposalApprovedEvent`. [fee] is the network fee the approver was
/// quoted at submit time.
class PendingMultisigApprovalEvent extends TransactionEvent {
  final String multisigAddress;
  final int proposalId;
  final String approverId;
  final String recipient;
  final BigInt? fee;

  PendingMultisigApprovalEvent({
    required super.id,
    required this.multisigAddress,
    required this.proposalId,
    required this.approverId,
    required this.recipient,
    required super.amount,
    this.fee,
    super.extrinsicHash,
    required DateTime submittedAt,
  }) : super(from: approverId, to: recipient, timestamp: submittedAt, blockNumber: 0);

  DateTime get submittedAt => timestamp;

  /// Estimated network fee for the approver at submit time.
  BigInt get memberCost => fee ?? BigInt.zero;

  /// Stable key for swapping this pending row with an indexed approval event.
  String get activityDedupKey => extrinsicHash != null ? 'hash:$extrinsicHash' : 'pending:$id';

  PendingMultisigApprovalEvent copyWith({String? extrinsicHash}) {
    return PendingMultisigApprovalEvent(
      id: id,
      multisigAddress: multisigAddress,
      proposalId: proposalId,
      approverId: approverId,
      recipient: recipient,
      amount: amount,
      fee: fee,
      extrinsicHash: extrinsicHash ?? this.extrinsicHash,
      submittedAt: submittedAt,
    );
  }

  factory PendingMultisigApprovalEvent.create({
    required String multisigAddress,
    required int proposalId,
    required String approverId,
    required String recipient,
    required BigInt amount,
    BigInt? fee,
  }) {
    return PendingMultisigApprovalEvent(
      id: 'pending_approval_${DateTime.now().millisecondsSinceEpoch}',
      multisigAddress: multisigAddress,
      proposalId: proposalId,
      approverId: approverId,
      recipient: recipient,
      amount: amount,
      fee: fee,
      submittedAt: DateTime.now(),
    );
  }

  factory PendingMultisigApprovalEvent.fromProposal({
    required MultisigAccount msig,
    required MultisigProposal proposal,
    required String approverId,
    BigInt? fee,
  }) {
    return PendingMultisigApprovalEvent.create(
      multisigAddress: msig.accountId,
      proposalId: proposal.id,
      approverId: approverId,
      recipient: proposal.recipient,
      amount: proposal.amount,
      fee: fee,
    );
  }

  @override
  String toString() {
    return 'PendingMultisigApprovalEvent{id: $id, multisig: $multisigAddress, '
        'proposalId: $proposalId, approver: $approverId}';
  }
}
