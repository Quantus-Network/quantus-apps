import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/transaction_role.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/route_intent_providers.dart';

final transactionServiceProvider = Provider<TransactionService>((ref) {
  return TransactionService(ref);
});

enum TransactionViewType { normal, reversible, guardianIntercept }

class TransactionDetailViewConfig {
  final TransactionViewType type;
  final EntrustedAccount? entrustedAccount;

  const TransactionDetailViewConfig({required this.type, this.entrustedAccount});

  static const normal = TransactionDetailViewConfig(type: TransactionViewType.normal);
}

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

    // Add pending transactions that haven't not failed first (highest priority)
    for (final transaction in pendingTransactions) {
      if (transaction.transactionState == TransactionState.failed) {
        otherTransfers.add(transaction);
      } else if (seenIds.add(transaction.id)) {
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
    otherTransfers.sort((a, b) => b.timestamp.compareTo(a.timestamp));
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

  void navigateToTransactionFromPayloadIfPossible(Map<String, dynamic>? json, GlobalKey<NavigatorState> navigatorKey) {
    final event = deserializeTxEventFromJsonIfPossible(json);
    
    if (event != null) {
      _ref.read(transactionIntentProvider.notifier).state = event;
      navigatorKey.currentState?.pushNamed('/transactions');
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

  /// Basically deciding whether or not to show a reversible or intercept user interface,
  /// or whether to just show a normal transaction detail view.
  static TransactionDetailViewConfig getTransactionDetailViewConfig({
    required TransactionEvent transaction,
    required TransactionRole role,
    required DisplayAccount? activeAccount,
  }) {
    if (transaction is! ReversibleTransferEvent) {
      return TransactionDetailViewConfig.normal;
    }

    final isScheduled = transaction.status == ReversibleTransferStatus.SCHEDULED;
    final isCancelled = transaction.status == ReversibleTransferStatus.CANCELLED;
    // Reversible transaction UX is shown for scheduled transactions, so user can intercept / revert them.
    // It is also shown for canceled transactions, showing a "this transaction was canceled/intercepted/reverted" message.
    final showReversibleTransactionUX = isScheduled || isCancelled;
    final isActorRole = role == TransactionRole.sender || role == TransactionRole.both;

    if (!showReversibleTransactionUX || !isActorRole) {
      return TransactionDetailViewConfig.normal;
    }

    if (activeAccount is EntrustedDisplayAccount) {
      return TransactionDetailViewConfig(
        type: TransactionViewType.guardianIntercept,
        entrustedAccount: activeAccount.account,
      );
    }

    return const TransactionDetailViewConfig(type: TransactionViewType.reversible);
  }
}
