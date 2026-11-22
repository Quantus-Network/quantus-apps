import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart' show CupertinoSwitch;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/models/shell_sheet.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/providers/wallet_presence_provider.dart';
import 'package:quantus_desktop_wallet/services/external_links.dart';
import 'package:quantus_desktop_wallet/ui/settings/notifications_row.dart';
import 'package:quantus_desktop_wallet/ui/shell/desktop_shell.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallet_core/models/notification_models.dart';
import 'package:wallet_core/providers/notification_config_provider.dart';

import '../../fakes.dart';
import '../../services/fake_notification_plugin.dart';

const _usualLine = 'Transaction and wallet alerts';
const _notAllowed = 'Not allowed in System Settings';
const _open = 'Open System Settings';

final _switch = find.byKey(NotificationsRow.switchKey);
final _openAction = find.byKey(NotificationsRow.openSystemSettingsKey);

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(DesktopShell)));

/// Opens Settings on a wallet, the system's notifications being [plugin].
/// Links opened outside the app go to [openUrl].
Future<void> _openSettings(
  WidgetTester tester,
  FakeNotificationPlugin plugin, {
  Future<void> Function(Uri url)? openUrl,
  String locale = 'en',
}) async {
  final settings = FakeSettingsService(activeAccount: const RegularAccount(mainAccount))..locale = locale;
  await pumpShell(
    tester,
    notifications: plugin,
    overrides: [
      ...shellOverrides(accounts: const [mainAccount], settings: settings),
      openExternalUrlProvider.overrideWithValue(openUrl ?? (_) async {}),
    ],
  );
  _container(tester).read(shellSheetProvider.notifier).open(ShellSheet.settings);
  await tester.pumpAndSettle();
}

bool _switchValue(WidgetTester tester) =>
    tester.widget<CupertinoSwitch>(find.descendant(of: _switch, matching: find.byType(CupertinoSwitch))).value;

Future<NotificationConfig> _saved() async {
  final prefs = await SharedPreferences.getInstance();
  return NotificationConfig.fromJson(jsonDecode(prefs.getString(notificationConfigKey)!) as Map<String, dynamic>);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testOnMac('Preferences shows Notifications, on, with the usual line', (tester) async {
    await _openSettings(tester, FakeNotificationPlugin());

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text(_usualLine), findsOneWidget);
    expect(_switchValue(tester), isTrue);
    expect(_openAction, findsNothing);
  });

  testOnMac('turning it off is saved, and so is turning it back on', (tester) async {
    await _openSettings(tester, FakeNotificationPlugin());

    await tester.tap(_switch);
    await tester.pumpAndSettle();

    expect(_switchValue(tester), isFalse);
    expect(_container(tester).read(notificationConfigProvider).enabled, isFalse);
    expect((await _saved()).enabled, isFalse);

    await tester.tap(_switch);
    await tester.pumpAndSettle();

    expect(_switchValue(tester), isTrue);
    expect((await _saved()).enabled, isTrue);
  });

  testOnMac('an off saved before is still off after a restart', (tester) async {
    const off = NotificationConfig(
      enabled: false,
      sound: true,
      vibration: true,
      showBadge: true,
      sentTokensEnabled: true,
      receivedTokensEnabled: true,
      recoveryTimerEndingEnabled: true,
      reversibleTransactionsEnabled: true,
    );
    SharedPreferences.setMockInitialValues({notificationConfigKey: jsonEncode(off.toJson())});

    await _openSettings(tester, FakeNotificationPlugin());

    expect(_switchValue(tester), isFalse);
  });

  testOnMac('Tab reaches the switch, Space flips it, and a screen reader names it', (tester) async {
    final semantics = tester.ensureSemantics();
    await _openSettings(tester, FakeNotificationPlugin());

    expect(
      tester.getSemantics(find.descendant(of: _switch, matching: find.byType(CupertinoSwitch))),
      isSemantics(label: 'Notifications', hasToggledState: true, isToggled: true),
    );

    bool switchHasFocus() {
      final focused = FocusManager.instance.primaryFocus?.context;
      if (focused == null) return false;
      return find.descendant(of: _switch, matching: find.byWidget(focused.widget)).evaluate().isNotEmpty;
    }

    for (var i = 0; i < 20 && !switchHasFocus(); i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(switchHasFocus(), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();

    expect(_switchValue(tester), isFalse);
    semantics.dispose();
  });

  testOnMac('while macOS has not answered, the switch shows and works', (tester) async {
    final answer = Completer<bool>();
    await _openSettings(tester, FakeNotificationPlugin()..heldAnswer = answer);

    expect(find.text(_usualLine), findsOneWidget);
    await tester.tap(_switch);
    await tester.pumpAndSettle();
    expect(_switchValue(tester), isFalse);

    answer.complete(true);
    await tester.pumpAndSettle();
  });

  testOnMac('when macOS is not allowing them, the row says so and offers System Settings', (tester) async {
    await _openSettings(tester, FakeNotificationPlugin(grants: false));

    final line = tester.widget<Text>(find.text(_notAllowed));
    expect(line.style?.color, tester.element(find.text(_notAllowed)).colorsV3.semanticEmber);
    expect(find.text(_open), findsOneWidget);
    expect(_switch, findsNothing);
  });

  testOnMac('Open System Settings opens its Notifications pane', (tester) async {
    final opened = <Uri>[];
    await _openSettings(tester, FakeNotificationPlugin(grants: false), openUrl: (url) async => opened.add(url));

    await tester.tap(_openAction);
    await tester.pumpAndSettle();

    expect(opened, [NotificationsRow.systemSettingsUrl]);
    expect(opened.single.scheme, 'x-apple.systempreferences');
    expect(opened.single.path, 'com.apple.preference.notifications');
  });

  testOnMac('when System Settings cannot be opened, the row says so', (tester) async {
    await _openSettings(
      tester,
      FakeNotificationPlugin(grants: false),
      openUrl: (_) async => throw StateError('Nothing on this computer opened it'),
    );

    await tester.tap(_openAction);
    await tester.pumpAndSettle();

    expect(find.text('Couldn’t open System Settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testOnMac('when notifications are unavailable, the row gives the reason and no control', (tester) async {
    await _openSettings(tester, FakeNotificationPlugin(startError: StateError('no notification service')));

    const reason = 'Unavailable: no notification service';
    expect(find.text(reason), findsOneWidget);
    expect(
      tester.widget<Text>(find.text(reason)).style?.color,
      tester.element(find.text(reason)).colorsV3.semanticEmber,
    );
    expect(_switch, findsNothing);
    expect(_openAction, findsNothing);
  });

  testOnWindowsAndLinux('Windows and Linux show the switch, and never Open System Settings', (tester) async {
    await _openSettings(tester, FakeNotificationPlugin(grants: false));

    expect(_switchValue(tester), isTrue);
    expect(_openAction, findsNothing);
  });

  testOnMac('the row follows the app language', (tester) async {
    await _openSettings(tester, FakeNotificationPlugin(grants: false), locale: 'id');

    expect(find.text('Notifikasi'), findsOneWidget);
    expect(find.text('Tidak diizinkan di Pengaturan Sistem'), findsOneWidget);
    expect(find.text('Buka Pengaturan Sistem'), findsOneWidget);
  });

  testOnMac('resetting the wallet puts the switch back on', (tester) async {
    final device = FakeWalletDevice()..store(const [mainAccount]);
    await pumpShell(tester, notifications: FakeNotificationPlugin(), overrides: device.overrides);
    final container = _container(tester);
    container.read(shellSheetProvider.notifier).open(ShellSheet.settings);
    await tester.pumpAndSettle();
    await tester.tap(_switch);
    await tester.pumpAndSettle();
    expect(container.read(notificationConfigProvider).enabled, isFalse);

    // The wipe clears everything saved, this setting with it.
    await (await SharedPreferences.getInstance()).clear();
    await container.read(walletPresenceProvider.notifier).wipeWallet();
    await tester.pumpAndSettle();

    expect(container.read(notificationConfigProvider).enabled, isTrue);
  });

  testOnMac('allowed in System Settings meanwhile, the switch comes back when the window does', (tester) async {
    final plugin = FakeNotificationPlugin(grants: false);
    await _openSettings(tester, plugin);
    expect(_openAction, findsOneWidget);
    addTearDown(() => tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed));

    plugin.grants = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(_switchValue(tester), isTrue);
    expect(_openAction, findsNothing);
    expect(find.text(_usualLine), findsOneWidget);
    expect(plugin.permissionRequests, 1);
  });
}
