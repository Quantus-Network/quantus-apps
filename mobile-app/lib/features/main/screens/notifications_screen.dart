import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/features/components/base_with_background.dart';
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
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                NotificationService.showNotification(
                  title: 'Success!',
                  message: 'Your action was completed successfully.',
                  backgroundColor: Colors.green,
                  icon: Icons.check_circle,
                );
              },
              child: const Text('Show Success Notification'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                NotificationService.showNotification(
                  title: 'Warning!',
                  message: 'Please check your internet connection.',
                  backgroundColor: Colors.orange,
                  icon: Icons.warning,
                );
              },
              child: const Text('Show Warning Notification'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                NotificationService.showNotification(
                  title: 'Error!',
                  message: 'Something went wrong. Please try again.',
                  backgroundColor: Colors.red,
                  icon: Icons.error,
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
                    title: 'Notification $i',
                    message: 'This is notification number $i',
                    backgroundColor: Colors.blue,
                    icon: Icons.info,
                  );
                }
              },
              child: const Text('Add Multiple Notifications'),
            ),
          ],
        ),
      ),
    );
  }
}
