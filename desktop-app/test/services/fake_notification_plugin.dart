import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:quantus_desktop_wallet/services/notification_plugin.dart';

/// A notification the app showed.
typedef ShownNotification = ({int id, String title, String body, String payload});

/// Stands in for the system's notifications: records what the app asks of
/// them, and answers as [startError] and [grants] say.
class FakeNotificationPlugin implements NotificationPlugin {
  FakeNotificationPlugin({this.startError, this.grants = true, this.launchedBy});

  /// What starting throws, as a system without a notification service would.
  Object? startError;

  /// Whether macOS lets the app show notifications, when asked or read.
  bool grants;

  /// Holds macOS's answer to the prompt until completed, as a person who has
  /// not answered yet does.
  Completer<bool>? heldAnswer;

  /// What reading the permission throws, when it fails.
  Object? permissionCheckError;
  var permissionChecks = 0;

  /// The payload of the notification whose click launched the app, if one did.
  final String? launchedBy;
  var launchPayloadReads = 0;

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
  Future<String?> launchPayload() async {
    launchPayloadReads++;
    return launchedBy;
  }

  @override
  Future<bool> requestMacOSPermission() async {
    permissionRequests++;
    final held = heldAnswer;
    if (held != null) return held.future;
    return grants;
  }

  @override
  Future<bool> isMacOSPermissionGranted() async {
    permissionChecks++;
    final error = permissionCheckError;
    if (error != null) throw error;
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
