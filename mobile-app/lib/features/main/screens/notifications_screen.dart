import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/base_with_background.dart';
import 'package:resonance_network_wallet/features/components/dropdown_select.dart';
import 'package:resonance_network_wallet/features/components/notification_group.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/notification_provider.dart';
import 'package:resonance_network_wallet/models/notification_models.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  void _addNotification() {
    final activeAccount = ref.read(activeAccountProvider).value;
    final accountName = activeAccount?.name ?? 'Unknown';

    final notifier = ref.read(notificationProvider.notifier);

    notifier.addNotification(NotificationData(
      id: '1',
      type: NotificationType.info,
      source: NotificationSource.local,
      title: 'Notification Info',
      message: 'This is info notification',
      accountName: accountName,
      timestamp: DateTime.now(),
    ));

    notifier.addNotification(NotificationData(
      id: '2',
      type: NotificationType.success,
      source: NotificationSource.local,
      title: 'Notification Success',
      message: 'This is success notification',
      accountName: accountName,
      timestamp: DateTime.now(),
    ));

    notifier.addNotification(NotificationData(
      id: '3',
      type: NotificationType.warning,
      source: NotificationSource.local,
      title: 'Notification Warning',
      message: 'This is warning notification',
      accountName: accountName,
      timestamp: DateTime.now(),
    ));

    notifier.addNotification(NotificationData(
      id: '4',
      type: NotificationType.alert,
      source: NotificationSource.local,
      title: 'Notification Alert',
      message: 'This is alert notification',
      accountName: accountName,
      timestamp: DateTime.now(),
    ));
  }

  void _addTransactionFailed() {
    final activeAccount = ref.read(activeAccountProvider).value;
    final accountName = activeAccount?.name ?? 'Unknown';
    final accountId = activeAccount?.accountId ?? 'unknown';

    final notifier = ref.read(notificationProvider.notifier);

    // Create sample transaction data for demonstration
    final transactionData = TransactionData(
      id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
      from: accountId,
      to: 'recipient_address',
      amount: BigInt.from(1000000), // 1 QNT
      fee: BigInt.from(10000), // 0.01 QNT
      error: 'Insufficient balance',
      timestamp: DateTime.now(),
      state: TransactionState.failed,
    );

    notifier.addTransactionFailed(
      accountName: accountName,
      transactionId: transactionData.id,
      errorMessage: 'Transaction failed due to insufficient balance',
      transactionData: transactionData,
    );
  }

  void _addBalanceAlert() {
    final activeAccount = ref.read(activeAccountProvider).value;
    final accountName = activeAccount?.name ?? 'Unknown';
    final accountId = activeAccount?.accountId ?? 'unknown';

    final notifier = ref.read(notificationProvider.notifier);
    notifier.addBalanceLow(
      accountName: accountName,
      accountId: accountId,
    );
  }

  void _addAccountSuccess() {
    final activeAccount = ref.read(activeAccountProvider).value;
    final accountName = activeAccount?.name ?? 'Unknown';
    final accountId = activeAccount?.accountId ?? 'unknown';

    final notifier = ref.read(notificationProvider.notifier);
    notifier.addAccountAdded(
      accountName: accountName,
      accountId: accountId,
    );
  }

  void _addReversibleReminder() {
    final activeAccount = ref.read(activeAccountProvider).value;
    final accountName = activeAccount?.name ?? 'Unknown';

    final executionTime = DateTime.now().add(const Duration(hours: 2));

    final notifier = ref.read(notificationProvider.notifier);
    notifier.addReversibleTransactionReminder(
      accountName: accountName,
      transactionId: 'reversible_${DateTime.now().millisecondsSinceEpoch}',
      executionTime: executionTime,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseWithBackground(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notifications',
              style: TextStyle(
                color: Color(0xFFE6E6E6),
                fontSize: 16,
                fontFamily: 'Fira Code',
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 13),
            DropdownSelect<String>(
              initialValue: '1',
              items: [
                Item(value: '1', label: 'All Accounts'),
                Item(value: '2', label: 'My account'),
                Item(value: '3', label: 'Your Accounts'),
                Item(value: '4', label: 'His Accounts'),
              ],
              onChanged: (selectedItem) {
                print('Selected account: ${selectedItem?.label}');
              },
            ),
            const SizedBox(height: 13),
            // Make buttons scrollable in a constrained height
            SizedBox(
              height: 200, // Fixed height for buttons section
              child: SingleChildScrollView(
                child: Column(
                  spacing: 8,
                  children: [
                    ElevatedButton(
                      onPressed: _addNotification,
                      child: const Text('Add Test Notifications'),
                    ),
                    ElevatedButton(
                      onPressed: _addTransactionFailed,
                      child: const Text('Simulate Transaction Failed'),
                    ),
                    ElevatedButton(
                      onPressed: _addBalanceAlert,
                      child: const Text('Simulate Balance Alert'),
                    ),
                    ElevatedButton(
                      onPressed: _addAccountSuccess,
                      child: const Text('Simulate Account Added'),
                    ),
                    ElevatedButton(
                      onPressed: _addReversibleReminder,
                      child: const Text('Simulate Reversible Reminder'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Notification overlay - use Expanded to take remaining space
            Expanded(
              child: Consumer(
                builder: (context, ref, child) {
                  final notifications = ref.watch(notificationProvider);

                  if (notifications.isEmpty) {
                    return const Center(
                      child: Text(
                        'No notifications',
                        style: TextStyle(
                          color: Color(0xFFE6E6E6),
                          fontSize: 14,
                          fontFamily: 'Fira Code',
                        ),
                      ),
                    );
                  }

                  return NotificationGroup(
                    notifications: notifications,
                    onDismissAll: () => ref.read(notificationProvider.notifier).clearAll(),
                    onDismissSingle: (id) => ref.read(notificationProvider.notifier).removeNotification(id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
