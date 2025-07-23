import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/features/components/notification_card.dart';
import 'package:resonance_network_wallet/services/notification_service.dart';

class NotificationGroup extends StatefulWidget {
  final List<NotificationData> notifications;
  final VoidCallback onDismissAll;
  final Function(String) onDismissSingle;

  const NotificationGroup({
    super.key,
    required this.notifications,
    required this.onDismissAll,
    required this.onDismissSingle,
  });

  @override
  State<NotificationGroup> createState() => _NotificationGroupState();
}

class _NotificationGroupState extends State<NotificationGroup>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.notifications.isEmpty) return const SizedBox.shrink();

    final reveresedNotifications = widget.notifications.reversed;

    return SlideTransition(
      position: _slideAnimation,
      child: Column(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: InkWell(
                  onTap: widget.onDismissAll,
                  child: const Text(
                    'Dismiss All',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
          SizedBox(
            height: MediaQuery.of(context).size.height - 380,
            child: SingleChildScrollView(
              child: Column(
                spacing: 24,
                children: reveresedNotifications
                    .map(
                      (notification) => NotificationCard(
                        notification: notification,
                        onDismiss: () =>
                            widget.onDismissSingle(notification.id),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
