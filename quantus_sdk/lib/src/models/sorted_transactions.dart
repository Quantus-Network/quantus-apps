import 'package:quantus_sdk/src/models/account_event_cursor.dart';
import 'package:quantus_sdk/src/models/transaction_event.dart';

class SortedTransactionsList {
  final List<ReversibleTransferEvent> scheduledReversibleTransfers;
  final List<TransactionEvent> otherTransfers;

  /// Where the next page of [otherTransfers] starts; null before any row has
  /// been fetched.
  final AccountEventCursor? nextOtherCursor;

  /// Where the next page of [scheduledReversibleTransfers] starts; null before
  /// any row has been fetched.
  final AccountEventCursor? nextScheduledCursor;
  final bool hasMore;

  const SortedTransactionsList({
    required this.scheduledReversibleTransfers,
    required this.otherTransfers,
    this.nextOtherCursor,
    this.nextScheduledCursor,
    this.hasMore = false,
  });

  static const SortedTransactionsList empty = SortedTransactionsList(
    scheduledReversibleTransfers: [],
    otherTransfers: [],
  );
}
