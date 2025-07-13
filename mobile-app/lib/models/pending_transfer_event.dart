// New PendingTransactionEvent class (single type, mirroring TransactionEvent with reversible fields optional)
import 'package:quantus_sdk/quantus_sdk.dart';

enum TransactionState {
  sent,
  includedInBlock,
  includedInHistory,
  failed, // For errors
}

class PendingTransactionEvent extends TransactionEvent {
  TransactionState state;
  final bool isReversible;
  String? txId; // Nullable, set later for reversible
  final ReversibleTransferStatus? status; // Optional, for reversible
  DateTime? scheduledAt; // Optional, null for non-reversible (reversible duration inferred as scheduledAt - timestamp)
  BigInt? fee; // Optional, for transfers
  String? error;

  PendingTransactionEvent({
    required String tempId, // Generate temp ID at creation
    required super.from,
    required super.to,
    required super.amount,
    required super.timestamp,
    this.state = TransactionState.sent,
    this.isReversible = false,
    this.txId,
    this.status = ReversibleTransferStatus.SCHEDULED, // Default for reversible
    this.scheduledAt, // Set optimistically if reversible
    this.fee,
    super.extrinsicHash,
    super.blockNumber = 0, // Initial 0, update on inclusion
    this.error,
  }) : super(id: tempId);

  // Helper to infer reversible duration (0 for non-reversible)
  Duration get reversibleDuration {
    if (!isReversible || scheduledAt == null) return Duration.zero;
    return scheduledAt!.difference(timestamp);
  }

  // Update from submission events (e.g., set extrinsicHash, txId if reversible)
  void updateFromSubmission({String? extrinsicHash, String? txId, int? blockNumber}) {
    this.extrinsicHash = extrinsicHash ?? this.extrinsicHash;
    if (isReversible) {
      this.txId = txId ?? this.txId;
    }
    this.blockNumber = blockNumber ?? this.blockNumber;
  }

  @override
  String toString() {
    return 'PendingTransactionEvent{id: $id, from: $from, to: $to, amount: $amount, timestamp: $timestamp, state: $state, isReversible: $isReversible, txId: $txId, status: $status, scheduledAt: $scheduledAt, fee: $fee, extrinsicHash: $extrinsicHash, blockNumber: $blockNumber, error: $error}';
  }
}
