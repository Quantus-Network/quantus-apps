import 'package:flutter_riverpod/legacy.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Optimistic transactions: added when submitted, shown immediately, removed
/// once the indexer reports them in history.
class PendingTransactionsNotifier extends StateNotifier<List<PendingTransactionEvent>> {
  PendingTransactionsNotifier() : super([]);

  void add(PendingTransactionEvent tx) {
    state = [...state, tx];
  }

  void updateState(
    String id,
    TransactionState newState, {
    DateTime? scheduledAtTime,
    String? blockHash,
    String? error,
    String? extrinsicHash,
  }) {
    state = [
      for (final tx in state)
        if (tx.id == id)
          tx.copyWith(
            transactionState: newState,
            blockHash: blockHash,
            scheduledAtTime: scheduledAtTime,
            error: error,
            extrinsicHash: extrinsicHash,
          )
        else
          tx,
    ];
  }

  void remove(String id) {
    state = state.where((tx) => tx.id != id).toList();
  }

  void clear() {
    state = [];
  }
}

final pendingTransactionsProvider = StateNotifierProvider<PendingTransactionsNotifier, List<PendingTransactionEvent>>(
  (ref) => PendingTransactionsNotifier(),
);
