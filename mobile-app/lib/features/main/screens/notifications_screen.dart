import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/features/components/base_with_background.dart';
import 'package:resonance_network_wallet/features/components/dropdown_select.dart';
import 'package:resonance_network_wallet/models/wallet_state_manager.dart';
import 'package:resonance_network_wallet/services/notification_service.dart'; // Ensure import

class NotificationsScreen extends StatefulWidget {
  final WalletStateManager manager;

  const NotificationsScreen({super.key, required this.manager});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Initialize the notification service
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.initialize(Overlay.of(context));
    });

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
                items: [
                  Item(id: '1', label: 'All Accounts'),
                  Item(id: '2', label: 'My account'),
                  Item(id: '3', label: 'Your Accounts'),
                  Item(id: '4', label: 'His Accounts'),
                ],
                onChanged: (selectedItem) {
                  // Handle account selection if needed
                  print('Selected account: ${selectedItem?.label}');
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  NotificationService.showNotification(
                    accountName:
                        widget.manager.walletData.data?.account.name ??
                        'Unknown',
                    title: 'Success!',
                    message: 'Your action was completed successfully.',
                    type: NotificationType.success,
                  );
                },
                child: const Text('Show Success Notification'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  NotificationService.showNotification(
                    accountName:
                        widget.manager.walletData.data?.account.name ??
                        'Unknown',
                    title: 'Warning!',
                    message: 'Please check your internet connection.',
                    type: NotificationType.warning,
                  );
                },
                child: const Text('Show Warning Notification'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  NotificationService.showNotification(
                    accountName:
                        widget.manager.walletData.data?.account.name ??
                        'Unknown',
                    title: 'Error!',
                    message: 'Something went wrong. Please try again.',
                    type: NotificationType.error,
                  );
                },
                child: const Text('Show Error Notification'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  // Add multiple notifications quickly
                  for (int i = 1; i <= 3; i++) {
                    NotificationService.showNotification(
                      accountName:
                          widget.manager.walletData.data?.account.name ??
                          'Unknown',
                      title: 'Notification $i',
                      message: 'This is notification number $i',
                    );
                  }
                },
                child: const Text('Add Multiple Notifications'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
