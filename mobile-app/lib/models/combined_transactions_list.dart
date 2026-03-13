import 'package:quantus_sdk/quantus_sdk.dart';

class CombinedTransactionsList {
  final Set<String> pendingCancellationIds;
  final List<PendingTransactionEvent> pendingTransactions;
  final List<ReversibleTransferEvent> scheduledReversibleTransfers;
  final List<TransactionEvent> otherTransfers;

  CombinedTransactionsList({
    required this.pendingCancellationIds,
    required this.pendingTransactions,
    required this.scheduledReversibleTransfers,
    required this.otherTransfers,
  });

  CombinedTransactionsList copyWith({
    Set<String>? pendingCancellationIds,
    List<PendingTransactionEvent>? pendingTransactions,
    List<ReversibleTransferEvent>? scheduledReversibleTransfers,
    List<TransactionEvent>? otherTransfers,
  }) {
    return CombinedTransactionsList(
      pendingCancellationIds: pendingCancellationIds ?? this.pendingCancellationIds,
      pendingTransactions: pendingTransactions ?? this.pendingTransactions,
      scheduledReversibleTransfers: scheduledReversibleTransfers ?? this.scheduledReversibleTransfers,
      otherTransfers: otherTransfers ?? this.otherTransfers,
    );
  }

  static CombinedTransactionsList get empty => CombinedTransactionsList(
    pendingCancellationIds: <String>{},
    pendingTransactions: [],
    scheduledReversibleTransfers: [],
    otherTransfers: [],
  );
}
