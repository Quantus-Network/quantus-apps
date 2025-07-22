// import 'dart:async';
import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/features/components/notification_group.dart';

class NotificationService {
  static final List<NotificationData> _activeNotifications = [];
  static OverlayState? _overlayState;
  static OverlayEntry? _groupOverlay;

  static void initialize(OverlayState overlayState) {
    _overlayState = overlayState;
  }

  static void showNotification({
    required String accountName,
    required String title,
    required String message,
    NotificationType type = NotificationType.info,
  }) {
    if (_overlayState == null) return;

    final notificationData = NotificationData(
      id: _activeNotifications.length.toString(),
      accountName: accountName,
      title: title,
      message: message,
      type: type,
      timestamp: DateTime.now(),
    );

    _activeNotifications.add(notificationData);
    _showGroupOverlay();

    // // Auto-dismiss after duration
    // Timer(duration, () {
    //   _removeNotification(notificationData.id);
    // });
  }

  static void _showGroupOverlay() {
    if (_groupOverlay != null) {
      _groupOverlay!.markNeedsBuild();
      return;
    }

    _groupOverlay = OverlayEntry(
      builder: (context) => NotificationGroup(
        notifications: _activeNotifications,
        onDismissAll: _dismissAll,
        onDismissSingle: _removeNotification,
      ),
    );

    _overlayState!.insert(_groupOverlay!);
  }

  static void _removeNotification(String id) {
    _activeNotifications.removeWhere((data) => data.id == id);

    if (_activeNotifications.isEmpty) {
      _hideGroupOverlay();
    } else {
      _groupOverlay?.markNeedsBuild();
    }
  }

  static void _dismissAll() {
    _activeNotifications.clear();
    _hideGroupOverlay();
  }

  static void _hideGroupOverlay() {
    _groupOverlay?.remove();
    _groupOverlay = null;
  }

  static void clearAll() {
    _dismissAll();
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
