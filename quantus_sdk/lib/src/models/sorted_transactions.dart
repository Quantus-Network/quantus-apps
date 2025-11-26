import 'package:quantus_sdk/src/models/reversible_transfer_status.dart';
import 'package:quantus_sdk/src/models/transaction_event.dart';

class SortedTransactionsList {
  final List<ReversibleTransferEvent> reversibleTransfers;
  final List<TransactionEvent> otherTransfers;

  const SortedTransactionsList({required this.reversibleTransfers, required this.otherTransfers});

  static const SortedTransactionsList empty = SortedTransactionsList(reversibleTransfers: [], otherTransfers: []);

  List<TransactionEvent> get combined {
    // Scheduled transfers on top
    final scheduled = reversibleTransfers.where((tx) => tx.status == ReversibleTransferStatus.SCHEDULED).toList();

    // Combine all lists
    return [...scheduled, ...otherTransfers];
  }
}
