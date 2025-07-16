import 'package:quantus_sdk/src/models/reversible_transfer_status.dart';

// Base class for different transaction types
abstract class TransactionEvent {
  final String id;
  final String from;
  final String to;
  final BigInt amount;
  final DateTime timestamp;
  int blockNumber;
  String? extrinsicHash;
  String? blockHash;

  TransactionEvent({
    required this.id,
    required this.from,
    required this.to,
    required this.amount,
    required this.timestamp,
    this.extrinsicHash,
    required this.blockNumber,
    this.blockHash,
  });

  @override
  String toString() {
    return 'Transaction{id: $id, from: $from, to: $to, amount: $amount, timestamp: $timestamp, extrinsicHash: $extrinsicHash, blockNumber: $blockNumber}';
  }
}

// Data class to represent a single transfer
class TransferEvent extends TransactionEvent {
  final BigInt fee;

  TransferEvent({
    required super.id,
    required super.from,
    required super.to,
    required super.amount,
    required super.timestamp,
    required this.fee,
    super.extrinsicHash,
    required super.blockNumber,
    required super.blockHash,
  });

  factory TransferEvent.fromJson(Map<String, dynamic> json) {
    final block = json['block'] as Map<String, dynamic>?;
    final blockHeight = block?['height'] as int? ?? 0;
    final blockHash = block?['hash'] as String? ?? '';
    return TransferEvent(
      id: json['id'] as String,
      from: json['from']?['id'] as String? ?? '',
      to: json['to']?['id'] as String? ?? '',
      amount: BigInt.parse(json['amount'] as String),
      timestamp: DateTime.parse(json['timestamp'] as String),
      fee: json['fee'] != null ? BigInt.parse(json['fee'] as String) : BigInt.zero,
      extrinsicHash: json['extrinsicHash'] as String?,
      blockNumber: blockHeight,
      blockHash: blockHash,
    );
  }

  @override
  String toString() {
    return 'Transfer{id: $id, from: $from, to: $to, amount: $amount, timestamp: $timestamp, fee: $fee, extrinsicHash: $extrinsicHash, blockNumber: $blockNumber}';
  }
}

class ReversibleTransferEvent extends TransactionEvent {
  final String txId;
  final ReversibleTransferStatus status;
  final DateTime scheduledAt;
  bool get isReversible => true;
  bool get isScheduled => status == ReversibleTransferStatus.SCHEDULED;

  ReversibleTransferEvent({
    required super.id,
    required super.from,
    required super.to,
    required super.amount,
    required super.timestamp,
    required this.txId,
    required this.status,
    required this.scheduledAt,
    super.extrinsicHash,
    required super.blockNumber,
    required super.blockHash,
  });

  factory ReversibleTransferEvent.fromJson(Map<String, dynamic> json) {
    final block = json['block'] as Map<String, dynamic>;
    final blockHeight = block['height'] as int;
    final blockHash = block['hash'] as String? ?? '';
    return ReversibleTransferEvent(
      id: json['id'] as String,
      from: json['from']?['id'] as String? ?? '',
      to: json['to']?['id'] as String? ?? '',
      amount: BigInt.parse(json['amount'] as String),
      timestamp: DateTime.parse(json['timestamp'] as String),
      txId: json['txId'] as String,
      status: ReversibleTransferStatus.values.byName(json['status'] as String),
      scheduledAt: DateTime.parse(json['scheduledAt'] as String),
      extrinsicHash: json['extrinsicHash'] as String?,
      blockNumber: blockHeight,
      blockHash: blockHash,
    );
  }

  @override
  String toString() {
    return 'ReversibleTransfer{id: $id, from: $from, to: $to, amount: $amount, timestamp: $timestamp, txId: $txId, status: $status, scheduledAt: $scheduledAt, extrinsicHash: $extrinsicHash, blockNumber: $blockNumber}';
  }
}
