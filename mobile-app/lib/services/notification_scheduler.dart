import 'dart:async';
import 'package:resonance_network_wallet/models/notification_models.dart';
import 'package:resonance_network_wallet/providers/notification_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stub service for scheduling local push notifications
class NotificationScheduler {
  static final _instance = NotificationScheduler._internal();
  factory NotificationScheduler() => _instance;
  NotificationScheduler._internal();

  final Map<String, Timer> _scheduledTimers = {};
  bool _initialized = false;

  /// Initialize the notification scheduler
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    print('NotificationScheduler initialized (stub implementation)');
  }

  /// Schedule a notification for a specific time
  Future<void> scheduleNotification(NotificationData notification) async {
    if (!_initialized) await initialize();
    if (notification.scheduledTime == null) return;

    final scheduledDate = notification.scheduledTime!;
    if (scheduledDate.isBefore(DateTime.now())) return;

    final duration = scheduledDate.difference(DateTime.now());

    // Schedule timer to show notification at the right time
    final timer = Timer(duration, () {
      _showScheduledNotification(notification);
      _scheduledTimers.remove(notification.id);
    });

    _scheduledTimers[notification.id] = timer;
    print('Scheduled notification: ${notification.title} for $scheduledDate');
  }

  /// Cancel a scheduled notification
  Future<void> cancelNotification(String notificationId) async {
    final timer = _scheduledTimers.remove(notificationId);
    timer?.cancel();
    print('Cancelled scheduled notification: $notificationId');
  }

  /// Cancel all scheduled notifications
  Future<void> cancelAllNotifications() async {
    for (final timer in _scheduledTimers.values) {
      timer.cancel();
    }
    _scheduledTimers.clear();
    print('Cancelled all scheduled notifications');
  }

  /// Show scheduled notification (stub - would show local push notification)
  void _showScheduledNotification(NotificationData notification) {
    print('🔔 SCHEDULED NOTIFICATION: ${notification.title}');
    print('   Message: ${notification.message}');
    print('   Account: ${notification.accountName}');

    // For now, this just prints to console
  }

  /// Show immediate notification (for testing)
  Future<void> showImmediateNotification(NotificationData notification) async {
    if (!_initialized) await initialize();

    print('🔔 IMMEDIATE NOTIFICATION: ${notification.title}');
    print('   Message: ${notification.message}');
    print('   Account: ${notification.accountName}');
  }

  /// Get list of scheduled notification IDs
  List<String> getScheduledNotificationIds() {
    return _scheduledTimers.keys.toList();
  }
}

/// Provider for notification scheduler
final notificationSchedulerProvider = Provider<NotificationScheduler>((ref) {
  return NotificationScheduler();
});

/// Extension to integrate scheduler with notification provider
extension NotificationSchedulerExtension on NotificationNotifier {
  /// Schedule a notification if it has a scheduled time
  void scheduleIfNeeded(NotificationData notification) {
    if (notification.scheduledTime != null) {
      // Get scheduler from provider context
      final scheduler = NotificationScheduler();
      scheduler.scheduleNotification(notification);
    }
  }
}
