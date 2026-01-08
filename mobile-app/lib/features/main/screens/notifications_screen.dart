import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/select.dart';
import 'package:resonance_network_wallet/features/components/notification_group.dart';
import 'package:resonance_network_wallet/features/components/scaffold_base.dart';
import 'package:resonance_network_wallet/features/components/sphere.dart';
import 'package:resonance_network_wallet/features/components/wallet_app_bar.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/notification_provider.dart';
import 'package:resonance_network_wallet/models/notification_models.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';
import 'package:resonance_network_wallet/utils/feature_flags.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
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
    final account = ref.read(activeAccountProvider).value;
    final accountName = account?.name ?? 'Unknown';
    final accountId = account?.accountId ?? 'unknown';

    final notifier = ref.read(notificationProvider.notifier);

    notifier.addNotification(
      NotificationData(
        id: '1',
        accountId: accountId,
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
        accountId: accountId,
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
        accountId: accountId,
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
        accountId: accountId,
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
    final account = ref.read(activeAccountProvider).value;

    final notifier = ref.read(notificationProvider.notifier);

    // Create sample transaction data for demonstration
    final transactionData = PendingTransactionEvent(
      tempId: 'tx_${DateTime.now().millisecondsSinceEpoch}',
      from: account?.accountId ?? 'Unknown',
      to: 'recipient_address',
      amount: BigInt.from(1000000), // 1 QNT
      fee: BigInt.from(10000), // 0.01 QNT
      error: 'Insufficient balance',
      timestamp: DateTime.now(),
      blockNumber: 1,
      delaySeconds: 0,
      isReversible: false,
      transactionState: TransactionState.failed,
    );

    notifier.addTransactionFailed(
      account: account,
      errorMessage: 'Transaction failed due to insufficient balance',
      transactionData: transactionData,
    );
  }

  void _addBalanceAlert() {
    final account = ref.read(activeAccountProvider).value;

    final notifier = ref.read(notificationProvider.notifier);
    notifier.addBalanceLow(account: account);
  }

  void _addAccountSuccess() {
    final account = ref.read(activeAccountProvider).value;

    final notifier = ref.read(notificationProvider.notifier);
    notifier.addAccountAdded(account: account);
  }

  void _addReversibleReminder() {
    final account = ref.read(activeAccountProvider).value;

    final notifier = ref.read(notificationProvider.notifier);
    notifier.addReversibleTransactionReminder(
      account: account,
      transactionData: ReversibleTransferEvent(
        id: 'revtx_123456',
        from: '0xABCDEF1234567890',
        to: '0xFEDCBA0987654321',
        amount: BigInt.from(2500000000000000000),
        timestamp: DateTime.now(),
        txId: '0xtransaction123abc',
        status: ReversibleTransferStatus.SCHEDULED,
        scheduledAt: DateTime.now().add(const Duration(minutes: 15)),
        extrinsicHash: '0xextrinsichash123',
        blockNumber: 123456,
        blockHash: '0xblockhash987654321',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldBase(
      appBar: WalletAppBar(title: 'Notifications'),
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
          Consumer(
            builder: (context, ref, child) {
              final accountsAsync = ref.watch(accountsProvider);
              return accountsAsync.when(
                data: (accounts) {
                  if (accounts.isEmpty) {
                    return const Text('No accounts found.', style: TextStyle(color: Colors.white70));
                  }
                  return _buildAccountDropdown(accounts);
                },
                loading: () => const CircularProgressIndicator(),
                error: (e, st) => const Text('Error loading accounts.', style: TextStyle(color: Colors.red)),
              );
            },
          ),
          const SizedBox(height: 13),
          // Show test buttons only if feature flag is enabled
          Consumer(
            builder: (context, ref, child) {
              final enableTestButtons = FeatureFlags.enableTestButtons;

              if (!enableTestButtons) return const SizedBox.shrink();

              return SizedBox(
                height: 200, // Fixed height for buttons section
                child: SingleChildScrollView(
                  child: Column(
                    spacing: 8,
                    children: [
                      ElevatedButton(onPressed: _addNotification, child: const Text('Add Test Notifications')),
                      ElevatedButton(
                        onPressed: _addTransactionFailed,
                        child: const Text('Simulate Transaction Failed'),
                      ),
                      ElevatedButton(onPressed: _addBalanceAlert, child: const Text('Simulate Balance Alert')),
                      ElevatedButton(onPressed: _addAccountSuccess, child: const Text('Simulate Account Added')),
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
              final enableTestButtons = FeatureFlags.enableTestButtons;
              return enableTestButtons ? const SizedBox(height: 24) : const SizedBox.shrink();
            },
          ),
          const SizedBox(height: 24),
          // Notification overlay - use Expanded to take remaining space
          Expanded(
            child: Consumer(
              builder: (context, ref, child) {
                final allNotifications = ref.watch(notificationProvider);
                final filteredNotifications = _filterNotificationsByAccounts(allNotifications);

                if (filteredNotifications.isEmpty) {
                  return Center(child: Text('No notifications', style: context.themeText.paragraph));
                }

                return NotificationGroup(
                  notifications: filteredNotifications,
                  onDismissAll: () => ref.read(notificationProvider.notifier).clearAll(),
                  onDismissSingle: (id) => ref.read(notificationProvider.notifier).removeNotification(id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountDropdown(List<Account> accounts) {
    final allAccountsSelected = _selectedAccountIds != null && _selectedAccountIds!.length == accounts.length;

    return Select<String>(
      initialValue: allAccountsSelected ? '_all_' : _selectedAccountIds?.firstOrNull,
      items: [
        Item<String>(value: '_all_', label: 'All Accounts'),
        ...accounts.map((account) => Item<String>(value: account.accountId, label: account.name)),
      ],
      onSelect: (selectedItem) {
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

  List<NotificationData> _filterNotificationsByAccounts(List<NotificationData> notifications) {
    if (_selectedAccountIds == null || _selectedAccountIds!.isEmpty) {
      return notifications;
    }

    // If "All Accounts" is selected, show all notifications
    if (_selectedAccountIds!.length == ref.read(accountsProvider).value?.length) {
      return notifications;
    }

    // Filter notifications by selected account IDs
    return notifications.where((notification) {
      // Check if notification has account metadata
      final accountId = notification.accountId;
      return _selectedAccountIds!.contains(accountId);
    }).toList();
  }
}
