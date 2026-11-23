import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/ui/components/balance_card.dart';
import 'package:quantus_desktop_wallet/ui/components/panel.dart';
import 'package:quantus_desktop_wallet/ui/components/panel_resize_handle.dart';
import 'package:quantus_desktop_wallet/ui/shell/desktop_shell.dart';
import 'package:quantus_desktop_wallet/ui/shell/mining_rewards_pane.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_footer.dart';
import 'package:quantus_desktop_wallet/ui/shell/sidebar.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

import '../../fakes.dart';

/// Opens Main's wallet; [savedWidth] is the sidebar's width saved by an
/// earlier run, as it was written.
Future<FakeSettingsService> _open(WidgetTester tester, {String? savedWidth}) async {
  final settings = FakeSettingsService(activeAccount: const RegularAccount(mainAccount));
  if (savedWidth != null) settings.strings[SidebarWidthNotifier.settingsKey] = savedWidth;
  await pumpShell(
    tester,
    overrides: shellOverrides(
      accounts: const [mainAccount, savingsAccount],
      settings: settings,
      balances: oneTokenEach,
    ),
  );
  return settings;
}

Rect _sidebar(WidgetTester tester) => tester.getRect(find.byType(Sidebar));

Rect _balance(WidgetTester tester) => tester.getRect(find.byType(BalanceCard));

Finder get _handle => find.byType(PanelResizeHandle);

Future<void> _dragHandle(WidgetTester tester, double by) async {
  await tester.timedDrag(_handle, Offset(by, 0), const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
}

void main() {
  testOnMac('the sidebar is the Accounts panel, 240pt wide, 8pt from the window\'s edge, between the top bar and the '
      'footer, and 8pt from the balance\'s panel', (tester) async {
    await _open(tester);

    expect(_sidebar(tester), const Rect.fromLTWH(Panel.gap, 52, 240, 800 - 52 - ShellFooter.height));
    expect(find.descendant(of: find.byType(Sidebar), matching: find.text('Accounts')), findsOneWidget);
    expect(_balance(tester).left, _sidebar(tester).right + Panel.gap);
    expect(_balance(tester).top, 52);
    expect(_balance(tester).right, 1200 - Panel.gap);
  });

  testOnMac('with the sidebar hidden the panels start 8pt from the window\'s edge', (tester) async {
    await _open(tester);
    ProviderScope.containerOf(tester.element(find.byType(DesktopShell))).read(sidebarVisibleProvider.notifier).toggle();
    await tester.pumpAndSettle();

    expect(_balance(tester).left, Panel.gap);
    expect(_handle, findsNothing);
  });

  testOnMac('Mining Rewards is a panel of its own, beside the sidebar', (tester) async {
    await _open(tester);

    await tester.tap(find.descendant(of: find.byType(Sidebar), matching: find.text('Mining Rewards')));
    await tester.pumpAndSettle();

    final pane = tester.getRect(find.byType(MiningRewardsPane));
    expect(pane.left, _sidebar(tester).right + Panel.gap);
    expect(find.descendant(of: find.byType(MiningRewardsPane), matching: find.byType(Panel)), findsOneWidget);
  });

  testOnMac('dragging the gap beside the sidebar resizes it, stopping at 200 and 360, and saves the width', (
    tester,
  ) async {
    final settings = await _open(tester);

    await _dragHandle(tester, 60);

    expect(_sidebar(tester).width, 300);
    expect(_balance(tester).left, _sidebar(tester).right + Panel.gap);
    expect(settings.strings[SidebarWidthNotifier.settingsKey], '300.0');

    await _dragHandle(tester, 200);

    expect(_sidebar(tester).width, 360);

    await _dragHandle(tester, -400);

    expect(_sidebar(tester).width, 200);
    expect(settings.strings[SidebarWidthNotifier.settingsKey], '200.0');
  });

  testOnMac('a drag past the limit and back moves the edge only once the pointer is back over it', (tester) async {
    await _open(tester);
    final gesture = await tester.startGesture(tester.getCenter(_handle));

    await gesture.moveBy(const Offset(200, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-100, 0));
    await tester.pump();

    // 240 + 100 is short of the limit: the edge follows the pointer, not
    // where it would be had the edge gone past 360.
    expect(_sidebar(tester).width, 340);

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testOnMac('the sidebar opens at the width saved before', (tester) async {
    await _open(tester, savedWidth: '300.0');

    expect(_sidebar(tester).width, 300);
  });

  testOnMac('a saved width outside the limits opens within them', (tester) async {
    await _open(tester, savedWidth: '900');

    expect(_sidebar(tester).width, 360);
  });

  testOnMac('a saved width that cannot be read opens the sidebar at 240', (tester) async {
    await _open(tester, savedWidth: 'wide');

    expect(_sidebar(tester).width, 240);
  });

  testOnMac('a line shows in the gap while the pointer is over it', (tester) async {
    await _open(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: const Offset(700, 400));
    await tester.pump();

    expect(find.byKey(PanelResizeHandle.lineKey), findsNothing);

    await mouse.moveTo(tester.getCenter(_handle));
    await tester.pump();

    expect(find.byKey(PanelResizeHandle.lineKey), findsOneWidget);

    await mouse.moveTo(const Offset(700, 400));
    await tester.pump();

    expect(find.byKey(PanelResizeHandle.lineKey), findsNothing);
  });

  for (final (what, hide) in [('at its widest', false), ('hidden', true)]) {
    testOnMac('in the smallest window, with the sidebar $what, nothing overflows', (tester) async {
      await _open(tester, savedWidth: '360');
      tester.view.physicalSize = const Size(960, 640);
      await tester.pumpAndSettle();
      if (hide) {
        ProviderScope.containerOf(
          tester.element(find.byType(DesktopShell)),
        ).read(sidebarVisibleProvider.notifier).toggle();
        await tester.pumpAndSettle();
      }

      expect(tester.takeException(), isNull);
      expect(_balance(tester).right, 960 - Panel.gap);
    });
  }
}
