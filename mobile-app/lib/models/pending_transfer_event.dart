// New PendingTransactionEvent class (single type, mirroring TransactionEvent with reversible fields optional)
import 'package:quantus_sdk/quantus_sdk.dart';

class PendingTransactionEvent extends TransactionEvent {
  @override
  TransactionState transactionState;
  @override
  final bool isReversible;
  String? txId; // Nullable, set later for reversible
  final ReversibleTransferStatus? status; // Optional, for reversible
  DateTime? scheduledAtTime;
  BigInt? fee; // Optional, for transfers
  String? error;

  @override
  DateTime get scheduledAt => scheduledAtTime ?? DateTime.now();
  @override
  bool get isScheduled => isReversible;

  PendingTransactionEvent({
    required String tempId, // Generate temp ID at creation
    required super.from,
    required super.to,
    required super.amount,
    required super.timestamp,
    super.blockHash,
    this.transactionState = TransactionState.created,
    this.isReversible = false,
    this.txId,
    this.status = ReversibleTransferStatus.SCHEDULED, // Default for reversible
    this.scheduledAtTime, // Set optimistically if reversible
    required this.fee,
    super.extrinsicHash,
    super.blockNumber = 0, // Initial 0, update on inclusion
    this.error,
  }) : super(id: tempId);

  @override
  String toString() {
    return 'PendingTransactionEvent{id: $id, from: $from, to: $to, amount: $amount, timestamp: $timestamp, state: $transactionState, isReversible: $isReversible, txId: $txId, status: $status, scheduledAt: $scheduledAt, fee: $fee, extrinsicHash: $extrinsicHash, blockNumber: $blockNumber, error: $error}';
  }
}
