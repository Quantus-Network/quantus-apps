import 'dart:async';
import 'dart:convert';

import 'package:async/async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/models/notification_models.dart';
import 'package:resonance_network_wallet/services/notification_scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Maximum number of notifications to keep (FIFO)
const int maxNotifications = 64;

/// Key for storing notifications in shared preferences
const String notificationsStorageKey = 'notifications';

/// Notification provider that manages the notification state
final notificationProvider =
    StateNotifierProvider<NotificationNotifier, List<NotificationData>>((ref) {
      return NotificationNotifier();
    });

/// Notifier that manages notification state with persistence and streams
class NotificationNotifier extends StateNotifier<List<NotificationData>> {
  NotificationNotifier() : super([]) {
    _initialize();
  }

  // Stream controllers for different notification sources
  final StreamController<NotificationData> _localAlertController =
      StreamController.broadcast();
  final StreamController<NotificationData> _localPushController =
      StreamController.broadcast();
  final StreamController<NotificationData> _remotePushController =
      StreamController.broadcast();

  // Timer for periodic cleanup of expired notifications
  Timer? _cleanupTimer;

  /// Combined stream of all notifications
  Stream<NotificationData> get notificationStream => StreamGroup.merge([
    _localAlertController.stream,
    _localPushController.stream,
    _remotePushController.stream,
  ]);

  /// Initialize the notifier by loading persisted notifications
  Future<void> _initialize() async {
    await _loadPersistedNotifications();
    _startCleanupTimer();
    _cleanupExpiredNotifications();
  }

  /// Start periodic cleanup timer
  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _cleanupExpiredNotifications();
    });
  }

  /// Load notifications from shared preferences
  Future<void> _loadPersistedNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson =
          prefs.getStringList(notificationsStorageKey) ?? [];

      final notifications = notificationsJson
          .map((json) => NotificationData.fromJson(jsonDecode(json)))
          .where((notification) => notification.persistent)
          .toList();

      state = notifications;
    } catch (e) {
      // If loading fails, start with empty state
      state = [];
    }
  }

  /// Save notifications to shared preferences
  Future<void> _saveNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final notificationsJson = state
        .where((notification) => notification.persistent)
        .map((notification) => jsonEncode(notification.toJson()))
        .toList();

    await prefs.setStringList(notificationsStorageKey, notificationsJson);
  }

  /// Add a new notification
  void addNotification(NotificationData notification) {
    // Enforce 64 notification limit (FIFO)
    if (state.length >= maxNotifications) {
      // Remove oldest notification
      state = state.sublist(1);
    }

    // Add new notification
    state = [...state, notification];

    // Save to persistence if persistent
    if (notification.persistent) {
      _saveNotifications();
    }

    // Send to appropriate stream
    _sendToStream(notification);

    // Schedule if needed
    scheduleIfNeeded(notification);
  }

  /// Remove a notification by ID
  void removeNotification(String id) {
    state = state.where((notification) => notification.id != id).toList();
    _saveNotifications();
  }

  /// Clear all notifications
  void clearAll() {
    state = [];
    _saveNotifications();
  }

  /// Get notifications for a specific account
  List<NotificationData> getNotificationsForAccount(String accountId) {
    return state
        .where(
          (notification) => notification.metadata?['accountId'] == accountId,
        )
        .toList();
  }

  /// Get notifications by type
  List<NotificationData> getNotificationsByType(NotificationType type) {
    return state.where((notification) => notification.type == type).toList();
  }

  /// Send notification to appropriate stream
  void _sendToStream(NotificationData notification) {
    switch (notification.source) {
      case NotificationSource.local:
        _localAlertController.add(notification);
        break;
      case NotificationSource.push:
        _localPushController.add(notification);
        break;
      case NotificationSource.remote:
        _remotePushController.add(notification);
        break;
    }
  }

  /// Clean up expired notifications
  void _cleanupExpiredNotifications() {
    final now = DateTime.now();
    final expiredIds = <String>[];

    for (final notification in state) {
      if (notification.expiryTime != null &&
          notification.expiryTime!.isBefore(now)) {
        expiredIds.add(notification.id);
      }
    }

    if (expiredIds.isNotEmpty) {
      state = state
          .where((notification) => !expiredIds.contains(notification.id))
          .toList();
      _saveNotifications();
    }
  }

  /// Add convenience methods for specific notification types
  void addTransactionFailed({
    required String accountName,
    required String transactionId,
    required String errorMessage,
    TransactionData? transactionData,
  }) {
    final notification = NotificationTemplates.transactionFailed(
      accountName: accountName,
      transactionId: transactionId,
      errorMessage: errorMessage,
      transactionData: transactionData,
    );
    addNotification(notification);
  }

  void addBalanceLow({required String accountName, required String accountId}) {
    final notification = NotificationTemplates.balanceLow(
      accountName: accountName,
      accountId: accountId,
    );
    addNotification(notification);
  }

  void addAccountAdded({
    required String accountName,
    required String accountId,
  }) {
    final notification = NotificationTemplates.accountAdded(
      accountName: accountName,
      accountId: accountId,
    );
    addNotification(notification);
  }

  void addReversibleTransactionReminder({
    required String accountName,
    required String transactionId,
    required DateTime executionTime,
  }) {
    final notification = NotificationTemplates.reversibleTransactionReminder(
      accountName: accountName,
      transactionId: transactionId,
      executionTime: executionTime,
    );
    addNotification(notification);
  }

  /// Stub for remote notifications (to be implemented later)
  void addRemoteNotification(NotificationData notification) {
    // This is a placeholder for future Firebase/APNs integration
    addNotification(notification.copyWith(source: NotificationSource.remote));
  }

  @override
  void dispose() {
    _cleanupTimer?.cancel();
    _localAlertController.close();
    _localPushController.close();
    _remotePushController.close();
    super.dispose();
  }
}
