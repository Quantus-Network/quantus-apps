import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/notification_models.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/notification_provider.dart';
import 'package:resonance_network_wallet/providers/remote_config_provider.dart';
import 'package:resonance_network_wallet/services/history_polling_manager.dart';
import 'package:resonance_network_wallet/services/telemetry_service.dart';
import 'package:resonance_network_wallet/services/transaction_service.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';

/// Top-level handler for background/terminated FCM messages.
/// Must be a top-level function (not a class method) for Firebase.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  quantusDebugPrint('FCM background message: ${message.messageId}');
}

class FirebaseMessagingService {
  final Ref _ref;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final SenotiService _senotiService = SenotiService();

  bool _isInitialized = false;
  bool _hasRegisteredHandlers = false;
  String? _cachedToken;

  FirebaseMessagingService(this._ref);

  String get _platform => Platform.operatingSystem;

  /// Returns the cached FCM device token, fetching from Firebase if not yet available.
  Future<String?> getDeviceToken() async {
    if (_cachedToken != null) return _cachedToken;

    try {
      _cachedToken = await _messaging.getToken();
      quantusDebugPrint('FCM token: $_cachedToken');
    } catch (e, st) {
      quantusDebugPrint('Failed to get FCM device token: $e');
      TelemetryService().sendError('fcm_get_device_token_failed', error: e, stackTrace: st);
    }

    return _cachedToken;
  }

  /// Initialize FCM: request permissions, get token, and set up listeners.
  Future<void> init() async {
    if (_isInitialized) return;

    final authorizationStatus = await _requestPermission();
    if (authorizationStatus != AuthorizationStatus.authorized) {
      quantusDebugPrint('FCM permission not authorized');
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

    quantusDebugPrint('FCM permission status: ${settings.authorizationStatus}');

    if (Platform.isIOS) {
      await _messaging.setForegroundNotificationPresentationOptions(alert: false, badge: true, sound: false);
    }

    return settings.authorizationStatus;
  }

  Future<void> _tryRegisterDevice(String token) async {
    try {
      await _senotiService.registerDevice(token, _platform);
    } catch (e) {
      quantusDebugPrint('Failed to register device: $e');
    }
  }

  /// Register the device with the push notification backend.
  /// Call this after the user creates or imports a wallet for the first time.
  Future<void> registerDeviceIfPossible() async {
    final token = await getDeviceToken();
    if (token == null) {
      quantusDebugPrint('No FCM token available — skipping device registration');
      return;
    }
    await _tryRegisterDevice(token);
  }

  void _setupTokenRefreshListener() {
    _messaging.onTokenRefresh.listen((newToken) async {
      quantusDebugPrint('FCM token refreshed: $newToken');
      _cachedToken = newToken;
      await _tryRegisterDevice(newToken);
    });
  }

  /// Unregister this device from push notifications (e.g. on wallet reset/logout).
  Future<void> unregisterDevice() async {
    final token = await getDeviceToken();
    if (token == null) {
      quantusDebugPrint('No FCM token available — skipping unregister');
      return;
    }
    try {
      await _senotiService.unregisterDevice(token, _platform);
      _cachedToken = null;
    } catch (e) {
      quantusDebugPrint('Failed to unregister device: $e');
    }
  }

  /// Register a newly created address for push notifications on this device.
  Future<void> insertNewAddress(String newAddress) async {
    final token = await getDeviceToken();
    if (token == null) {
      quantusDebugPrint('No FCM token available — skipping insertNewAddress');
      return;
    }

    try {
      await _senotiService.insertNewAddress(newAddress: newAddress, deviceToken: token);
    } catch (e) {
      quantusDebugPrint('Failed to insert new address: $e');
    }
  }

  /// Listen for messages when the app is in the foreground.
  /// FCM does NOT show a system notification in this case, so we convert
  /// the message to a NotificationData and show it via local notifications.
  ///
  /// Background/terminated resume is already covered by the app lifecycle
  /// manager (silent refresh on resume), so here we only refresh historical
  /// data (balance, activity, proposals) for the foreground case.
  void _setupForegroundMessageListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      quantusDebugPrint('FCM foreground message: ${message.messageId}');

      unawaited(_ref.read(historyPollingManagerProvider).triggerSilentRefresh());

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
  void setupNotificationTapHandlers() {
    if (_hasRegisteredHandlers) return;
    _hasRegisteredHandlers = true;

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      quantusDebugPrint('FCM notification tapped (background): ${message.messageId}');
      _handleNotificationTap(message);
    });

    _handleInitialMessage();
  }

  Future<void> _handleInitialMessage() async {
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      quantusDebugPrint('FCM initial message (terminated): ${initialMessage.messageId}');
      _handleNotificationTap(initialMessage);
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;

    quantusDebugPrint('FCM tap payload: $data');

    if (data.isEmpty) return;

    final txService = _ref.read(transactionServiceProvider);

    if (txService.navigateToProposalFromPayloadIfPossible(data)) return;
    txService.navigateToTransactionFromPayloadIfPossible(data);
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

/// Best-effort push-notification registration for onboarding entry points.
///
/// This must never block or abort wallet creation/import. Reading
/// [firebaseMessagingServiceProvider] constructs a [FirebaseMessagingService],
/// whose field initializer touches `FirebaseMessaging.instance` synchronously;
/// that throws when Firebase has not been initialized yet (it is initialized
/// lazily once remote notifications are enabled). Tapping immediately after
/// launch could therefore throw and skip navigation, so the provider read and
/// every subsequent call are wrapped here and all failures are swallowed.
///
/// When [insertAddress] is non-null, the address is registered for push
/// notifications on the existing device; otherwise the device itself is
/// registered for the first time.
Future<void> registerForRemoteNotificationsBestEffort(WidgetRef ref, {String? insertAddress}) async {
  try {
    if (!ref.read(remoteConfigProvider).enableRemoteNotifications) return;
    final service = ref.read(firebaseMessagingServiceProvider);
    if (insertAddress != null) {
      await service.insertNewAddress(insertAddress);
    } else {
      await service.registerDeviceIfPossible();
    }
  } catch (e) {
    quantusDebugPrint('Failed to register for remote notifications: $e');
    TelemetryService().sendError('registerForRemoteNotifications', error: e, stackTrace: StackTrace.current);
  }
}
