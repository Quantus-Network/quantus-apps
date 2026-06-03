import 'dart:async';
import 'dart:convert';

import 'package:async/async.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/notification_models.dart';
import 'package:resonance_network_wallet/providers/notification_config_provider.dart';
import 'package:resonance_network_wallet/services/local_notifications_service.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Maximum number of notifications to keep (FIFO)
const int maxNotifications = 64;

/// Key for storing notifications in shared preferences
const String notificationsStorageKey = 'notifications';

/// Notification provider that manages the notification state
final notificationProvider = StateNotifierProvider<NotificationNotifier, List<NotificationData>>((ref) {
  final localNotificationsService = ref.watch(localNotificationsServiceProvider);
  final notificationConfig = ref.watch(notificationConfigProvider);

  return NotificationNotifier(localNotificationsService, notificationConfig);
});

/// Notifier that manages notification state with persistence and streams
class NotificationNotifier extends StateNotifier<List<NotificationData>> {
  final LocalNotificationsService _localNotificationsService;
  final NotificationConfig _config;

  final Map<String, Timer> _scheduledTimers = {};

  NotificationNotifier(this._localNotificationsService, this._config) : super([]) {
    _initialize();
  }

  // Stream controllers for different notification sources
  final StreamController<NotificationData> _localAlertController = StreamController.broadcast();
  final StreamController<NotificationData> _localPushController = StreamController.broadcast();
  final StreamController<NotificationData> _remotePushController = StreamController.broadcast();

  // Timer for periodic cleanup of expired notifications
  Timer? _cleanupTimer;

  /// Combined stream of all notifications
  Stream<NotificationData> get notificationStream =>
      StreamGroup.merge([_localAlertController.stream, _localPushController.stream, _remotePushController.stream]);

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

  /// Check if notifications can be shown (OS + app level + notification type)
  Future<bool> canShowNotification(NotificationIntent type) async {
    // Check app-level master setting
    if (!_config.enabled) {
      quantusDebugPrint('Notifications disabled at app level');
      return false;
    }

    // Check specific notification type setting
    if (!_config.isIntentEnabled(type)) {
      quantusDebugPrint('Notification type ${type.name} is disabled');
      return false;
    }

    return true;
  }

  /// Check if any notifications can be shown (master check)
  Future<bool> canShowNotifications() async {
    if (!_config.enabled) {
      quantusDebugPrint('Notifications disabled at app level');
      return false;
    }

    return true;
  }

  /// Load notifications from shared preferences
  Future<void> _loadPersistedNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = prefs.getStringList(notificationsStorageKey) ?? [];

      final notifications = notificationsJson
          .map((json) => NotificationData.fromJson(jsonDecode(json)))
          .where((notification) => notification.persistent)
          .toList();

      if (mounted) {
        state = notifications;
      }
    } catch (e) {
      // If loading fails, start with empty state
      if (mounted) {
        state = [];
      }
    }
  }

  void _addNotificationImmediately(NotificationData notification) {
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
  }

  void _addNotificationOnSchedule(NotificationData notification) {
    final scheduledDate = notification.scheduledTime!;
    final duration = scheduledDate.difference(DateTime.now());

    quantusDebugPrint('DURATION ${scheduledDate.toString()}');

    // Schedule timer to show notification at the right time
    final timer = Timer(duration, () {
      _addNotificationImmediately(notification);
      _scheduledTimers.remove(notification.id);
    });

    _scheduledTimers[notification.id] = timer;
  }

  /// Save notifications to shared preferences
  Future<void> _saveNotifications() async {
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final notificationsJson = state
        .where((notification) => notification.persistent)
        .map((notification) => jsonEncode(notification.toJson()))
        .toList();

    await prefs.setStringList(notificationsStorageKey, notificationsJson);
  }

  /// Add a new notification
  Future<void> addNotification(NotificationData notification) async {
    if (!mounted) return;

    // Check if this specific notification intent can be shown
    if (!await canShowNotification(notification.intent)) {
      quantusDebugPrint('Cannot show ${notification.intent.name} notification: disabled or permission not granted');
      return;
    }

    if (notification.hasValidScheduleTime) {
      _addNotificationOnSchedule(notification);
    } else {
      _addNotificationImmediately(notification);
    }

    switch (notification.source) {
      case NotificationSource.local:
        // No need to handle, because it already shown by default when we added to the state array.
        break;
      case NotificationSource.push:
      case NotificationSource.remote:
        _localNotificationsService.showOrScheduleNotification(notification);
        break;
    }
  }

  Future<void> cancelNotification(String notificationId) async {
    final timer = _scheduledTimers.remove(notificationId);
    timer?.cancel();
    quantusDebugPrint('Cancelled scheduled notification: $notificationId');
  }

  Future<void> cancelAllNotifications() async {
    for (final timer in _scheduledTimers.values) {
      timer.cancel();
    }
    _scheduledTimers.clear();
    quantusDebugPrint('Cancelled all scheduled notifications');
  }

  List<String> getScheduledNotificationIds() {
    return _scheduledTimers.keys.toList();
  }

  /// Remove a notification by ID
  void removeNotification(String id) {
    if (!mounted) return;

    state = state.where((notification) => notification.id != id).toList();
    _saveNotifications();
  }

  /// Clear all notifications
  void clearAll() {
    if (!mounted) return;

    state = [];
    _saveNotifications();
  }

  /// Get notifications for a specific account
  List<NotificationData> getNotificationsForAccount(String accountId) {
    return state.where((notification) => notification.metadata?['accountId'] == accountId).toList();
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
    if (!mounted) return;

    final now = DateTime.now();
    final expiredIds = <String>[];

    for (final notification in state) {
      if (notification.expiryTime != null && notification.expiryTime!.isBefore(now)) {
        expiredIds.add(notification.id);
      }
    }

    if (expiredIds.isNotEmpty) {
      state = state.where((notification) => !expiredIds.contains(notification.id)).toList();
      _saveNotifications();
    }
  }

  /// Add convenience methods for specific notification types
  void addTransactionFailed({
    required Account? account,
    required String errorMessage,
    required PendingTransactionEvent transactionData,
  }) {
    final notification = NotificationTemplates.transactionFailed(
      account: account,
      transactionData: transactionData,
      errorMessage: errorMessage,
    );
    addNotification(notification);
  }

  void addBalanceLow({required Account? account}) {
    final notification = NotificationTemplates.balanceLow(account: account);
    addNotification(notification);
  }

  void addAccountAdded({required Account? account}) {
    final notification = NotificationTemplates.accountAdded(account: account);
    addNotification(notification);
  }

  void addReversibleTransactionReminder({required Account? account, required ReversibleTransferEvent transactionData}) {
    final notification = NotificationTemplates.reversibleTransactionReminder(
      account: account,
      transactionData: transactionData,
    );
    addNotification(notification);
  }

  void addTokenSent({required Account? account, required TransferEvent transactionData}) {
    final notification = NotificationTemplates.tokenSent(account: account, transactionData: transactionData);
    addNotification(notification);
  }

  void addTokenReceived({required Account? account, required TransferEvent transactionData}) {
    final notification = NotificationTemplates.tokenReceived(account: account, transactionData: transactionData);
    addNotification(notification);
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
