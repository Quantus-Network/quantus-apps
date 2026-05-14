import 'package:quantus_sdk/quantus_sdk.dart';

import 'json_dynamic_parse.dart';

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
    final block = jsonMapOrNull(json['block']);
    final blockHeight = blockHeightFromJsonMap(block);
    final blockHash = blockHashFromJsonMap(block);
    return TransferEvent(
      id: stringFromJson(json['id']),
      from: nestedAccountId(json['sender'] ?? json['from']),
      to: nestedAccountId(json['receiver'] ?? json['to']),
      amount: bigIntFromJson(json['amount']),
      timestamp: dateTimeFromJson(json['timestamp']),
      fee: json['fee'] != null ? bigIntFromJson(json['fee']) : BigInt.zero,
      extrinsicHash: optionalExtrinsicHash(json),
      blockNumber: blockHeight,
      blockHash: blockHash,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': EventType.TRANSFER.name,
      'from': {'id': from},
      'to': {'id': to},
      'amount': amount.toString(),
      'timestamp': timestamp.toIso8601String(),
      'fee': fee.toString(),
      'extrinsicHash': extrinsicHash,
      'block': {'height': blockNumber, 'hash': blockHash},
    };
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

  // Create a ReversibleTransferEvent with a known status
  factory ReversibleTransferEvent.fromJson(Map<String, dynamic> json, {required ReversibleTransferStatus status}) {
    final block = jsonMapRequired(json['block'], 'block');
    final transfer = jsonMapOrNull(json['scheduledTransfer']) ?? json;
    return ReversibleTransferEvent(
      id: stringFromJson(json['id']),
      from: nestedAccountId(transfer['sender'] ?? transfer['from']),
      to: nestedAccountId(transfer['receiver'] ?? transfer['to']),
      amount: bigIntFromJson(transfer['amount']),
      timestamp: dateTimeFromJson(json['timestamp']),
      txId: stringFromJson(json['txId']),
      status: status,
      scheduledAt: dateTimeFromJson(transfer['scheduledAt']),
      extrinsicHash: optionalExtrinsicHash(json),
      blockNumber: blockHeightFromJsonMap(block),
      blockHash: blockHashFromJsonMap(block),
    );
  }

  // Create a ReversibleTransferEvent we previously stored as JSON using toJson()
  factory ReversibleTransferEvent.deserializeFromJson(Map<String, dynamic> json) {
    return ReversibleTransferEvent.fromJson(
      json,
      status: ReversibleTransferStatus.values.byName(json['status'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': EventType.REVERSIBLE_TRANSFER.name,
      'from': {'id': from},
      'to': {'id': to},
      'amount': amount.toString(),
      'timestamp': timestamp.toIso8601String(),
      'txId': txId,
      'status': status.name,
      'scheduledAt': scheduledAt.toIso8601String(),
      'extrinsicHash': extrinsicHash,
      'block': {'height': blockNumber, 'hash': blockHash},
    };
  }

  ReversibleTransferEvent copyWith({
    String? id,
    String? from,
    String? to,
    BigInt? amount,
    DateTime? timestamp,
    String? txId,
    ReversibleTransferStatus? status,
    DateTime? scheduledAt,
    String? extrinsicHash,
    int? blockNumber,
    String? blockHash,
  }) {
    return ReversibleTransferEvent(
      id: id ?? this.id,
      from: from ?? this.from,
      to: to ?? this.to,
      amount: amount ?? this.amount,
      timestamp: timestamp ?? this.timestamp,
      txId: txId ?? this.txId,
      status: status ?? this.status,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      extrinsicHash: extrinsicHash ?? this.extrinsicHash,
      blockNumber: blockNumber ?? this.blockNumber,
      blockHash: blockHash ?? this.blockHash,
    );
  }

  // guaranteed to be positive or zero
  Duration get remainingTime => scheduledAt.difference(DateTime.now()).positive;

  @override
  String toString() {
    return 'ReversibleTransfer{id: $id, from: $from, to: $to, amount: $amount, timestamp: $timestamp, txId: $txId, status: $status, scheduledAt: $scheduledAt, extrinsicHash: $extrinsicHash, blockNumber: $blockNumber}';
  }
}

extension PositiveDuration on Duration {
  Duration get positive => isNegative ? Duration.zero : this;
}
