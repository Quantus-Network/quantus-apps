import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/models/shell_sheet.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/ui/shell/desktop_shell.dart';

import '../fakes.dart';

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(DesktopShell)));

/// The screens reported, in order.
List<String?> _screens(RecordingTelemetry telemetry) => [
  for (final event in telemetry.events)
    if (event.name == 'screen_view') event.parameters?['screen'],
];

void main() {
  test('every sheet is named for analytics in snake case, as the phone names its screens', () {
    expect(ShellSheet.send.telemetryName, 'send');
    expect(ShellSheet.accountInfo.telemetryName, 'account_info');
    expect(ShellSheet.connectColdWallet.telemetryName, 'connect_cold_wallet');
    expect(ShellSheet.helpSupport.telemetryName, 'help_support');
    for (final sheet in ShellSheet.values) {
      expect(sheet.telemetryName, matches(RegExp(r'^[a-z]+(_[a-z]+)*$')), reason: sheet.name);
    }
    expect(ShellSheet.values.map((sheet) => sheet.telemetryName).toSet(), hasLength(ShellSheet.values.length));
  });

  testOnMac('opening a sheet sends screen_view with the sheet\'s name', (tester) async {
    final telemetry = RecordingTelemetry();
    await pumpShell(
      tester,
      overrides: shellOverrides(accounts: const [mainAccount]),
      telemetry: telemetry,
    );
    expect(_screens(telemetry), isEmpty);

    await _container(tester).read(shellSheetProvider.notifier).open(ShellSheet.helpSupport);
    await tester.pumpAndSettle();

    expect(_screens(telemetry), ['help_support']);
    expect(telemetry.events.last.parameters, {'screen': 'help_support'});

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(_container(tester).read(shellSheetProvider), isNull);
    await _container(tester).read(shellSheetProvider.notifier).open(ShellSheet.settings);
    await tester.pumpAndSettle();

    // Closing one reports nothing.
    expect(_screens(telemetry), ['help_support', 'settings']);
  });

  testOnMac('a sheet asked for while another is open is not opened, and not reported', (tester) async {
    final telemetry = RecordingTelemetry();
    await pumpShell(
      tester,
      overrides: shellOverrides(accounts: const [mainAccount]),
      telemetry: telemetry,
    );
    final sheets = _container(tester).read(shellSheetProvider.notifier);

    await sheets.open(ShellSheet.settings);
    await tester.pumpAndSettle();
    await sheets.open(ShellSheet.about);
    await tester.pumpAndSettle();

    expect(_container(tester).read(shellSheetProvider), ShellSheet.settings);
    expect(_screens(telemetry), ['settings']);
  });
}
