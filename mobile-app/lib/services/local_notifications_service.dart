import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wallet_core/models/notification_models.dart';
import 'package:wallet_core/services/local_notifications.dart';
import 'package:wallet_core/providers/route_intent_providers.dart';
import 'package:resonance_network_wallet/services/swap_live_activity.dart';
import 'package:resonance_network_wallet/services/telemetry_service.dart';
import 'package:wallet_core/services/transaction_service.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class LocalNotificationsService implements LocalNotifications {
  final Ref _ref;

  LocalNotificationsService(this._ref);

  final _notificationPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  final StreamController<String?> _onNotificationClick = StreamController<String?>.broadcast();

  void _onDidReceiveNotificationResponse(NotificationResponse response) {
    _onNotificationClick.add(response.payload);
  }

  NotificationDetails _notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'local_channel_id',
        'Local Notification',
        channelDescription: 'Wallet notification channel',
        importance: Importance.high,
        priority: Priority.high,
        // Do not reveal any part of the notification on a secure lock screen: titles/bodies
        // contain transaction amounts and addresses (security audit finding L14).
        visibility: NotificationVisibility.secret,
      ),
      iOS: DarwinNotificationDetails(),
    );
  }

  Future<void> init() async {
    if (_isInitialized) return;

    // Set up timezone database for scheduled notifications. Failures here (e.g. unrecognized
    // device timezone identifier) must not prevent notifications or the rest of app startup.
    try {
      tz_data.initializeTimeZones();
      final currentTimeZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(currentTimeZone.identifier));
    } catch (e) {
      quantusPrint('Failed to set device timezone: "$e". Falling back to UTC for notifications.');
      try {
        tz_data.initializeTimeZones();
        tz.setLocalLocation(tz.UTC);
      } catch (err) {
        // Last resort: proceed without proper tz; scheduled notifs may not work but app continues.
        quantusPrint('Last resort failed to set device timezone to UTC: "$err".');
      }
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _notificationPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
    );

    // It will show the permission pop-up on Android.
    // It does nothing on older Android versions or iOS.
    if (Platform.isAndroid) {
      await _notificationPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    _isInitialized = true;
  }

  // This is for handling when app is in terminated state then launched by tapping notification.
  Future<void> handleLaunchByNotification() async {
    final notificationAppLaunchDetails = await _notificationPlugin.getNotificationAppLaunchDetails();
    if (notificationAppLaunchDetails?.didNotificationLaunchApp != true) return;

    final payload = notificationAppLaunchDetails!.notificationResponse?.payload;
    _dispatchNotificationPayload(
      payload,
      logLabel: 'Error decoding payload handle launch by notification',
      failureEvent: 'Error decoding notification launch payload',
    );
  }

  /// Shows the swap as a normal notification. The same id replaces the previous
  /// one, and a tap carries [swapLiveNotificationPayload].
  Future<void> showSwapProgress(SwapLiveActivityContent content) async {
    await init();
    final copy = swapLiveNotificationCopy(content);
    await _notificationPlugin.show(
      id: swapLiveNotificationId,
      title: copy.title,
      body: copy.body,
      notificationDetails: NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: false,
          presentList: true,
          presentSound: false,
          presentBadge: false,
          subtitle: copy.subtitle,
          threadIdentifier: 'swap_live_activity',
          interruptionLevel: InterruptionLevel.passive,
        ),
      ),
      payload: swapLiveNotificationPayload,
    );
  }

  Future<void> cancelSwapProgress() async {
    await init();
    await _notificationPlugin.cancel(id: swapLiveNotificationId);
  }

  void _dispatchNotificationPayload(String? payload, {required String logLabel, required String failureEvent}) {
    if (payload == null || payload.isEmpty) return;
    try {
      switch (routeLocalNotificationTap(payload)) {
        case LocalNotificationSwapTap():
          _ref.read(swapProgressIntentProvider.notifier).state = true;
        case LocalNotificationTransactionTap(:final json):
          _ref.read(transactionServiceProvider).navigateToTransactionFromPayloadIfPossible(json);
      }
    } catch (e) {
      quantusPrint('$logLabel: $e');
      TelemetryService().sendError(failureEvent, error: e);
    }
  }

  Future<void> _showNotification(NotificationData notification) async {
    final String? payload = notification.metadata != null ? jsonEncode(notification.metadata) : null;
    return _notificationPlugin.show(
      id: notification.id.hashCode,
      title: notification.title,
      body: notification.message,
      notificationDetails: _notificationDetails(),
      payload: payload,
    );
  }

  Future<void> _scheduleNotification(NotificationData notification) async {
    final remindAt = notification.scheduledTime ?? DateTime.now();
    final now = tz.TZDateTime.now(tz.local);

    tz.TZDateTime scheduledDate = tz.TZDateTime.from(remindAt, tz.local);

    // Ensure the scheduled date is in the future
    if (scheduledDate.isBefore(now)) {
      scheduledDate = now.add(Duration(seconds: NotificationTemplates.scheduleTimeBufferInSeconds));
    }

    final String? payload = notification.metadata != null ? jsonEncode(notification.metadata) : null;

    await _notificationPlugin.zonedSchedule(
      id: notification.id.hashCode,
      title: notification.title,
      body: notification.message,
      scheduledDate: scheduledDate,
      notificationDetails: _notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  @override
  Future<void> showOrScheduleNotification(NotificationData notification) async {
    if (notification.hasValidScheduleTime) {
      _scheduleNotification(notification);
    } else {
      _showNotification(notification);
    }
  }

  void setupNotificationsClickListener() {
    _onNotificationClick.stream.listen((payload) {
      _dispatchNotificationPayload(
        payload,
        logLabel: 'Error decoding payload setup notifications click listener',
        failureEvent: 'Error decoding notification click payload',
      );
    });
  }

  Future<void> cancelNotification(int id) async {
    await _notificationPlugin.cancel(id: id);
  }

  Future<void> cancelAllNotifications() async {
    await _notificationPlugin.cancelAll();
  }

  void dispose() {
    _onNotificationClick.close();
  }
}

final localNotificationsServiceProvider = Provider<LocalNotificationsService>((ref) {
  return LocalNotificationsService(ref);
});

/// The iOS notification used when a Live Activity cannot run.
class LocalSwapLiveNotificationPoster implements SwapLiveNotificationPoster {
  final LocalNotificationsService _service;

  LocalSwapLiveNotificationPoster(this._service);

  @override
  Future<void> show(SwapLiveActivityContent content) => _service.showSwapProgress(content);

  @override
  Future<void> cancel() => _service.cancelSwapProgress();
}
