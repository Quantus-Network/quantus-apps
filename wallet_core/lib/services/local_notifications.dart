import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wallet_core/models/notification_models.dart';
import 'package:wallet_core/utils/unbound_seam.dart';

/// Shows system notifications. Each app binds its own implementation through
/// `walletCoreOverrides`, because the notification plugin and its setup differ
/// per platform.
abstract interface class LocalNotifications {
  /// Shows [notification] now, or at its schedule time when it has a valid one.
  Future<void> showOrScheduleNotification(NotificationData notification);
}

final localNotificationsProvider = Provider<LocalNotifications>(
  (ref) => throw unboundSeam('localNotificationsProvider'),
);
