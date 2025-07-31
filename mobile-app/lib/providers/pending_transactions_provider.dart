import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/pending_transfer_event.dart';

/// Notifier to manage the list of pending transactions.
class PendingTransactionsNotifier
    extends StateNotifier<List<PendingTransactionEvent>> {
  PendingTransactionsNotifier() : super([]);

  /// Adds a new transaction to the list.
  void add(PendingTransactionEvent tx) {
    state = [...state, tx];
  }

  /// Updates the state of an existing transaction (e.g., 'inBlock', 'failed').
  void updateState(
    String id,
    TransactionState newState, {
    String? blockHash,
    String? error,
  }) {
    state = [
      for (final tx in state)
        if (tx.id == id)
          tx.copyWith(
            transactionState: newState,
            blockHash: blockHash,
            error: error,
          )
        else
          tx,
    ];
  }

  /// Removes a transaction from the list (once it's confirmed in history).
  void remove(String id) {
    state = state.where((tx) => tx.id != id).toList();
  }
}

/// Provider that exposes the PendingTransactionsNotifier.
final pendingTransactionsProvider =
    StateNotifierProvider<
      PendingTransactionsNotifier,
      List<PendingTransactionEvent>
    >((ref) {
      return PendingTransactionsNotifier();
    });
