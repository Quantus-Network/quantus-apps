import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/ui/components/toolbar_action.dart';
import 'package:quantus_desktop_wallet/ui/components/window_drag_area.dart';
import 'package:quantus_desktop_wallet/ui/shell/account_pane.dart';
import 'package:quantus_desktop_wallet/ui/shell/account_toolbar.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_header.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_view.dart';
import 'package:quantus_desktop_wallet/ui/shell/sidebar.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_desktop_wallet/ui/components/balance_card.dart';

import '../../fakes.dart';

/// Where the system draws the last traffic light's right edge: 20pt in, three
/// 14pt buttons 20pt apart. The Swift side places them; nothing the app draws
/// may start left of this.
const double _trafficLightsRightEdge = 74;

/// A point of empty header space over the sidebar, and one over the pane.
const _emptySidebarHeader = Offset(150, 26);
const _emptyPaneHeader = Offset(700, 26);

Finder _inSidebarHeader(Finder matching) => find.descendant(of: find.byType(SidebarHeader), matching: matching);

Finder _inPaneHeader(Finder matching) => find.descendant(of: find.byType(PaneHeader), matching: matching);

List<Override> _withActive(DisplayAccount active) => shellOverrides(
  accounts: const [mainAccount, encryptedAccount],
  settings: FakeSettingsService(activeAccount: active),
  balances: oneTokenEach,
  encryptedBalances: {0: oneToken},
);

void main() {
  group('on macOS', () {
    testOnMac('the sidebar side of the header shows the app name, clear of the traffic lights', (tester) async {
      await pumpShell(tester, overrides: _withActive(const RegularAccount(mainAccount)));

      final name = _inSidebarHeader(find.text('Quantus Wallet'));
      expect(name, findsOneWidget);
      expect(tester.getTopLeft(name).dx, greaterThanOrEqualTo(_trafficLightsRightEdge));
      expect(tester.getTopLeft(find.byType(SidebarHeader)), Offset.zero);
    });

    testOnMac('everything in the header is centred on the middle of its 52pt row, where the traffic lights are', (
      tester,
    ) async {
      await pumpShell(tester, overrides: _withActive(const RegularAccount(encryptedAccount)));

      for (final finder in [
        _inSidebarHeader(find.text('Quantus Wallet')),
        _inSidebarHeader(find.byTooltip('Hide Sidebar')),
        _inPaneHeader(find.text('Encrypted Account')),
        _inPaneHeader(find.byType(EncryptedLockBadge)),
        _inPaneHeader(find.widgetWithText(ToolbarAction, 'Receive')),
      ]) {
        expect(tester.getCenter(finder).dy, moreOrLessEquals(26, epsilon: 0.5), reason: '$finder');
      }
      expect(tester.getSize(find.byType(SidebarHeader)).height, 52);
      expect(tester.getSize(find.byType(PaneHeader)).height, 52);
    });

    testOnMac('the header title is the active account\'s name, with no lock badge on a transparent account', (
      tester,
    ) async {
      await pumpShell(tester, overrides: _withActive(const RegularAccount(mainAccount)));

      expect(_inPaneHeader(find.text('Main')), findsOneWidget);
      expect(_inPaneHeader(find.byType(EncryptedLockBadge)), findsNothing);
      expect(tester.getTopLeft(find.byType(PaneHeader)), const Offset(Sidebar.width, 0));
    });

    testOnMac('on the encrypted account the lock badge sits beside the header title', (tester) async {
      await pumpShell(tester, overrides: _withActive(const RegularAccount(encryptedAccount)));

      expect(_inPaneHeader(find.text('Encrypted Account')), findsOneWidget);
      expect(_inPaneHeader(find.byType(EncryptedLockBadge)), findsOneWidget);
    });

    testOnMac('the account actions are in the header, not in the pane body', (tester) async {
      await pumpShell(tester, overrides: _withActive(const RegularAccount(mainAccount)));

      expect(_inPaneHeader(find.byType(AccountToolbar)), findsOneWidget);
      expect(find.descendant(of: find.byType(AccountPane), matching: find.byType(AccountToolbar)), findsNothing);
      expect(find.byType(AccountToolbar), findsOneWidget);
    });

    testOnMac('with Mining Rewards selected the title is Mining Rewards and there are no account actions', (
      tester,
    ) async {
      await pumpShell(tester, overrides: _withActive(const RegularAccount(mainAccount)));

      await tester.tap(find.descendant(of: find.byType(Sidebar), matching: find.text('Mining Rewards')));
      await tester.pumpAndSettle();

      expect(_inPaneHeader(find.text('Mining Rewards')), findsOneWidget);
      expect(_inPaneHeader(find.text('Main')), findsNothing);
      expect(find.byType(AccountToolbar), findsNothing);
    });

    testOnMac('the sidebar button hides the sidebar, stays clear of the traffic lights, and brings it back', (
      tester,
    ) async {
      await pumpShell(tester, overrides: _withActive(const RegularAccount(mainAccount)));

      await tester.tap(_inSidebarHeader(find.byTooltip('Hide Sidebar')));
      await tester.pumpAndSettle();

      expect(find.byType(Sidebar), findsNothing);
      final show = _inPaneHeader(find.byTooltip('Show Sidebar'));
      expect(show, findsOneWidget);
      expect(tester.getTopLeft(show).dx, greaterThanOrEqualTo(_trafficLightsRightEdge));
      expect(tester.getTopLeft(find.byType(PaneHeader)), Offset.zero);

      await tester.tap(show);
      await tester.pumpAndSettle();

      expect(find.byType(Sidebar), findsOneWidget);
      expect(_inPaneHeader(find.byTooltip('Show Sidebar')), findsNothing);
      expect(_inSidebarHeader(find.byTooltip('Hide Sidebar')), findsOneWidget);
    });

    for (final (side, point) in [('sidebar', _emptySidebarHeader), ('pane', _emptyPaneHeader)]) {
      testOnMac('dragging empty header space over the $side asks the window to start a drag', (tester) async {
        final requests = recordWindowRequests(tester);
        await pumpShell(tester, overrides: _withActive(const RegularAccount(mainAccount)));

        await tester.dragFrom(point, const Offset(80, 30));
        await tester.pumpAndSettle();

        expect(requests, ['startDrag']);
      });

      testOnMac('double-clicking empty header space over the $side sends the title bar double-click', (tester) async {
        final requests = recordWindowRequests(tester);
        await pumpShell(tester, overrides: _withActive(const RegularAccount(mainAccount)));

        await tester.tapAt(point);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tapAt(point);
        await tester.pumpAndSettle();

        expect(requests, ['titleBarDoubleClick']);
      });
    }

    testOnMac('pressing or dragging a header button does not move the window', (tester) async {
      final requests = recordWindowRequests(tester);
      await pumpShell(tester, overrides: _withActive(const RegularAccount(mainAccount)));

      await tester.drag(_inPaneHeader(find.widgetWithText(ToolbarAction, 'Receive')), const Offset(60, 0));
      await tester.pumpAndSettle();
      await tester.tap(_inPaneHeader(find.widgetWithText(ToolbarAction, 'Send')));
      await tester.pumpAndSettle();

      expect(find.descendant(of: find.byType(ShellSheetView), matching: find.text('Send')), findsOneWidget);
      expect(requests, isEmpty);
    });

    testOnMac('dragging below the header does not move the window', (tester) async {
      final requests = recordWindowRequests(tester);
      await pumpShell(tester, overrides: _withActive(const RegularAccount(mainAccount)));

      await tester.dragFrom(const Offset(700, 400), const Offset(80, 30));
      await tester.pumpAndSettle();

      expect(requests, isEmpty);
    });
  });

  group('on Windows and Linux', () {
    testOnWindowsAndLinux('the header has no app name, no gap for traffic lights and no drag area', (tester) async {
      final requests = recordWindowRequests(tester);
      await pumpShell(tester, overrides: _withActive(const RegularAccount(mainAccount)));

      expect(_inSidebarHeader(find.text('Quantus Wallet')), findsNothing);
      expect(find.byType(WindowDragArea), findsNothing);
      expect(_inPaneHeader(find.text('Main')), findsOneWidget);
      expect(_inPaneHeader(find.byType(AccountToolbar)), findsOneWidget);

      final headerTop = tester.getTopLeft(find.byType(PaneHeader)).dy;
      await tester.dragFrom(Offset(700, headerTop + 26), const Offset(80, 30));
      await tester.pumpAndSettle();

      expect(requests, isEmpty);

      await tester.tap(_inSidebarHeader(find.byTooltip('Hide Sidebar')));
      await tester.pumpAndSettle();

      expect(find.byType(Sidebar), findsNothing);
      expect(tester.getTopLeft(_inPaneHeader(find.byTooltip('Show Sidebar'))).dx, lessThan(_trafficLightsRightEdge));
    });
  });

  testOnMac('the header\'s title starts, and its last action ends, on the pane content\'s edges', (tester) async {
    await pumpShell(tester, overrides: _withActive(const RegularAccount(mainAccount)));
    final content = tester.getRect(find.byType(BalanceCard));

    expect(tester.getRect(_inPaneHeader(find.text('Main'))).left, moreOrLessEquals(content.left, epsilon: 0.5));
    final swap = find.descendant(of: find.widgetWithText(ToolbarAction, 'Swap'), matching: find.text('Swap'));
    expect(tester.getRect(swap).right, moreOrLessEquals(content.right, epsilon: 0.5));
  });
}
