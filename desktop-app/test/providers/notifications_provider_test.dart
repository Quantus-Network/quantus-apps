import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/models/notification_status.dart';
import 'package:quantus_desktop_wallet/models/wallet_presence.dart';
import 'package:quantus_desktop_wallet/providers/notifications_provider.dart';
import 'package:quantus_desktop_wallet/providers/wallet_presence_provider.dart';
import 'package:quantus_desktop_wallet/services/notification_plugin.dart';
import 'package:quantus_desktop_wallet/services/window_chrome.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/models/notification_models.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/services/telemetry.dart';

import '../services/fake_notification_plugin.dart';

class _RecordingTelemetry implements Telemetry {
  final errors = <String>[];

  @override
  void sendEvent(String eventName, {Map<String, String>? parameters}) {}

  @override
  void sendError(String errorName, {required Object error}) => errors.add(errorName);
}

/// A wallet that is [initial] at first, and whatever [become] makes it later.
class _Presence extends WalletPresenceNotifier {
  _Presence(this.initial);

  final WalletPresence initial;

  @override
  Future<WalletPresence> build() async => initial;

  void become(WalletPresence presence) => state = AsyncData(presence);
}

/// The app's notifications on [platform], the system's being [plugin].
({ProviderContainer container, _RecordingTelemetry telemetry}) _open(
  FakeNotificationPlugin plugin, {
  required TargetPlatform platform,
  List<Override> overrides = const [],
}) {
  debugDefaultTargetPlatformOverride = platform;
  addTearDown(() => debugDefaultTargetPlatformOverride = null);
  final telemetry = _RecordingTelemetry();
  final container = ProviderContainer(
    overrides: [
      notificationPluginProvider.overrideWithValue(plugin),
      telemetryProvider.overrideWithValue(telemetry),
      l10nProvider.overrideWithValue(lookupAppLocalizations(const Locale('en'))),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  return (container: container, telemetry: telemetry);
}

NotificationData _notification({String id = 'n-1', DateTime? scheduledTime}) => NotificationData(
  id: id,
  accountId: 'qzpyxSr48YN9EQe2ito734iCReTXjnungmNCSY4Yph1YznEda',
  type: NotificationType.success,
  source: NotificationSource.local,
  title: 'Sent 1 QTC',
  message: 'Main',
  accountName: 'Main',
  timestamp: DateTime(2026),
  scheduledTime: scheduledTime,
);

/// Lets what the providers started finish.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the binding', () {
    test('starting sets up macOS, Windows and Linux without asking for permission', () async {
      final plugin = FakeNotificationPlugin();
      final (:container, telemetry: _) = _open(plugin, platform: TargetPlatform.macOS);
      final notifications = container.read(desktopLocalNotificationsProvider.notifier);

      await notifications.start();
      // Started once, however often asked.
      await notifications.start();

      expect(plugin.initializations, hasLength(1));
      final settings = plugin.initializations.single;
      expect(settings.macOS?.requestAlertPermission, isFalse);
      expect(settings.macOS?.requestSoundPermission, isFalse);
      expect(settings.macOS?.requestBadgePermission, isFalse);
      expect(settings.windows?.appName, 'Quantus Wallet');
      expect(settings.windows?.appUserModelId, 'Quantus.DesktopWallet');
      expect(settings.windows?.guid, '745d2a45-cfdc-4f29-91c2-0c8a985a2e19');
      expect(settings.linux?.defaultActionName, 'Open');
      expect(plugin.permissionRequests, 0);
      expect(container.read(desktopLocalNotificationsProvider), isA<NotificationsNotAsked>());
    });

    test('on macOS, asking for permission asks the system and reports allowed when it agrees', () async {
      final plugin = FakeNotificationPlugin(grants: true);
      final (:container, telemetry: _) = _open(plugin, platform: TargetPlatform.macOS);
      final notifications = container.read(desktopLocalNotificationsProvider.notifier);

      await notifications.start();
      await notifications.requestPermission();

      expect(plugin.permissionRequests, 1);
      expect(container.read(desktopLocalNotificationsProvider), isA<NotificationsAllowed>());
    });

    test('on macOS, a refusal reports notifications as turned off', () async {
      final plugin = FakeNotificationPlugin(grants: false);
      final (:container, telemetry: _) = _open(plugin, platform: TargetPlatform.macOS);
      final notifications = container.read(desktopLocalNotificationsProvider.notifier);

      await notifications.start();
      await notifications.requestPermission();

      expect(container.read(desktopLocalNotificationsProvider), isA<NotificationsDenied>());
    });

    for (final platform in [TargetPlatform.windows, TargetPlatform.linux]) {
      test('on ${platform.name}, nothing is asked: once started, notifications are allowed', () async {
        final plugin = FakeNotificationPlugin();
        final (:container, telemetry: _) = _open(plugin, platform: platform);
        final notifications = container.read(desktopLocalNotificationsProvider.notifier);

        await notifications.start();

        expect(container.read(desktopLocalNotificationsProvider), isA<NotificationsAllowed>());

        await notifications.requestPermission();

        expect(plugin.permissionRequests, 0);
        expect(container.read(desktopLocalNotificationsProvider), isA<NotificationsAllowed>());
      });
    }

    test('a start that fails reports notifications unavailable with the reason, tells telemetry, and does not '
        'throw', () async {
      final plugin = FakeNotificationPlugin(startError: StateError('no session bus'));
      final (:container, :telemetry) = _open(plugin, platform: TargetPlatform.linux);
      final notifications = container.read(desktopLocalNotificationsProvider.notifier);

      await notifications.start();
      // Asking afterwards changes nothing: there is nothing to ask.
      await notifications.requestPermission();

      expect(
        container.read(desktopLocalNotificationsProvider),
        isA<NotificationsUnavailable>().having((s) => s.reason, 'reason', contains('no session bus')),
      );
      expect(telemetry.errors, ['desktop_notifications_unavailable']);
    });

    test('a notification is shown with its title and body, each under its own id', () async {
      final plugin = FakeNotificationPlugin();
      final (:container, telemetry: _) = _open(plugin, platform: TargetPlatform.windows);
      final notifications = container.read(desktopLocalNotificationsProvider.notifier);
      await notifications.start();

      await notifications.showOrScheduleNotification(_notification(id: 'n-1'));
      await notifications.showOrScheduleNotification(_notification(id: 'n-2'));

      expect(plugin.shown.map((n) => (n.title, n.body)), [('Sent 1 QTC', 'Main'), ('Sent 1 QTC', 'Main')]);
      expect(plugin.shown.first.id, isNot(plugin.shown.last.id));
    });

    test('a notification carries the account it is about', () async {
      final plugin = FakeNotificationPlugin();
      final (:container, telemetry: _) = _open(plugin, platform: TargetPlatform.windows);
      final notifications = container.read(desktopLocalNotificationsProvider.notifier);
      await notifications.start();

      await notifications.showOrScheduleNotification(_notification());

      expect(jsonDecode(plugin.shown.single.payload), {
        'accountId': 'qzpyxSr48YN9EQe2ito734iCReTXjnungmNCSY4Yph1YznEda',
      });
    });

    test('a scheduled notification fails with UnsupportedError: nothing on desktop schedules one yet', () async {
      final plugin = FakeNotificationPlugin();
      final (:container, telemetry: _) = _open(plugin, platform: TargetPlatform.windows);
      final notifications = container.read(desktopLocalNotificationsProvider.notifier);
      await notifications.start();

      await expectLater(
        notifications.showOrScheduleNotification(_notification(scheduledTime: DateTime(2026, 12))),
        throwsUnsupportedError,
      );
      expect(plugin.shown, isEmpty);
    });

    test('showing while notifications are not allowed fails with StateError', () async {
      Future<void> expectRefused(FakeNotificationPlugin plugin, TargetPlatform platform, {bool ask = false}) async {
        final (:container, telemetry: _) = _open(plugin, platform: platform);
        final notifications = container.read(desktopLocalNotificationsProvider.notifier);
        await notifications.start();
        if (ask) await notifications.requestPermission();

        await expectLater(notifications.showOrScheduleNotification(_notification()), throwsStateError);
        expect(plugin.shown, isEmpty);
      }

      // Not asked yet, refused, and no notification service.
      await expectRefused(FakeNotificationPlugin(), TargetPlatform.macOS);
      await expectRefused(FakeNotificationPlugin(grants: false), TargetPlatform.macOS, ask: true);
      await expectRefused(FakeNotificationPlugin(startError: StateError('no session bus')), TargetPlatform.linux);
    });

    test('before it has started, showing fails with StateError', () async {
      final plugin = FakeNotificationPlugin();
      final (:container, telemetry: _) = _open(plugin, platform: TargetPlatform.windows);

      await expectLater(
        container.read(desktopLocalNotificationsProvider.notifier).showOrScheduleNotification(_notification()),
        throwsStateError,
      );
    });
  });

  group('a click', () {
    test('whose payload cannot be read still brings the window forward, and is reported', () async {
      final window = <String>[];
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(WindowChrome.channel, (call) async {
        window.add(call.method);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(WindowChrome.channel, null));
      final plugin = FakeNotificationPlugin();
      final (:container, :telemetry) = _open(plugin, platform: TargetPlatform.macOS);
      await container.read(desktopLocalNotificationsProvider.notifier).start();

      plugin.click('not what the app shows');
      await _settle();

      expect(window, ['bringToFront']);
      expect(telemetry.errors, ['desktop_notification_click_unreadable']);
    });
  });

  group('with the app', () {
    test('the app starting starts the notifications; with no wallet yet, nothing is asked', () async {
      final plugin = FakeNotificationPlugin();
      final presence = _Presence(WalletPresence.none);
      final (:container, telemetry: _) = _open(
        plugin,
        platform: TargetPlatform.macOS,
        overrides: [walletPresenceProvider.overrideWith(() => presence)],
      );

      container.read(notificationsStartupProvider);
      await container.read(walletPresenceProvider.future);
      await _settle();

      expect(plugin.initializations, hasLength(1));
      expect(plugin.permissionRequests, 0);
      expect(container.read(desktopLocalNotificationsProvider), isA<NotificationsNotAsked>());
    });

    test('opening the wallet asks for permission', () async {
      final plugin = FakeNotificationPlugin();
      final (:container, telemetry: _) = _open(
        plugin,
        platform: TargetPlatform.macOS,
        overrides: [walletPresenceProvider.overrideWith(() => _Presence(WalletPresence.present))],
      );

      container.read(notificationsStartupProvider);
      await container.read(walletPresenceProvider.future);
      await _settle();

      expect(plugin.permissionRequests, 1);
      expect(container.read(desktopLocalNotificationsProvider), isA<NotificationsAllowed>());
    });

    test('a wallet made after the app started asks for permission once it is there', () async {
      final plugin = FakeNotificationPlugin();
      final presence = _Presence(WalletPresence.none);
      final (:container, telemetry: _) = _open(
        plugin,
        platform: TargetPlatform.macOS,
        overrides: [walletPresenceProvider.overrideWith(() => presence)],
      );
      container.read(notificationsStartupProvider);
      await container.read(walletPresenceProvider.future);
      await _settle();

      presence.become(WalletPresence.present);
      await _settle();

      expect(plugin.permissionRequests, 1);
      expect(container.read(desktopLocalNotificationsProvider), isA<NotificationsAllowed>());
    });
  });
}
