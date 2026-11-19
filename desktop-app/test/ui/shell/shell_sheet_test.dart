import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/models/shell_sheet.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/ui/components/account_label.dart';
import 'package:quantus_desktop_wallet/ui/components/toolbar_action.dart';
import 'package:quantus_desktop_wallet/ui/shell/account_toolbar.dart';
import 'package:quantus_desktop_wallet/ui/shell/desktop_shell.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_view.dart';
import 'package:quantus_desktop_wallet/ui/shell/sidebar.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/account_providers.dart';

import '../../fakes.dart';

Finder _toolbarButton(String label) =>
    find.descendant(of: find.byType(AccountToolbar), matching: find.widgetWithText(ToolbarAction, label));

Future<void> _pumpWallet(WidgetTester tester, {bool reduceMotion = true}) => pumpShell(
  tester,
  reduceMotion: reduceMotion,
  overrides: shellOverrides(
    accounts: const [mainAccount],
    settings: FakeSettingsService(activeAccount: const RegularAccount(mainAccount)),
    balances: oneTokenEach,
  ),
);

/// Where the hairline under the header ends: the top of the pane.
double _paneTop(WidgetTester tester) => tester.getRect(find.byKey(DesktopShell.headerLineKey)).bottom;

Rect _sheet(WidgetTester tester) => tester.getRect(find.byType(ShellSheetView));

Future<void> _openSend(WidgetTester tester) async {
  await tester.tap(_toolbarButton('Send'));
  await tester.pumpAndSettle();
}

void main() {
  testOnMac('an open Receive sheet stays on the account it opened on, its header too', (tester) async {
    await pumpShell(
      tester,
      overrides: shellOverrides(
        accounts: const [mainAccount, savingsAccount],
        settings: FakeSettingsService(activeAccount: const RegularAccount(mainAccount)),
        balances: oneTokenEach,
      ),
    );
    await tester.tap(_toolbarButton('Receive'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(tester.element(find.byType(DesktopShell)));
    await container.read(activeAccountProvider.notifier).setActiveAccount(const RegularAccount(savingsAccount));
    await tester.pumpAndSettle();

    Finder inSheet(Finder finder) => find.descendant(of: find.byType(ShellSheetView), matching: finder);
    expect(inSheet(find.text('Main')), findsOneWidget);
    expect(inSheet(find.text('Savings')), findsNothing);
    expect(inSheet(find.text('qzMain')), findsOneWidget);
  });

  testOnMac('a sheet\'s header names its account after the title: the badge 14 on, the name 8 after it', (
    tester,
  ) async {
    await pumpShell(
      tester,
      overrides: shellOverrides(
        accounts: const [mainAccount, savingsAccount],
        settings: FakeSettingsService(activeAccount: const RegularAccount(mainAccount)),
        balances: oneTokenEach,
      ),
    );
    await tester.tap(_toolbarButton('Receive'));
    await tester.pumpAndSettle();

    Finder inHeader(Finder finder) => find.descendant(of: find.byType(ShellSheetHeader), matching: finder);
    final title = tester.getRect(inHeader(find.text('Receive')));
    final badge = tester.getRect(inHeader(find.byType(AccountBadge)));
    final name = tester.getRect(inHeader(find.text('Main')));
    expect(badge.size, const Size.square(24));
    expect(badge.left, title.right + 14);
    expect(name.left, badge.right + 8);
    expect(name.center.dy, moreOrLessEquals(badge.center.dy, epsilon: 1));
    expect(inHeader(find.byType(AccountLabel)), findsOneWidget);
  });

  testOnMac('a sheet hangs from the bottom of the header, centred on the pane beside the sidebar', (tester) async {
    await _pumpWallet(tester);

    await _openSend(tester);

    final sidebar = tester.getRect(find.byType(Sidebar));
    expect(_sheet(tester).top, _paneTop(tester));
    expect(_sheet(tester).center.dx, moreOrLessEquals((sidebar.right + 1200) / 2));
  });

  testOnMac('with the sidebar hidden, a sheet is centred on the whole window', (tester) async {
    await _pumpWallet(tester);
    ProviderScope.containerOf(tester.element(find.byType(DesktopShell))).read(sidebarVisibleProvider.notifier).toggle();
    await tester.pumpAndSettle();

    await _openSend(tester);

    expect(_sheet(tester).top, _paneTop(tester));
    expect(_sheet(tester).center.dx, moreOrLessEquals(600));
  });

  testOnWindowsAndLinux(
    'a sheet hangs from the bottom of the header, below the in-window menu bar, centred on the pane',
    (tester) async {
      await _pumpWallet(tester);

      await _openSend(tester);

      final sidebar = tester.getRect(find.byType(Sidebar));
      expect(_sheet(tester).top, _paneTop(tester));
      expect(_sheet(tester).center.dx, moreOrLessEquals((sidebar.right + 1200) / 2));
    },
  );

  testOnWindowsAndLinux('with the sidebar hidden, a sheet hangs from the header, centred on the whole window', (
    tester,
  ) async {
    await _pumpWallet(tester);
    ProviderScope.containerOf(tester.element(find.byType(DesktopShell))).read(sidebarVisibleProvider.notifier).toggle();
    await tester.pumpAndSettle();

    await _openSend(tester);

    expect(_sheet(tester).top, _paneTop(tester));
    expect(_sheet(tester).center.dx, moreOrLessEquals(600));
  });

  testOnMac('a click outside a sheet closes it', (tester) async {
    await _pumpWallet(tester);
    await _openSend(tester);

    await tester.tapAt(const Offset(100, 700));
    await tester.pumpAndSettle();

    expect(find.byType(ShellSheetView), findsNothing);
  });

  testOnMac('a sheet slides down from under the header', (tester) async {
    await _pumpWallet(tester, reduceMotion: false);

    await tester.tap(_toolbarButton('Send'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    expect(_sheet(tester).top, lessThan(_paneTop(tester)));

    await tester.pumpAndSettle();

    expect(_sheet(tester).top, _paneTop(tester));
  });

  testOnMac('with reduced motion a sheet is in place on its first frame', (tester) async {
    await _pumpWallet(tester);

    await tester.tap(_toolbarButton('Send'));
    await tester.pump();

    expect(_sheet(tester).top, _paneTop(tester));
  });

  for (final (sheet, kind) in [
    (ShellSheet.send, 'a sheet that names the account'),
    (ShellSheet.addAccount, 'a sheet that does not'),
  ]) {
    testOnMac('the close button sits at the right edge of $kind', (tester) async {
      await _pumpWallet(tester);

      ProviderScope.containerOf(
        tester.element(find.byType(DesktopShell)),
      ).read(shellSheetProvider.notifier).open(sheet);
      await tester.pumpAndSettle();

      final close = tester.getRect(find.descendant(of: find.byType(ShellSheetView), matching: find.byTooltip('Close')));
      expect(_sheet(tester).right - close.right, lessThan(32));
    });
  }
}
