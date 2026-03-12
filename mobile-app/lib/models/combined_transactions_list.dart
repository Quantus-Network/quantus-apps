import 'package:quantus_sdk/quantus_sdk.dart';

class CombinedTransactionsList {
  final Set<String> pendingCancellationIds;
  final List<PendingTransactionEvent> pendingTransactions;
  final List<ReversibleTransferEvent> scheduledTransfers;
  final List<TransactionEvent> otherTransfers;

  CombinedTransactionsList({
    required this.pendingCancellationIds,
    required this.pendingTransactions,
    required this.scheduledTransfers,
    required this.otherTransfers,
  });

  CombinedTransactionsList copyWith({
    Set<String>? pendingCancellationIds,
    List<PendingTransactionEvent>? pendingTransactions,
    List<ReversibleTransferEvent>? scheduledTransfers,
    List<TransactionEvent>? otherTransfers,
  }) {
    return CombinedTransactionsList(
      pendingCancellationIds: pendingCancellationIds ?? this.pendingCancellationIds,
      pendingTransactions: pendingTransactions ?? this.pendingTransactions,
      scheduledTransfers: scheduledTransfers ?? this.scheduledTransfers,
      otherTransfers: otherTransfers ?? this.otherTransfers,
    );
  }

  static CombinedTransactionsList get empty => CombinedTransactionsList(
    pendingCancellationIds: <String>{},
    pendingTransactions: [],
    scheduledTransfers: [],
    otherTransfers: [],
  );
}
