import 'package:flutter/material.dart';

class NotificationService extends ChangeNotifier {
  final List<NotificationData> _activeNotifications = [];

  List<NotificationData> get activeNotifications =>
      List.unmodifiable(_activeNotifications);

  void addNotification({
    String? id,
    required String accountName,
    required String title,
    required String message,
    NotificationType type = NotificationType.info,
    VoidCallback? onViewDetails,
  }) {
    final notificationData = NotificationData(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      accountName: accountName,
      title: title,
      message: message,
      type: type,
      timestamp: DateTime.now(),
      onViewDetails: onViewDetails,
    );

    _activeNotifications.add(notificationData);
    notifyListeners(); // This triggers UI updates
  }

  void removeNotification(String id) {
    _activeNotifications.removeWhere((data) => data.id == id);
    notifyListeners();
  }

  void clearAll() {
    _activeNotifications.clear();
    notifyListeners();
  }
}

class NotificationData {
  final String id;
  final NotificationType type;
  final String accountName;
  final String title;
  final String message;
  final VoidCallback? onViewDetails;
  final DateTime timestamp;

  NotificationData({
    required this.id,
    required this.timestamp,
    this.type = NotificationType.info,
    required this.accountName,
    required this.title,
    required this.message,
    this.onViewDetails,
  });
}

enum NotificationType { info, success, warning, error }
