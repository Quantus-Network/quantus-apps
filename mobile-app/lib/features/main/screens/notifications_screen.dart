import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/features/components/base_with_background.dart';
import 'package:resonance_network_wallet/features/components/dropdown_select.dart';
import 'package:resonance_network_wallet/features/components/notification_group.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/services/notification_service.dart'; // Ensure import

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();

  @override
  void dispose() {
    super.dispose();
    _notificationService.dispose();
  }

  void _addNotification() {
    final activeAccount = ref.read(activeAccountProvider).value;
    final accountName = activeAccount?.name ?? 'Unknown';

    _notificationService.addNotification(
      id: '1',
      accountName: accountName,
      title: 'Notification Info',
      message: 'This is info notification',
    );

    _notificationService.addNotification(
      id: '2',
      accountName: accountName,
      title: 'Notification Success',
      message: 'This is success notification',
      type: NotificationType.success,
    );

    _notificationService.addNotification(
      id: '3',
      accountName: accountName,
      title: 'Notification Warning',
      message: 'This is warning notification',
      type: NotificationType.warning,
    );

    _notificationService.addNotification(
      id: '4',
      accountName: accountName,
      title: 'Notification Error',
      message: 'This is error notification',
      type: NotificationType.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseWithBackground(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: SizedBox(
          width: double.infinity,
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
              ElevatedButton(
                onPressed: _addNotification,
                child: const Text('Add Notification'),
              ),
              const SizedBox(height: 24),
              // Notification overlay
              ListenableBuilder(
                listenable: _notificationService,
                builder: (context, child) {
                  if (_notificationService.activeNotifications.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return NotificationGroup(
                    notifications: _notificationService.activeNotifications,
                    onDismissAll: _notificationService.clearAll,
                    onDismissSingle: _notificationService.removeNotification,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
