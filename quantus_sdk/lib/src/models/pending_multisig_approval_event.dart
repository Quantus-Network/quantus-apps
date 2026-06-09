import 'package:flutter/foundation.dart';

/// An approval submitted on-chain but not yet reflected in the indexer.
@immutable
class PendingMultisigApprovalEvent {
  final String id;
  final String multisigAddress;
  final int proposalId;
  final String approverId;
  final String? extrinsicHash;
  final DateTime submittedAt;

  const PendingMultisigApprovalEvent({
    required this.id,
    required this.multisigAddress,
    required this.proposalId,
    required this.approverId,
    this.extrinsicHash,
    required this.submittedAt,
  });

  PendingMultisigApprovalEvent copyWith({String? extrinsicHash}) {
    return PendingMultisigApprovalEvent(
      id: id,
      multisigAddress: multisigAddress,
      proposalId: proposalId,
      approverId: approverId,
      extrinsicHash: extrinsicHash ?? this.extrinsicHash,
      submittedAt: submittedAt,
    );
  }

  factory PendingMultisigApprovalEvent.create({
    required String multisigAddress,
    required int proposalId,
    required String approverId,
  }) {
    return PendingMultisigApprovalEvent(
      id: 'pending_approval_${DateTime.now().millisecondsSinceEpoch}',
      multisigAddress: multisigAddress,
      proposalId: proposalId,
      approverId: approverId,
      submittedAt: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'PendingMultisigApprovalEvent{id: $id, multisig: $multisigAddress, '
        'proposalId: $proposalId, approver: $approverId}';
  }
}
