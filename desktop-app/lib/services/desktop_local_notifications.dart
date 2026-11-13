import 'package:wallet_core/models/notification_models.dart';
import 'package:wallet_core/services/local_notifications.dart';

/// Desktop notifications have not been built yet.
///
/// Showing one fails, so the first desktop feature that notifies the user
/// forces the implementation instead of silently dropping the notification.
class DesktopLocalNotifications implements LocalNotifications {
  const DesktopLocalNotifications();

  @override
  Future<void> showOrScheduleNotification(NotificationData notification) async =>
      throw UnimplementedError('Desktop local notifications are not implemented.');
}
