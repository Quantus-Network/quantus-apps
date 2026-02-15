import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/models/notification_models.dart';
import 'package:resonance_network_wallet/services/transaction_service.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

class LocalNotificationsService {
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
      ),
      iOS: DarwinNotificationDetails(),
    );
  }

  Future<void> init() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();
    final currentTimeZone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(currentTimeZone.identifier));

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _notificationPlugin.initialize(
      initSettings,
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
  Future<void> handleLaunchByNotification(GlobalKey<NavigatorState> navigatorKey) async {
    final notificationAppLaunchDetails = await _notificationPlugin.getNotificationAppLaunchDetails();
    if (notificationAppLaunchDetails?.didNotificationLaunchApp != true) return;

    final payload = notificationAppLaunchDetails!.notificationResponse?.payload;
    if (payload == null || payload.isEmpty) return;

    final txService = _ref.read(transactionServiceProvider);
    final json = jsonDecode(payload);

    txService.navigateToTransactionFromPayloadIfPossible(json, navigatorKey);
  }

  Future<void> _showNotification(NotificationData notification) async {
    final String? payload = notification.metadata != null ? jsonEncode(notification.metadata) : null;
    return _notificationPlugin.show(
      notification.id.hashCode,
      notification.title,
      notification.message,
      _notificationDetails(),
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
      notification.id.hashCode,
      notification.title,
      notification.message,
      scheduledDate,
      _notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  Future<void> showOrScheduleNotification(NotificationData notification) async {
    if (notification.hasValidScheduleTime) {
      _scheduleNotification(notification);
    } else {
      _showNotification(notification);
    }
  }

  void setupNotificationsClickListener(GlobalKey<NavigatorState> navigatorKey) {
    _onNotificationClick.stream.listen((payload) {
      if (payload == null || payload.isEmpty) return;

      final txService = _ref.read(transactionServiceProvider);
      final json = jsonDecode(payload);

      txService.navigateToTransactionFromPayloadIfPossible(json, navigatorKey);
    });
  }

  Future<void> cancelNotification(int id) async {
    await _notificationPlugin.cancel(id);
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
