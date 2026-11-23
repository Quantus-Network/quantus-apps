import 'package:flutter/cupertino.dart' show CupertinoSwitch;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/models/shell_sheet.dart';
import 'package:quantus_desktop_wallet/providers/background_mode_provider.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/providers/wallet_presence_provider.dart';
import 'package:quantus_desktop_wallet/ui/settings/keep_running_row.dart';
import 'package:quantus_desktop_wallet/ui/shell/desktop_shell.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/services/telemetry.dart';

import '../../fakes.dart';

const _title = 'Keep Running When Closed';
const _line = 'Keeps watching your sends and proposals';

final _switch = find.byKey(KeepRunningRow.switchKey);

class _RecordingTelemetry implements Telemetry {
  final errors = <String>[];

  @override
  void sendEvent(String eventName, {Map<String, String>? parameters}) {}

  @override
  void sendError(String errorName, {required Object error}) => errors.add(errorName);
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(DesktopShell)));

Future<void> _openSettings(WidgetTester tester, {FakeSettingsService? settings}) async {
  final stored = settings ?? FakeSettingsService(activeAccount: const RegularAccount(mainAccount));
  await pumpShell(
    tester,
    overrides: shellOverrides(accounts: const [mainAccount], settings: stored),
  );
  _container(tester).read(shellSheetProvider.notifier).open(ShellSheet.settings);
  await tester.pumpAndSettle();
}

bool _switchValue(WidgetTester tester) =>
    tester.widget<CupertinoSwitch>(find.descendant(of: _switch, matching: find.byType(CupertinoSwitch))).value;

Future<void> _flip(WidgetTester tester) async {
  await tester.ensureVisible(_switch);
  await tester.pumpAndSettle();
  await tester.tap(_switch);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testOnMac('with no saved choice it is on, and says what it is for', (tester) async {
    await _openSettings(tester);

    expect(find.text(_title), findsOneWidget);
    expect(find.text(_line), findsOneWidget);
    expect(_switchValue(tester), isTrue);
  });

  testOnMac('turning it off is saved, and so is turning it back on', (tester) async {
    final settings = FakeSettingsService(activeAccount: const RegularAccount(mainAccount));
    await _openSettings(tester, settings: settings);

    await _flip(tester);

    expect(_switchValue(tester), isFalse);
    expect(settings.bools[KeepRunningNotifier.settingsKey], isFalse);

    await _flip(tester);

    expect(_switchValue(tester), isTrue);
    expect(settings.bools[KeepRunningNotifier.settingsKey], isTrue);
  });

  testOnMac('an off saved before is still off after a restart', (tester) async {
    final settings = FakeSettingsService(activeAccount: const RegularAccount(mainAccount));
    settings.bools[KeepRunningNotifier.settingsKey] = false;

    await _openSettings(tester, settings: settings);

    expect(_switchValue(tester), isFalse);
  });

  test('a choice that cannot be saved goes back, and is reported', () async {
    final telemetry = _RecordingTelemetry();
    final settings = FakeSettingsService()..failNextBoolWrite = StateError('the preferences refused it');
    final container = ProviderContainer(
      overrides: [settingsServiceProvider.overrideWithValue(settings), telemetryProvider.overrideWithValue(telemetry)],
    );
    addTearDown(container.dispose);

    await container.read(keepRunningProvider.notifier).setEnabled(false);

    expect(container.read(keepRunningProvider), isTrue);
    expect(settings.bools.containsKey(KeepRunningNotifier.settingsKey), isFalse);
    expect(telemetry.errors, ['desktop_keep_running_save_failed']);
  });

  testOnMac('a wallet reset brings the default back', (tester) async {
    final device = FakeWalletDevice()..store(const [mainAccount]);
    await pumpShell(tester, overrides: device.overrides);
    final container = _container(tester);
    await container.read(keepRunningProvider.notifier).setEnabled(false);
    expect(container.read(keepRunningProvider), isFalse);

    await container.read(walletPresenceProvider.notifier).wipeWallet();
    await tester.pumpAndSettle();

    expect(container.read(keepRunningProvider), isTrue);
  });

  testOnMac('it follows the app language', (tester) async {
    final settings = FakeSettingsService(activeAccount: const RegularAccount(mainAccount))..locale = 'id';

    await _openSettings(tester, settings: settings);

    expect(find.text('Tetap Berjalan Saat Ditutup'), findsOneWidget);
    expect(find.text('Tetap memantau pengiriman dan proposal Anda'), findsOneWidget);
  });

  testOnWindowsAndLinux('Windows and Linux do not offer it', (tester) async {
    await _openSettings(tester);

    expect(find.text(_title), findsNothing);
    expect(_switch, findsNothing);
  });
}
