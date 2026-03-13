import 'package:quantus_sdk/src/models/transaction_event.dart';

class SortedTransactionsList {
  final List<ReversibleTransferEvent> scheduledReversibleTransfers;
  final List<TransactionEvent> otherTransfers;
  final int nextOtherOffset;
  final int nextScheduledOffset;
  final bool hasMore;

  const SortedTransactionsList({
    required this.scheduledReversibleTransfers,
    required this.otherTransfers,
    this.nextOtherOffset = 0,
    this.nextScheduledOffset = 0,
    this.hasMore = false,
  });

  static const SortedTransactionsList empty = SortedTransactionsList(
    scheduledReversibleTransfers: [],
    otherTransfers: [],
  );
}
