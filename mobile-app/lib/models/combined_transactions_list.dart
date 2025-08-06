import 'package:quantus_sdk/quantus_sdk.dart';

class CombinedTransactionsList {
  final List<PendingTransactionEvent> pendingTransactions;
  final List<ReversibleTransferEvent> reversibleTransfers;
  final List<TransactionEvent> otherTransfers;

  CombinedTransactionsList({
    required this.pendingTransactions,
    required this.reversibleTransfers,
    required this.otherTransfers,
  });

  CombinedTransactionsList copyWith({
    List<PendingTransactionEvent>? pendingTransactions,
    List<ReversibleTransferEvent>? reversibleTransfers,
    List<TransactionEvent>? otherTransfers,
  }) {
    return CombinedTransactionsList(
      pendingTransactions: pendingTransactions ?? this.pendingTransactions,
      reversibleTransfers: reversibleTransfers ?? this.reversibleTransfers,
      otherTransfers: otherTransfers ?? this.otherTransfers,
    );
  }

  static CombinedTransactionsList get empty => CombinedTransactionsList(
    pendingTransactions: [],
    reversibleTransfers: [],
    otherTransfers: [],
  );
}
