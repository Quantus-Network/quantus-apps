import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/generated/planck/pallets/balances.dart' as balances;
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/notification_models.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/all_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/notification_provider.dart';
import 'package:resonance_network_wallet/providers/pending_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';

/// Service that integrates notifications with existing app providers
class NotificationIntegrationService {
  final Ref _ref;

  NotificationIntegrationService(this._ref) {
    // Set up listeners for automatic notifications
    _setupTransactionListeners();
    _setupBalanceListeners();
  }

  void _setupTransactionListeners() {
    // Listen to pending transactions for failure notifications
    _ref.listen<List<PendingTransactionEvent>>(pendingTransactionsProvider, (previous, next) {
      if (previous != null) {
        // Check for newly failed transactions
        final newFailed = next.where(
          (tx) =>
              tx.transactionState == TransactionState.failed &&
              !previous.any((prevTx) => prevTx.id == tx.id && prevTx.transactionState == tx.transactionState),
        );

        for (final failedTx in newFailed) {
          _notifyTransactionFailed(failedTx);
        }
      }
    });

    _ref.listen(paginationControllerProvider, (previous, next) {
      if (previous != null && previous.otherTransfers.isNotEmpty) {
        final accounts = _ref.watch(accountsProvider).value;
        if (accounts == null || accounts.isEmpty) return;

        final accountIds = accounts.map((acc) => acc.accountId).toSet();

        final previousIds = previous.otherTransfers.map((tx) => tx.id).toSet();
        final newTxs = next.otherTransfers.where((tx) => !previousIds.contains(tx.id));

        final newReceiveTxs = newTxs.where((tx) {
          if (tx is! TransferEvent) return false;

          // Received from someone else (not a self-transfer)
          return accountIds.contains(tx.to) && !accountIds.contains(tx.from);
        });

        for (final receiveTokenTx in newReceiveTxs) {
          _notifyTokenReceived(receiveTokenTx as TransferEvent);
        }
      }
    });
  }

  void _setupBalanceListeners() {
    // Listen to balance changes for low balance alerts
    _ref.listen<AsyncValue<BigInt>>(balanceProvider, (previous, next) {
      next.whenData((balance) {
        // Check if balance is at or near existential deposit
        final existentialDeposit = balances.Constants().existentialDeposit;
        if (balance <= existentialDeposit) {
          // Example threshold
          final activeAccount = _ref.read(activeAccountProvider).value;
          if (activeAccount is RegularAccount) {
            _notifyLowBalance(activeAccount.account, activeAccount.account.accountId);
          }
        }
      });
    });
  }

  void _notifyTransactionFailed(PendingTransactionEvent transaction) {
    final notifier = _ref.read(notificationProvider.notifier);
    final account = _ref.read(accountsProvider.notifier).getAccountWithId(transaction.from);

    notifier.addTransactionFailed(
      account: account,
      errorMessage: transaction.error ?? 'Transaction failed',
      transactionData: transaction,
    );
  }

  void _notifyLowBalance(Account account, String accountId) {
    final notifier = _ref.read(notificationProvider.notifier);

    // Check if we already have a recent low balance notification for this account
    final existingNotifications = notifier.getNotificationsForAccount(accountId);
    final recentLowBalance = existingNotifications.any(
      (n) => n.type == NotificationType.alert && n.timestamp.isAfter(DateTime.now().subtract(const Duration(hours: 1))),
    );

    if (!recentLowBalance) {
      notifier.addBalanceLow(account: account);
    }
  }

  void _notifyTokenReceived(TransferEvent transaction) {
    final notifier = _ref.read(notificationProvider.notifier);
    final account = _ref.read(accountsProvider.notifier).getAccountWithId(transaction.to);

    notifier.addTokenReceived(account: account, transactionData: transaction);
  }
}

/// Provider for the notification integration service
final notificationIntegrationServiceProvider = Provider<NotificationIntegrationService>((ref) {
  return NotificationIntegrationService(ref);
});
