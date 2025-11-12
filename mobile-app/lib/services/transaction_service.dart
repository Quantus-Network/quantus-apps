import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/transaction_role.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';

final transactionServiceProvider = Provider<TransactionService>((ref) {
  return TransactionService(ref);
});

class TransactionService {
  final Ref _ref;

  TransactionService(this._ref);

  /// Combines and deduplicates transactions from multiple sources
  /// Priority order: pending -> reversible -> other
  /// Duplicates are removed based on transaction ID
  List<TransactionEvent> combineAndDeduplicateTransactions({
    required Set<String> pendingCancellationIds,
    required List<PendingTransactionEvent> pendingTransactions,
    required List<ReversibleTransferEvent> reversibleTransfers,
    required List<TransactionEvent> otherTransfers,
  }) {
    final seenIds = <String>{};
    final List<TransactionEvent> result = [];

    // Add pending transactions first (highest priority)
    for (final transaction in pendingTransactions) {
      if (seenIds.add(transaction.id)) {
        if (transaction.isReversible && pendingCancellationIds.contains(transaction.id)) {
          result.add(transaction.copyWith(status: ReversibleTransferStatus.CANCELLED));
        } else {
          result.add(transaction);
        }
      }
    }

    // Add reversible transfers (medium priority)
    for (final transaction in reversibleTransfers) {
      if (transaction.status == ReversibleTransferStatus.SCHEDULED) {
        if (seenIds.add(transaction.id)) {
          if (pendingCancellationIds.contains(transaction.id)) {
            result.add(transaction.copyWith(status: ReversibleTransferStatus.CANCELLED));
          } else {
            result.add(transaction);
          }
        }
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

  TransactionRole getTransactionRole(TransactionEvent transaction, {List<String>? accountIds}) {
    final accounts = accountIds ?? (_ref.read(accountsProvider).value?.map((acc) => acc.accountId).toList() ?? []);

    final isFrom = accounts.contains(transaction.from);
    final isTo = accounts.contains(transaction.to);

    if (isFrom && isTo) {
      return TransactionRole.both;
    } else if (isFrom) {
      return TransactionRole.sender;
    } else {
      return TransactionRole.receiver;
    }
  }

  TransactionEvent? deserializeTxEventFromJsonIfPossible(dynamic json) {
    final txType = json['type'];
    TransactionEvent? event;

    try {
      if (txType == EventType.TRANSFER.name) {
        event = TransferEvent.fromJson(json);
      } else if (txType == EventType.REVERSIBLE_TRANSFER.name) {
        event = ReversibleTransferEvent.fromJson(json);
      } else if (txType == EventType.PENDING_TRANSACTION.name) {
        event = PendingTransactionEvent.fromJson(json);
      }
    } catch (e) {
      print('Failed deserializing event: $e');
    }

    return event;
  }
}
