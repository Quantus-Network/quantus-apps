import 'package:flutter/widgets.dart' show Rect, Size;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/ui/components/toolbar_action.dart';
import 'package:quantus_desktop_wallet/ui/components/window_drag_area.dart';
import 'package:quantus_desktop_wallet/ui/shell/account_pane.dart';
import 'package:quantus_desktop_wallet/ui/shell/account_toolbar.dart';
import 'package:quantus_desktop_wallet/ui/shell/desktop_shell.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_header.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_view.dart';
import 'package:quantus_desktop_wallet/ui/shell/sidebar.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

import '../../fakes.dart';

/// Where the system draws the last traffic light's right edge: 20pt in, three
/// 14pt buttons 20pt apart. The Swift side places them; nothing the app draws
/// may start left of this.
const double _trafficLightsRightEdge = 74;

/// Points of empty space in the top bar: past the sidebar's switch, and over
/// the panels.
const _emptyBarBySidebar = Offset(300, 26);
const _emptyBarOverPanels = Offset(700, 26);

Finder _inTopBar(Finder matching) => find.descendant(of: find.byType(ShellTopBar), matching: matching);

Finder get _wordmark => find.byKey(ShellTopBar.wordmarkKey);

List<Override> _withActive(DisplayAccount active) => shellOverrides(
  accounts: const [mainAccount, encryptedAccount],
  settings: FakeSettingsService(activeAccount: active),
  balances: oneTokenEach,
  encryptedBalances: {0: oneToken},
);

Future<void> _hideSidebar(WidgetTester tester) async {
  ProviderScope.containerOf(tester.element(find.byType(DesktopShell))).read(sidebarVisibleProvider.notifier).toggle();
  await tester.pumpAndSettle();
}

void main() {
  group('on macOS', () {
    testOnMac('the top bar runs across the window: the wordmark clear of the traffic lights, then the sidebar\'s '
        'switch', (tester) async {
      await pumpShell(tester, overrides: _withActive(const RegularAccount(mainAccount)));

      expect(tester.getRect(find.byType(ShellTopBar)), const Rect.fromLTWH(0, 0, 1200, 52));
      expect(tester.getTopLeft(_wordmark).dx, greaterThanOrEqualTo(_trafficLightsRightEdge));
      final hide = _inTopBar(find.byTooltip('Hide Sidebar'));
      expect(tester.getTopLeft(hide).dx, greaterThan(tester.getTopRight(_wordmark).dx));
    });

    testOnMac('everything in the top bar is centred on the middle of its 52pt row, where the traffic lights are', (
      tester,
    ) async {
      await pumpShell(tester, overrides: _withActive(const RegularAccount(encryptedAccount)));
      await _hideSidebar(tester);

      for (final finder in [
        _wordmark,
        _inTopBar(find.byTooltip('Show Sidebar')),
        _inTopBar(find.text('Encrypted Account')),
        _inTopBar(find.byType(EncryptedLockBadge)),
        _inTopBar(find.widgetWithText(ToolbarAction, 'Receive')),
      ]) {
        expect(tester.getCenter(finder).dy, moreOrLessEquals(26, epsilon: 0.5), reason: '$finder');
      }
    });

    testOnMac('with the sidebar shown the bar names no account: the selected row in Accounts does', (tester) async {
      await pumpShell(tester, overrides: _withActive(const RegularAccount(mainAccount)));

      expect(_inTopBar(find.text('Main')), findsNothing);
      expect(_inTopBar(find.byType(AccountBadge)), findsNothing);
    });

    testOnMac('with the sidebar hidden the bar names the active account, its badge and name after the switch', (
      tester,
    ) async {
      await pumpShell(tester, overrides: _withActive(const RegularAccount(mainAccount)));
      await _hideSidebar(tester);

      final name = _inTopBar(find.text('Main'));
      expect(name, findsOneWidget);
      final badge = _inTopBar(find.byType(AccountBadge));
      expect(tester.getSize(badge), const Size.square(24));
      expect(
        tester.getTopLeft(badge).dx,
        greaterThan(tester.getTopRight(_inTopBar(find.byTooltip('Show Sidebar'))).dx),
      );
      expect(tester.getTopLeft(name).dx, greaterThan(tester.getTopRight(badge).dx));
    });

    testOnMac('with the sidebar hidden, the encrypted account is named with its lock badge', (tester) async {
      await pumpShell(tester, overrides: _withActive(const RegularAccount(encryptedAccount)));
      await _hideSidebar(tester);

      expect(_inTopBar(find.text('Encrypted Account')), findsOneWidget);
      expect(tester.getSize(_inTopBar(find.byType(EncryptedLockBadge))), const Size.square(24));
      final lock = find.descendant(of: _inTopBar(find.byType(EncryptedLockBadge)), matching: find.byType(QuantusIcon));
      expect(tester.widget<QuantusIcon>(lock).size, 12);
    });

    testOnMac('the account actions are in the top bar, not in the panels', (tester) async {
      await pumpShell(tester, overrides: _withActive(const RegularAccount(mainAccount)));

      expect(_inTopBar(find.byType(AccountToolbar)), findsOneWidget);
      expect(find.descendant(of: find.byType(AccountPane), matching: find.byType(AccountToolbar)), findsNothing);
      expect(find.byType(AccountToolbar), findsOneWidget);
    });

    testOnMac('the sidebar\'s switch hides the sidebar and brings it back, staying in place', (tester) async {
      await pumpShell(tester, overrides: _withActive(const RegularAccount(mainAccount)));
      final where = tester.getTopLeft(_inTopBar(find.byTooltip('Hide Sidebar')));

      await tester.tap(_inTopBar(find.byTooltip('Hide Sidebar')));
      await tester.pumpAndSettle();

      expect(find.byType(Sidebar), findsNothing);
      final show = _inTopBar(find.byTooltip('Show Sidebar'));
      expect(tester.getTopLeft(show), where);

      await tester.tap(show);
      await tester.pumpAndSettle();

      expect(find.byType(Sidebar), findsOneWidget);
      expect(_inTopBar(find.byTooltip('Hide Sidebar')), findsOneWidget);
    });

    for (final (where, point) in [('by the sidebar', _emptyBarBySidebar), ('over the panels', _emptyBarOverPanels)]) {
      testOnMac('dragging empty top bar space $where asks the window to start a drag', (tester) async {
        final requests = recordWindowRequests(tester);
        await pumpShell(tester, overrides: _withActive(const RegularAccount(mainAccount)));

        await tester.dragFrom(point, const Offset(80, 30));
        await tester.pumpAndSettle();

        expect(requests, ['startDrag']);
      });

      testOnMac('double-clicking empty top bar space $where sends the title bar double-click', (tester) async {
        final requests = recordWindowRequests(tester);
        await pumpShell(tester, overrides: _withActive(const RegularAccount(mainAccount)));

        await tester.tapAt(point);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tapAt(point);
        await tester.pumpAndSettle();

        expect(requests, ['titleBarDoubleClick']);
      });
    }

    testOnMac('dragging the wordmark, or the account named in the bar, moves the window', (tester) async {
      final requests = recordWindowRequests(tester);
      await pumpShell(tester, overrides: _withActive(const RegularAccount(mainAccount)));
      await _hideSidebar(tester);

      await tester.drag(_wordmark, const Offset(80, 30));
      await tester.pumpAndSettle();
      await tester.drag(_inTopBar(find.text('Main')), const Offset(80, 30));
      await tester.pumpAndSettle();

      expect(requests, ['startDrag', 'startDrag']);
    });

    testOnMac('pressing or dragging a top bar button does not move the window', (tester) async {
      final requests = recordWindowRequests(tester);
      await pumpShell(tester, overrides: _withActive(const RegularAccount(mainAccount)));

      await tester.drag(_inTopBar(find.widgetWithText(ToolbarAction, 'Receive')), const Offset(60, 0));
      await tester.pumpAndSettle();
      await tester.tap(_inTopBar(find.widgetWithText(ToolbarAction, 'Send')));
      await tester.pumpAndSettle();

      expect(find.descendant(of: find.byType(ShellSheetView), matching: find.text('Send')), findsOneWidget);
      expect(requests, isEmpty);
    });

    testOnMac('dragging below the top bar does not move the window', (tester) async {
      final requests = recordWindowRequests(tester);
      await pumpShell(tester, overrides: _withActive(const RegularAccount(mainAccount)));

      await tester.dragFrom(const Offset(700, 400), const Offset(80, 30));
      await tester.pumpAndSettle();

      expect(requests, isEmpty);
    });

    testOnMac('the last action ends 20pt from the window\'s right edge', (tester) async {
      await pumpShell(tester, overrides: _withActive(const RegularAccount(mainAccount)));

      final swap = find.descendant(of: find.widgetWithText(ToolbarAction, 'Swap'), matching: find.text('Swap'));
      expect(tester.getRect(swap).right, moreOrLessEquals(1200 - ShellTopBar.edgePadding, epsilon: 0.5));
    });
  });

  group('on Windows and Linux', () {
    testOnWindowsAndLinux('the top bar starts with the wordmark at its edge, with no gap for traffic lights and no '
        'drag area', (tester) async {
      final requests = recordWindowRequests(tester);
      await pumpShell(tester, overrides: _withActive(const RegularAccount(mainAccount)));

      expect(tester.getTopLeft(_wordmark).dx - tester.getTopLeft(find.byType(ShellTopBar)).dx, ShellTopBar.edgePadding);
      expect(find.byType(WindowDragArea), findsNothing);
      expect(_inTopBar(find.byType(AccountToolbar)), findsOneWidget);

      final barTop = tester.getTopLeft(find.byType(ShellTopBar)).dy;
      await tester.dragFrom(Offset(700, barTop + 26), const Offset(80, 30));
      await tester.pumpAndSettle();

      expect(requests, isEmpty);

      await tester.tap(_inTopBar(find.byTooltip('Hide Sidebar')));
      await tester.pumpAndSettle();

      expect(find.byType(Sidebar), findsNothing);
      expect(_inTopBar(find.text('Main')), findsOneWidget);
    });
  });
}
