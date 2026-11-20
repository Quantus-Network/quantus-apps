import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:quantus_desktop_wallet/services/notification_plugin.dart';

/// A notification the app showed.
typedef ShownNotification = ({int id, String title, String body, String payload});

/// Stands in for the system's notifications: records what the app asks of
/// them, and answers as [startError] and [grants] say.
class FakeNotificationPlugin implements NotificationPlugin {
  FakeNotificationPlugin({this.startError, this.grants = true});

  /// What starting throws, as a system without a notification service would.
  Object? startError;

  /// Whether macOS lets the app show notifications when asked.
  bool grants;

  final initializations = <InitializationSettings>[];
  var permissionRequests = 0;
  final shown = <ShownNotification>[];
  void Function(String? payload)? _onClick;

  @override
  Future<void> initialize(InitializationSettings settings, {required void Function(String? payload) onClick}) async {
    initializations.add(settings);
    final error = startError;
    if (error != null) throw error;
    _onClick = onClick;
  }

  @override
  Future<bool> requestMacOSPermission() async {
    permissionRequests++;
    return grants;
  }

  @override
  Future<void> show({required int id, required String title, required String body, required String payload}) async {
    shown.add((id: id, title: title, body: body, payload: payload));
  }

  /// Clicks a notification with [payload], as the person would.
  void click(String? payload) {
    final onClick = _onClick;
    if (onClick == null) throw StateError('Clicked a notification before the notifications were started');
    onClick(payload);
  }
}
