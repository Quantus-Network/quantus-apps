import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/dropdown_select.dart';
import 'package:resonance_network_wallet/features/components/notification_group.dart';
import 'package:resonance_network_wallet/features/components/scaffold_base.dart';
import 'package:resonance_network_wallet/features/components/sphere.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/notification_provider.dart';
import 'package:resonance_network_wallet/models/notification_models.dart';
import 'package:resonance_network_wallet/services/feature_flags.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  List<String>? _selectedAccountIds;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeAccounts();
  }

  void _initializeAccounts() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final accountsValue = ref.read(accountsProvider);
        accountsValue.when(
          data: (accounts) {
            if (!_isInitialized) {
              // Default to all accounts
              final accountIds = accounts.map((a) => a.accountId).toList();
              setState(() {
                _selectedAccountIds = accountIds;
                _isInitialized = true;
              });
            }
          },
          loading: () {},
          error: (error, stack) {
            if (!_isInitialized) {
              setState(() {
                _selectedAccountIds = [];
                _isInitialized = true;
              });
            }
          },
        );
      }
    });
  }

  void _addNotification() {
    final activeAccount = ref.read(activeAccountProvider).value;
    final accountName = activeAccount?.name ?? 'Unknown';

    final notifier = ref.read(notificationProvider.notifier);

    notifier.addNotification(
      NotificationData(
        id: '1',
        type: NotificationType.info,
        source: NotificationSource.local,
        title: 'Notification Info',
        message: 'This is info notification',
        accountName: accountName,
        timestamp: DateTime.now(),
      ),
    );

    notifier.addNotification(
      NotificationData(
        id: '2',
        type: NotificationType.success,
        source: NotificationSource.local,
        title: 'Notification Success',
        message: 'This is success notification',
        accountName: accountName,
        timestamp: DateTime.now(),
      ),
    );

    notifier.addNotification(
      NotificationData(
        id: '3',
        type: NotificationType.warning,
        source: NotificationSource.local,
        title: 'Notification Warning',
        message: 'This is warning notification',
        accountName: accountName,
        timestamp: DateTime.now(),
      ),
    );

    notifier.addNotification(
      NotificationData(
        id: '4',
        type: NotificationType.alert,
        source: NotificationSource.local,
        title: 'Notification Alert',
        message: 'This is alert notification',
        accountName: accountName,
        timestamp: DateTime.now(),
      ),
    );
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
    notifier.addBalanceLow(accountName: accountName, accountId: accountId);
  }

  void _addAccountSuccess() {
    final activeAccount = ref.read(activeAccountProvider).value;
    final accountName = activeAccount?.name ?? 'Unknown';
    final accountId = activeAccount?.accountId ?? 'unknown';

    final notifier = ref.read(notificationProvider.notifier);
    notifier.addAccountAdded(accountName: accountName, accountId: accountId);
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
    return ScaffoldBase(
      decorations: [
        Positioned(
          left: context.getHorizontalCenterPosition(252),
          bottom: -30,
          child: const Sphere(variant: 9, size: 252),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => Navigator.pop(context),
                child: const Icon(
                  Icons.arrow_back_ios,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Notifications',
                style: context.themeText.smallTitle,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Consumer(
            builder: (context, ref, child) {
              final accountsAsync = ref.watch(accountsProvider);
              return accountsAsync.when(
                data: (accounts) {
                  if (accounts.isEmpty) {
                    return const Text(
                      'No accounts found.',
                      style: TextStyle(color: Colors.white70),
                    );
                  }
                  return _buildAccountDropdown(accounts);
                },
                loading: () => const CircularProgressIndicator(),
                error: (e, st) => const Text(
                  'Error loading accounts.',
                  style: TextStyle(color: Colors.red),
                ),
              );
            },
          ),
          const SizedBox(height: 13),
          // Show test buttons only if feature flag is enabled
          Consumer(
            builder: (context, ref, child) {
              final featureFlags = ref.watch(featureFlagsProvider);
              final enableTestButtons = featureFlags.isEnabled('test_buttons');

              if (!enableTestButtons) return const SizedBox.shrink();

              return SizedBox(
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
              );
            },
          ),
          Consumer(
            builder: (context, ref, child) {
              final featureFlags = ref.watch(featureFlagsProvider);
              final enableTestButtons = featureFlags.isEnabled('test_buttons');
              return enableTestButtons
                  ? const SizedBox(height: 24)
                  : const SizedBox.shrink();
            },
          ),
          const SizedBox(height: 24),
          // Notification overlay - use Expanded to take remaining space
          Expanded(
            child: Consumer(
              builder: (context, ref, child) {
                final allNotifications = ref.watch(notificationProvider);
                final filteredNotifications = _filterNotificationsByAccounts(
                  allNotifications,
                );

                if (filteredNotifications.isEmpty) {
                  return Center(
                    child: Text(
                      'No notifications',
                      style: context.themeText.paragraph,
                    ),
                  );
                }

                return NotificationGroup(
                  notifications: filteredNotifications,
                  onDismissAll: () =>
                      ref.read(notificationProvider.notifier).clearAll(),
                  onDismissSingle: (id) => ref
                      .read(notificationProvider.notifier)
                      .removeNotification(id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountDropdown(List<Account> accounts) {
    final allAccountsSelected =
        _selectedAccountIds != null &&
        _selectedAccountIds!.length == accounts.length;

    return DropdownSelect<String>(
      initialValue: allAccountsSelected
          ? '_all_'
          : _selectedAccountIds?.firstOrNull,
      items: [
        Item<String>(value: '_all_', label: 'All Accounts'),
        ...accounts.map(
          (account) =>
              Item<String>(value: account.accountId, label: account.name),
        ),
      ],
      onChanged: (selectedItem) {
        if (selectedItem == null) return;
        final newSelectedIds = selectedItem.value == '_all_'
            ? accounts.map((a) => a.accountId).toList()
            : [selectedItem.value];

        setState(() {
          _selectedAccountIds = newSelectedIds;
        });
      },
      disabled: false,
    );
  }

  List<NotificationData> _filterNotificationsByAccounts(
    List<NotificationData> notifications,
  ) {
    if (_selectedAccountIds == null || _selectedAccountIds!.isEmpty) {
      return notifications;
    }

    // If "All Accounts" is selected, show all notifications
    if (_selectedAccountIds!.length ==
        ref.read(accountsProvider).value?.length) {
      return notifications;
    }

    // Filter notifications by selected account IDs
    return notifications.where((notification) {
      // Check if notification has account metadata
      final accountId = notification.metadata?['accountId'] as String?;
      return accountId != null && _selectedAccountIds!.contains(accountId);
    }).toList();
  }
}
