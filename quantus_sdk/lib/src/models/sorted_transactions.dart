import 'package:quantus_sdk/src/models/transaction_event.dart';
import 'package:quantus_sdk/src/models/reversible_transfer_status.dart';

class SortedTransactionsList {
  final List<ReversibleTransferEvent> reversibleTransfers;
  final List<TransactionEvent> otherTransfers;

  SortedTransactionsList({required this.reversibleTransfers, required this.otherTransfers});

  List<TransactionEvent> get combined {
    // Scheduled transfers on top
    final scheduled = reversibleTransfers.where((tx) => tx.status == ReversibleTransferStatus.SCHEDULED).toList();

    // The rest of the reversible transfers
    final otherReversible = reversibleTransfers.where((tx) => tx.status != ReversibleTransferStatus.SCHEDULED).toList();

    // Combine all lists
    return [...scheduled, ...otherReversible, ...otherTransfers];
  }
}
