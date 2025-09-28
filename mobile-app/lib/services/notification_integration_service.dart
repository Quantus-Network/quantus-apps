import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/generated/schrodinger/pallets/balances.dart'
    as balances;
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/notification_models.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
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
    _ref.listen<List<PendingTransactionEvent>>(pendingTransactionsProvider, (
      previous,
      next,
    ) {
      if (previous != null) {
        // Check for newly failed transactions
        final newFailed = next.where(
          (tx) =>
              tx.transactionState == TransactionState.failed &&
              !previous.any(
                (prevTx) =>
                    prevTx.id == tx.id &&
                    prevTx.transactionState == tx.transactionState,
              ),
        );

        for (final failedTx in newFailed) {
          _notifyTransactionFailed(failedTx);
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
          if (activeAccount != null) {
            _notifyLowBalance(activeAccount.name, activeAccount.accountId);
          }
        }
      });
    });
  }

  void _notifyTransactionFailed(PendingTransactionEvent transaction) {
    final notifier = _ref.read(notificationProvider.notifier);

    // Create transaction data for detailed view
    final transactionData = TransactionData(
      id: transaction.id,
      from: transaction.from,
      to: transaction.to,
      amount: transaction.amount,
      fee: transaction.fee,
      error: transaction.error,
      timestamp: transaction.timestamp,
      state: transaction.transactionState,
    );

    notifier.addTransactionFailed(
      accountName: transaction
          .from, // This might need adjustment based on your account resolution
      transactionId: transaction.id,
      errorMessage: transaction.error ?? 'Transaction failed',
      transactionData: transactionData,
    );
  }

  void _notifyLowBalance(String accountName, String accountId) {
    final notifier = _ref.read(notificationProvider.notifier);

    // Check if we already have a recent low balance notification for this account
    final existingNotifications = notifier.getNotificationsForAccount(
      accountId,
    );
    final recentLowBalance = existingNotifications.any(
      (n) =>
          n.type == NotificationType.alert &&
          n.timestamp.isAfter(
            DateTime.now().subtract(const Duration(hours: 1)),
          ),
    );

    if (!recentLowBalance) {
      notifier.addBalanceLow(accountName: accountName, accountId: accountId);
    }
  }

  /// Manually trigger notifications (for testing or specific use cases)
  void notifyAccountAdded(String accountName, String accountId) {
    final notifier = _ref.read(notificationProvider.notifier);
    notifier.addAccountAdded(accountName: accountName, accountId: accountId);
  }

  void notifyReversibleTransaction(
    String accountName,
    String transactionId,
    DateTime executionTime,
  ) {
    final notifier = _ref.read(notificationProvider.notifier);
    notifier.addReversibleTransactionReminder(
      accountName: accountName,
      transactionId: transactionId,
      executionTime: executionTime,
    );
  }
}

/// Provider for the notification integration service
final notificationIntegrationServiceProvider =
    Provider<NotificationIntegrationService>((ref) {
      return NotificationIntegrationService(ref);
    });
