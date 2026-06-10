import 'package:flutter/foundation.dart';

/// A cancellation submitted on-chain but not yet reflected in the indexer.
@immutable
class PendingMultisigCancellationEvent {
  final String id;
  final String multisigAddress;
  final int proposalId;
  final String proposerId;
  final String? extrinsicHash;
  final DateTime submittedAt;

  const PendingMultisigCancellationEvent({
    required this.id,
    required this.multisigAddress,
    required this.proposalId,
    required this.proposerId,
    this.extrinsicHash,
    required this.submittedAt,
  });

  PendingMultisigCancellationEvent copyWith({String? extrinsicHash}) {
    return PendingMultisigCancellationEvent(
      id: id,
      multisigAddress: multisigAddress,
      proposalId: proposalId,
      proposerId: proposerId,
      extrinsicHash: extrinsicHash ?? this.extrinsicHash,
      submittedAt: submittedAt,
    );
  }

  factory PendingMultisigCancellationEvent.create({
    required String multisigAddress,
    required int proposalId,
    required String proposerId,
  }) {
    return PendingMultisigCancellationEvent(
      id: 'pending_cancellation_${DateTime.now().millisecondsSinceEpoch}',
      multisigAddress: multisigAddress,
      proposalId: proposalId,
      proposerId: proposerId,
      submittedAt: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'PendingMultisigCancellationEvent{id: $id, multisig: $multisigAddress, '
        'proposalId: $proposalId, proposer: $proposerId}';
  }
}
