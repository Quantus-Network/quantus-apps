import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The system's notifications, as the app uses them. The plugin sits behind
/// this so that tests can stand in for the system.
abstract interface class NotificationPlugin {
  /// Starts the system's notifications with [settings], calling [onClick]
  /// with a notification's payload when the person clicks it. Throws when the
  /// system's notification service does not start.
  Future<void> initialize(InitializationSettings settings, {required void Function(String? payload) onClick});

  /// The payload of the notification whose click launched the app, if one
  /// did. Such a click comes before the app has started its notifications,
  /// so it never reaches [initialize]'s `onClick`.
  Future<String?> launchPayload();

  /// Asks macOS whether the app may show notifications, with sounds and a
  /// badge. Returns whether it may. macOS asks the person only the first
  /// time; after that it answers with what they chose.
  Future<bool> requestMacOSPermission();

  /// Whether macOS lets the app show notifications right now. Unlike
  /// [requestMacOSPermission], this never asks the person.
  Future<bool> isMacOSPermissionGranted();

  /// Shows a notification now. One shown with the same [id] replaces it.
  Future<void> show({required int id, required String title, required String body, required String payload});

  /// Removes every notification of the app the system still shows. Throws on
  /// Windows and Linux when the notifications have not been started.
  Future<void> cancelAll();
}

/// The system's notifications through flutter_local_notifications.
class SystemNotificationPlugin implements NotificationPlugin {
  final _plugin = FlutterLocalNotificationsPlugin();

  @override
  Future<void> initialize(InitializationSettings settings, {required void Function(String? payload) onClick}) async {
    final started = await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) => onClick(response.payload),
    );
    // Null: the plugin has nothing for this platform.
    if (started == null) throw StateError('There are no system notifications on $defaultTargetPlatform');
    // On macOS the answer is whether permission was granted, which starting
    // does not ask for; Windows and Linux answer whether their service started.
    if (!started && defaultTargetPlatform != TargetPlatform.macOS) {
      throw StateError("The system's notification service did not start");
    }
  }

  /// Asked of macOS only. Linux has no launch details, and Windows cannot
  /// launch this app for a click: the plugin registers the app's activator
  /// with Windows only while the app is running.
  @override
  Future<String?> launchPayload() async {
    if (defaultTargetPlatform != TargetPlatform.macOS) return null;
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return details.notificationResponse?.payload;
  }

  @override
  Future<bool> requestMacOSPermission() async {
    final macOS = _plugin.resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>();
    if (macOS == null) throw StateError('There are no macOS notifications on $defaultTargetPlatform');
    return await macOS.requestPermissions(alert: true, sound: true, badge: true) ?? false;
  }

  @override
  Future<bool> isMacOSPermissionGranted() async {
    final macOS = _plugin.resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>();
    if (macOS == null) throw StateError('There are no macOS notifications on $defaultTargetPlatform');
    final options = await macOS.checkPermissions();
    if (options == null) throw StateError('macOS did not say whether the app may show notifications');
    return options.isEnabled;
  }

  @override
  Future<void> show({required int id, required String title, required String body, required String payload}) {
    return _plugin.show(id: id, title: title, body: body, payload: payload);
  }

  @override
  Future<void> cancelAll() => _plugin.cancelAll();
}

final notificationPluginProvider = Provider<NotificationPlugin>((ref) => SystemNotificationPlugin());
