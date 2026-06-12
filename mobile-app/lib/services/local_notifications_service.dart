import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/models/notification_models.dart';
import 'package:resonance_network_wallet/services/telemetry_service.dart';
import 'package:resonance_network_wallet/services/transaction_service.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
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

    // Set up timezone database for scheduled notifications. Failures here (e.g. unrecognized
    // device timezone identifier) must not prevent notifications or the rest of app startup.
    try {
      tz_data.initializeTimeZones();
      final currentTimeZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(currentTimeZone.identifier));
    } catch (e) {
      debugPrint('Failed to set device timezone: "$e". Falling back to UTC for notifications.');
      try {
        tz_data.initializeTimeZones();
        tz.setLocalLocation(tz.UTC);
      } catch (err) {
        // Last resort: proceed without proper tz; scheduled notifs may not work but app continues.
        debugPrint('Last resort failed to set device timezone to UTC: "$err".');
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
    if (payload == null || payload.isEmpty) return;

    final txService = _ref.read(transactionServiceProvider);
    try {
      final json = jsonDecode(payload);
      txService.navigateToTransactionFromPayloadIfPossible(json);
    } catch (e) {
      debugPrint('Error decoding payload handle launch by notification: $e');
      TelemetryService().sendError(
        'Error decoding notification launch payload',
        error: e.runtimeType.toString(),
        stackTrace: StackTrace.current,
      );
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

  Future<void> showOrScheduleNotification(NotificationData notification) async {
    if (notification.hasValidScheduleTime) {
      _scheduleNotification(notification);
    } else {
      _showNotification(notification);
    }
  }

  void setupNotificationsClickListener() {
    _onNotificationClick.stream.listen((payload) {
      if (payload == null || payload.isEmpty) return;

      final txService = _ref.read(transactionServiceProvider);

      try {
        final json = jsonDecode(payload);
        txService.navigateToTransactionFromPayloadIfPossible(json);
      } catch (e) {
        debugPrint('Error decoding payload setup notifications click listener: $e');
        TelemetryService().sendError(
          'Error decoding notification click payload',
          error: e.runtimeType.toString(),
          stackTrace: StackTrace.current,
        );
      }
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
