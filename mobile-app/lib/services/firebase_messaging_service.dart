import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/notification_models.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/notification_provider.dart';
import 'package:resonance_network_wallet/services/transaction_service.dart';

/// Top-level handler for background/terminated FCM messages.
/// Must be a top-level function (not a class method) for Firebase.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background message: ${message.messageId}');
}

class FirebaseMessagingService {
  final Ref _ref;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final SenotiService _senotiService = SenotiService();

  bool _isInitialized = false;
  String? _cachedToken;

  FirebaseMessagingService(this._ref);

  String get _platform => Platform.operatingSystem;

  /// Returns the cached FCM device token, fetching from Firebase if not yet available.
  Future<String?> getDeviceToken() async {
    _cachedToken ??= await _messaging.getToken();
    debugPrint('FCM token: $_cachedToken');

    return _cachedToken;
  }

  /// Initialize FCM: request permissions, get token, and set up listeners.
  Future<void> init() async {
    if (_isInitialized) return;

    final authorizationStatus = await _requestPermission();
    if (authorizationStatus != AuthorizationStatus.authorized) {
      debugPrint('FCM permission not authorized');
      return;
    }

    await getDeviceToken();
    await registerDeviceIfPossible();

    _setupForegroundMessageListener();
    _setupTokenRefreshListener();
    _setupBackgroundMessageListener();

    _isInitialized = true;
  }

  /// Request notification permissions (required for iOS, Android 13+).
  Future<AuthorizationStatus> _requestPermission() async {
    final settings = await _messaging.requestPermission(alert: true, badge: true, sound: true, provisional: false);

    debugPrint('FCM permission status: ${settings.authorizationStatus}');

    if (Platform.isIOS) {
      await _messaging.setForegroundNotificationPresentationOptions(alert: false, badge: true, sound: false);
    }

    return settings.authorizationStatus;
  }

  Future<void> _tryRegisterDevice(String token) async {
    try {
      await _senotiService.registerDevice(token, _platform);
    } catch (e) {
      debugPrint('Failed to register device: $e');
    }
  }

  /// Register the device with the push notification backend.
  /// Call this after the user creates or imports a wallet for the first time.
  Future<void> registerDeviceIfPossible() async {
    final token = await getDeviceToken();
    if (token == null) {
      debugPrint('No FCM token available — skipping device registration');
      return;
    }
    await _tryRegisterDevice(token);
  }

  void _setupTokenRefreshListener() {
    _messaging.onTokenRefresh.listen((newToken) async {
      debugPrint('FCM token refreshed: $newToken');
      _cachedToken = newToken;
      await _tryRegisterDevice(newToken);
    });
  }

  /// Unregister this device from push notifications (e.g. on wallet reset/logout).
  Future<void> unregisterDevice() async {
    final token = await getDeviceToken();
    if (token == null) {
      debugPrint('No FCM token available — skipping unregister');
      return;
    }
    try {
      await _senotiService.unregisterDevice(token, _platform);
    } catch (e) {
      debugPrint('Failed to unregister device: $e');
    }
  }

  /// Register a newly created address for push notifications on this device.
  Future<void> insertNewAddress(String newAddress) async {
    final token = await getDeviceToken();
    if (token == null) {
      debugPrint('No FCM token available — skipping insertNewAddress');
      return;
    }

    try {
      await _senotiService.insertNewAddress(newAddress: newAddress, deviceToken: token);
    } catch (e) {
      debugPrint('Failed to insert new address: $e');
    }
  }

  /// Listen for messages when the app is in the foreground.
  /// FCM does NOT show a system notification in this case, so we convert
  /// the message to a NotificationData and show it via local notifications.
  void _setupForegroundMessageListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('FCM foreground message: ${message.messageId}');

      final notification = _remoteMessageToNotificationData(message);
      if (notification == null) return;

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
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('FCM notification tapped (background): ${message.messageId}');
      _handleNotificationTap(message, navigatorKey);
    });

    _handleInitialMessage(navigatorKey);
  }

  Future<void> _handleInitialMessage(GlobalKey<NavigatorState> navigatorKey) async {
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('FCM initial message (terminated): ${initialMessage.messageId}');
      _handleNotificationTap(initialMessage, navigatorKey);
    }
  }

  void _handleNotificationTap(RemoteMessage message, GlobalKey<NavigatorState> navigatorKey) {
    final data = message.data;
    if (data.isEmpty) return;

    final txService = _ref.read(transactionServiceProvider);
    txService.navigateToTransactionFromPayloadIfPossible(data, navigatorKey);
  }

  NotificationData? _remoteMessageToNotificationData(RemoteMessage message) {
    final data = message.data;

    final txService = _ref.read(transactionServiceProvider);
    final event = txService.deserializeTxEventFromJsonIfPossible(data);
    if (event == null) return null;

    if (event is TransferEvent) {
      final account = _ref.read(accountsProvider.notifier).getAccountWithId(event.to);
      return NotificationTemplates.tokenReceived(account: account, transactionData: event);
    } else if (event is ReversibleTransferEvent) {
      final account = _ref.read(accountsProvider.notifier).getAccountWithId(event.to);
      return NotificationTemplates.reversibleTransactionReminder(account: account, transactionData: event);
    }

    return null;
  }
}

final firebaseMessagingServiceProvider = Provider<FirebaseMessagingService>((ref) {
  return FirebaseMessagingService(ref);
});
