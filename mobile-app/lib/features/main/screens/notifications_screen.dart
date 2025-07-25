import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/features/components/base_with_background.dart';
import 'package:resonance_network_wallet/features/components/dropdown_select.dart';
import 'package:resonance_network_wallet/features/components/notification_group.dart';
import 'package:resonance_network_wallet/models/wallet_state_manager.dart';
import 'package:resonance_network_wallet/services/notification_service.dart'; // Ensure import

class NotificationsScreen extends StatefulWidget {
  final WalletStateManager manager;

  const NotificationsScreen({super.key, required this.manager});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();

  @override
  void dispose() {
    super.dispose();
    _notificationService.dispose();
  }

  void _addNotification() {
    _notificationService.addNotification(
      id: '1',
      accountName: widget.manager.walletData?.account.name ?? 'Unknown',
      title: 'Notification Info',
      message: 'This is info notification',
    );

    _notificationService.addNotification(
      id: '2',
      accountName: widget.manager.walletData?.account.name ?? 'Unknown',
      title: 'Notification Success',
      message: 'This is success notification',
      type: NotificationType.success,
    );

    _notificationService.addNotification(
      id: '3',
      accountName: widget.manager.walletData?.account.name ?? 'Unknown',
      title: 'Notification Warning',
      message: 'This is warning notification',
      type: NotificationType.warning,
    );

    _notificationService.addNotification(
      id: '4',
      accountName: widget.manager.walletData?.account.name ?? 'Unknown',
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
              DropdownSelect(
                initialValue: '1',
                items: [
                  Item(id: '1', label: 'All Accounts'),
                  Item(id: '2', label: 'My account'),
                  Item(id: '3', label: 'Your Accounts'),
                  Item(id: '4', label: 'His Accounts'),
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
