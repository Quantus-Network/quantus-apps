import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/notification_models.dart';
import 'package:resonance_network_wallet/providers/notification_provider.dart';
import 'package:resonance_network_wallet/services/transaction_service.dart';

/// Top-level handler for background/terminated FCM messages.
/// Must be a top-level function (not a class method) for Firebase.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background messages are automatically shown by the OS as notifications.
  // No additional handling is needed here unless you want to persist data.
  debugPrint('FCM background message: ${message.messageId}');
}

class FirebaseMessagingService {
  final Ref _ref;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final SenotiService _senotiService = SenotiService();

  bool _isInitialized = false;

  FirebaseMessagingService(this._ref);

  /// Initialize FCM: request permissions, get token, and set up listeners.
  Future<void> init() async {
    if (_isInitialized) return;

    final authorizationStatus = await _requestPermission();
    if (authorizationStatus != AuthorizationStatus.authorized) {
      debugPrint('FCM permission not authorized');
      return;
    }

    await _getToken();

    _setupForegroundMessageListener();
    _setupTokenRefreshListener();
    _setupBackgroundMessageListener();

    _isInitialized = true;
  }

  /// Request notification permissions (required for iOS, Android 13+).
  Future<AuthorizationStatus> _requestPermission() async {
    final settings = await _messaging.requestPermission(alert: true, badge: true, sound: true, provisional: false);

    debugPrint('FCM permission status: ${settings.authorizationStatus}');

    // On iOS, set foreground notification presentation options.
    // This tells iOS to NOT show the system banner when the app is in the
    // foreground, because we handle it ourselves via local notifications.
    if (Platform.isIOS) {
      await _messaging.setForegroundNotificationPresentationOptions(alert: false, badge: true, sound: false);
    }

    return settings.authorizationStatus;
  }

  Future<void> _registerDevice(String token) async {
    try {
      await _senotiService.registerDevice(token, Platform.operatingSystem);
    } catch (e) {
      debugPrint('Failed to register device: $e');
    }
  }

  /// Get the FCM device token (useful for server-side targeting).
  Future<void> _getToken() async {
    final token = await _messaging.getToken();
    debugPrint('FCM token: $token');

    if (token != null && token.isNotEmpty) {
      await _registerDevice(token);
    }
  }

  /// Listen for token refresh events.
  void _setupTokenRefreshListener() {
    _messaging.onTokenRefresh.listen((newToken) async {
      debugPrint('FCM token refreshed: $newToken');

      await _registerDevice(newToken);
    });
  }

  /// Listen for messages when the app is in the foreground.
  /// FCM does NOT show a system notification in this case, so we convert
  /// the message to a NotificationData and show it via local notifications.
  void _setupForegroundMessageListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('FCM foreground message: ${message.messageId}');

      final notification = _remoteMessageToNotificationData(message);
      if (notification == null) return;

      // Add to the notification provider (persists + sends to stream).
      final notifier = _ref.read(notificationProvider.notifier);
      notifier.addNotification(notification);
    });
  }

  void _setupBackgroundMessageListener() {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  /// Handle the user tapping on an FCM notification that launched/resumed the app.
  /// Call this after the navigator key is available.
  void setupNotificationTapHandlers(GlobalKey<NavigatorState> navigatorKey) {
    // Handle tap when app was in background (not terminated).
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('FCM notification tapped (background): ${message.messageId}');
      _handleNotificationTap(message, navigatorKey);
    });

    // Handle tap when app was terminated.
    _handleInitialMessage(navigatorKey);
  }

  /// Check if the app was launched from a terminated state by tapping an FCM notification.
  Future<void> _handleInitialMessage(GlobalKey<NavigatorState> navigatorKey) async {
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('FCM initial message (terminated): ${initialMessage.messageId}');
      _handleNotificationTap(initialMessage, navigatorKey);
    }
  }

  /// Navigate based on the FCM message data payload.
  void _handleNotificationTap(RemoteMessage message, GlobalKey<NavigatorState> navigatorKey) {
    final data = message.data;
    if (data.isEmpty) return;

    final txService = _ref.read(transactionServiceProvider);
    txService.navigateToTransactionFromPayloadIfPossible(data, navigatorKey);
  }

  /// Convert an FCM [RemoteMessage] into the app's [NotificationData] model.
  NotificationData? _remoteMessageToNotificationData(RemoteMessage message) {
    final notification = message.notification;
    final data = message.data;

    final title = notification?.title ?? data['title'] as String? ?? 'Notification';
    final body = notification?.body ?? data['body'] as String? ?? '';

    // Parse optional fields from the data payload.
    final accountId = data['accountId'] as String? ?? '';
    final accountName = data['accountName'] as String? ?? '';
    final typeStr = data['type'] as String?;
    final intentStr = data['intent'] as String?;

    final type = NotificationType.values.firstWhere((e) => e.name == typeStr, orElse: () => NotificationType.info);

    final intent = NotificationIntent.values.firstWhere(
      (e) => e.name == intentStr,
      orElse: () => NotificationIntent.others,
    );

    // Build metadata from the data payload (excluding fields we already extracted).
    final metadata = Map<String, dynamic>.from(data)
      ..remove('title')
      ..remove('body')
      ..remove('accountId')
      ..remove('accountName')
      ..remove('type')
      ..remove('intent');

    return NotificationData(
      id: 'remote_${message.messageId ?? DateTime.now().millisecondsSinceEpoch}',
      accountId: accountId,
      type: type,
      intent: intent,
      source: NotificationSource.remote,
      title: title,
      message: body,
      accountName: accountName,
      timestamp: DateTime.now(),
      persistent: true,
      metadata: metadata.isNotEmpty ? metadata : null,
    );
  }
}

final firebaseMessagingServiceProvider = Provider<FirebaseMessagingService>((ref) {
  return FirebaseMessagingService(ref);
});
