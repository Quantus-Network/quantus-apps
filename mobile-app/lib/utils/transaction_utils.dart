import 'package:quantus_sdk/quantus_sdk.dart';

/// Utility functions for handling transactions
class TransactionUtils {
  /// Combines and deduplicates transactions from multiple sources
  /// Priority order: pending -> reversible -> other
  /// Duplicates are removed based on transaction ID
  static List<TransactionEvent> combineAndDeduplicateTransactions({
    required List<PendingTransactionEvent> pendingTransactions,
    required List<ReversibleTransferEvent> reversibleTransfers,
    required List<TransactionEvent> otherTransfers,
  }) {
    final seenIds = <String>{};
    final List<TransactionEvent> result = [];

    // Add pending transactions first (highest priority)
    for (final transaction in pendingTransactions) {
      if (seenIds.add(transaction.id)) {
        result.add(transaction);
      }
    }

    // Add reversible transfers (medium priority)
    for (final transaction in reversibleTransfers) {
      if (seenIds.add(transaction.id)) {
        result.add(transaction);
      }
    }

    // Add other transfers (lowest priority)
    for (final transaction in otherTransfers) {
      if (seenIds.add(transaction.id)) {
        result.add(transaction);
      }
    }

    return result;
  }
}
