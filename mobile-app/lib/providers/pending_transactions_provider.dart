import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

// Pending transaction event lifecycle:
//
// 1. Create PendingTransactionEvent
// 2. Add to pendingTransactionsProvider     ← Shows in UI immediately
// 3. _submitAndTrack begins
// 4. onStatus updates: ready → broadcast → inBlock
// 5. History poller finds it in blockchain
// 6. Transaction moves to inHistory
// 7. Then removed from pending

class PendingTransactionsNotifier extends StateNotifier<List<PendingTransactionEvent>> {
  PendingTransactionsNotifier() : super([]);

  /// Adds a new transaction to the list.
  void add(PendingTransactionEvent tx) {
    state = [...state, tx];
  }

  /// Updates the state of an existing transaction (e.g., 'inBlock', 'failed').
  void updateState(
    String id,
    TransactionState newState, {
    DateTime? scheduledAtTime,
    String? blockHash,
    String? error,
  }) {
    state = [
      for (final tx in state)
        if (tx.id == id)
          tx.copyWith(transactionState: newState, blockHash: blockHash, scheduledAtTime: scheduledAtTime, error: error)
        else
          tx,
    ];
  }

  /// Removes a transaction from the list (once it's confirmed in history).
  void remove(String id) {
    state = state.where((tx) => tx.id != id).toList();
  }

  /// Clears all pending transactions (e.g., on logout)
  void clear() {
    state = [];
  }
}

/// Provider that exposes the PendingTransactionsNotifier.
final pendingTransactionsProvider = StateNotifierProvider<PendingTransactionsNotifier, List<PendingTransactionEvent>>((
  ref,
) {
  return PendingTransactionsNotifier();
});
