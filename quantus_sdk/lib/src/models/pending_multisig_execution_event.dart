import 'package:flutter/foundation.dart';

/// An execution submitted on-chain but not yet reflected in the indexer.
@immutable
class PendingMultisigExecutionEvent {
  final String id;
  final String multisigAddress;
  final int proposalId;
  final String executorId;
  final String? extrinsicHash;
  final DateTime submittedAt;

  const PendingMultisigExecutionEvent({
    required this.id,
    required this.multisigAddress,
    required this.proposalId,
    required this.executorId,
    this.extrinsicHash,
    required this.submittedAt,
  });

  PendingMultisigExecutionEvent copyWith({String? extrinsicHash}) {
    return PendingMultisigExecutionEvent(
      id: id,
      multisigAddress: multisigAddress,
      proposalId: proposalId,
      executorId: executorId,
      extrinsicHash: extrinsicHash ?? this.extrinsicHash,
      submittedAt: submittedAt,
    );
  }

  factory PendingMultisigExecutionEvent.create({
    required String multisigAddress,
    required int proposalId,
    required String executorId,
  }) {
    return PendingMultisigExecutionEvent(
      id: 'pending_execution_${DateTime.now().millisecondsSinceEpoch}',
      multisigAddress: multisigAddress,
      proposalId: proposalId,
      executorId: executorId,
      submittedAt: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'PendingMultisigExecutionEvent{id: $id, multisig: $multisigAddress, '
        'proposalId: $proposalId, executor: $executorId}';
  }
}
