import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/services/notification_plugin.dart';

/// The plugin's own channel to its native side.
const _channel = MethodChannel('dexterous.com/flutter/local_notifications');

/// Answers the plugin's native calls on macOS with [launchDetails] for the
/// launch, and records which calls were made.
List<String> _nativeMacOS({required Map<String, Object?> launchDetails, bool isEnabled = false}) {
  debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
  addTearDown(() => debugDefaultTargetPlatformOverride = null);
  MacOSFlutterLocalNotificationsPlugin.registerWith();
  final calls = <String>[];
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_channel, (call) async {
    calls.add(call.method);
    return switch (call.method) {
      // The answer to whether permission was granted, which was not asked.
      'initialize' => false,
      'getNotificationAppLaunchDetails' => launchDetails,
      'checkPermissions' => {'isEnabled': isEnabled},
      _ => null,
    };
  });
  addTearDown(() => messenger.setMockMethodCallHandler(_channel, null));
  return calls;
}

const _settings = InitializationSettings(macOS: DarwinInitializationSettings());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test("on macOS, the click that launched the app is read from the system's launch details", () async {
    _nativeMacOS(
      launchDetails: {
        'notificationLaunchedApp': true,
        'notificationResponse': {
          'notificationId': 7,
          'notificationResponseType': 0,
          'payload': '{"accountId":"qzSavings"}',
        },
      },
    );
    final clicks = <String?>[];
    final plugin = SystemNotificationPlugin();
    await plugin.initialize(_settings, onClick: clicks.add);

    expect(await plugin.launchPayload(), '{"accountId":"qzSavings"}');
    // Such a click never comes through the running app's callback.
    expect(clicks, isEmpty);
  });

  test('on macOS, an app not launched by a notification has no launch payload', () async {
    _nativeMacOS(launchDetails: {'notificationLaunchedApp': false});
    final plugin = SystemNotificationPlugin();
    await plugin.initialize(_settings, onClick: (_) {});

    expect(await plugin.launchPayload(), isNull);
  });

  for (final isEnabled in [true, false]) {
    test("on macOS, reading the permission gives macOS's current answer ($isEnabled) and never asks", () async {
      final calls = _nativeMacOS(launchDetails: {'notificationLaunchedApp': false}, isEnabled: isEnabled);
      final plugin = SystemNotificationPlugin();
      await plugin.initialize(_settings, onClick: (_) {});

      expect(await plugin.isMacOSPermissionGranted(), isEnabled);
      expect(calls, contains('checkPermissions'));
      expect(calls, isNot(contains('requestPermissions')));
    });
  }

  for (final platform in [TargetPlatform.windows, TargetPlatform.linux]) {
    test('on ${platform.name}, which a click does not launch the app on, no launch details are asked for', () async {
      final calls = _nativeMacOS(launchDetails: {'notificationLaunchedApp': true});
      debugDefaultTargetPlatformOverride = platform;

      expect(await SystemNotificationPlugin().launchPayload(), isNull);
      expect(calls, isNot(contains('getNotificationAppLaunchDetails')));
    });
  }
}
