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

  /// Asks macOS whether the app may show notifications, with sounds and a
  /// badge. Returns whether it may. macOS asks the person only the first
  /// time; after that it answers with what they chose.
  Future<bool> requestMacOSPermission();

  /// Shows a notification now. One shown with the same [id] replaces it.
  Future<void> show({required int id, required String title, required String body, required String payload});
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

  @override
  Future<bool> requestMacOSPermission() async {
    final macOS = _plugin.resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>();
    if (macOS == null) throw StateError('There are no macOS notifications on $defaultTargetPlatform');
    return await macOS.requestPermissions(alert: true, sound: true, badge: true) ?? false;
  }

  @override
  Future<void> show({required int id, required String title, required String body, required String payload}) {
    return _plugin.show(id: id, title: title, body: body, payload: payload);
  }
}

final notificationPluginProvider = Provider<NotificationPlugin>((ref) => SystemNotificationPlugin());
