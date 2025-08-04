import 'package:quantus_sdk/quantus_sdk.dart';

class PendingTransactionEvent extends TransactionEvent {
  TransactionState transactionState;
  final bool isReversible;
  String? txId; // Nullable, set later for reversible
  final ReversibleTransferStatus? status; // Optional, for reversible
  DateTime? scheduledAtTime;
  int delaySeconds;
  BigInt? fee; // Optional, for transfers
  String? error;

  DateTime get scheduledAt => scheduledAtTime ?? DateTime.now();
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
    this.status = ReversibleTransferStatus.SCHEDULED,
    this.delaySeconds = 0,
    this.scheduledAtTime, // Set optimistically if reversible
    required this.fee,
    super.extrinsicHash,
    super.blockNumber = 0, // Initial 0, update on inclusion
    this.error,
  }) : super(id: tempId);

  @override
  String toString() {
    return 'PendingTransactionEvent{id: $id, from: $from, to: $to, '
        'amount: $amount, timestamp: $timestamp, state: $transactionState, '
        'isReversible: $isReversible, txId: $txId, status: $status, '
        'scheduledAt: $scheduledAt, delaySeconds: $delaySeconds, fee: $fee, '
        'extrinsicHash: $extrinsicHash, blockNumber: $blockNumber, '
        'error: $error}';
  }

  PendingTransactionEvent copyWith({
    String? id,
    String? from,
    String? to,
    BigInt? amount,
    DateTime? timestamp,
    String? blockHash,
    TransactionState? transactionState,
    int? delaySeconds,
    bool? isReversible,
    String? txId,
    ReversibleTransferStatus? status,
    DateTime? scheduledAtTime,
    BigInt? fee,
    String? extrinsicHash,
    int? blockNumber,
    String? error,
  }) {
    return PendingTransactionEvent(
      tempId: id ?? this.id,
      from: from ?? this.from,
      to: to ?? this.to,
      amount: amount ?? this.amount,
      timestamp: timestamp ?? this.timestamp,
      blockHash: blockHash ?? this.blockHash,
      transactionState: transactionState ?? this.transactionState,
      delaySeconds: delaySeconds ?? this.delaySeconds,
      isReversible: isReversible ?? this.isReversible,
      txId: txId ?? this.txId,
      status: status ?? this.status,
      scheduledAtTime: scheduledAtTime ?? this.scheduledAtTime,
      fee: fee ?? this.fee,
      extrinsicHash: extrinsicHash ?? this.extrinsicHash,
      blockNumber: blockNumber ?? this.blockNumber,
      error: error ?? this.error,
    );
  }
}
