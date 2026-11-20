import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/providers/activity_providers.dart';
import 'package:quantus_desktop_wallet/ui/activity/activity_inspector.dart';
import 'package:quantus_desktop_wallet/ui/activity/activity_panel.dart';
import 'package:quantus_desktop_wallet/ui/activity/activity_row_view.dart';
import 'package:quantus_desktop_wallet/ui/components/panel.dart';
import 'package:quantus_desktop_wallet/ui/components/toolbar_action.dart';
import 'package:quantus_desktop_wallet/ui/shell/account_toolbar.dart';
import 'package:quantus_desktop_wallet/ui/shell/desktop_shell.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_view.dart';
import 'package:quantus_desktop_wallet/ui/shell/sidebar.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

import '../../fakes.dart';

final _now = DateTime.now();

TransferEvent _received(String id, Duration ago) => TransferEvent(
  id: id,
  from: 'qzBob4hGy7UwE2nXk9VcMp3QsLd6TfRa8ZoJi1Wb5eNt9cPu',
  to: 'qzMain',
  amount: oneToken,
  timestamp: _now.subtract(ago),
  fee: BigInt.one,
  extrinsicHash: '0x$id',
  blockNumber: 1,
  blockHash: '0xblock',
);

final _scheduled = ReversibleTransferEvent(
  id: 'scheduled',
  from: 'qzMain',
  to: 'qzBob',
  amount: oneToken,
  timestamp: _now,
  txId: '0xtxid',
  status: ReversibleTransferStatus.SCHEDULED,
  scheduledAt: _now.add(const Duration(hours: 5)),
  blockNumber: 1,
  blockHash: '0xblock',
);

Future<void> _open(WidgetTester tester, {Size? window}) async {
  await pumpShell(
    tester,
    overrides: shellOverrides(
      accounts: const [mainAccount],
      settings: FakeSettingsService(activeAccount: const RegularAccount(mainAccount)),
      balances: oneTokenEach,
      chain: FakeSendChain()
        ..scheduledTransfers = [_scheduled]
        ..historyPages = [
          [_received('first', const Duration(hours: 1)), _received('second', const Duration(hours: 2))],
        ],
    ),
  );
  if (window != null) {
    tester.view.physicalSize = window;
    await tester.pumpAndSettle();
  }
}

String? _opened(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(DesktopShell))).read(openedActivityViewProvider)?.id;

Future<void> _click(WidgetTester tester, String id) async {
  await tester.tap(find.byWidgetPredicate((widget) => widget is ActivityRowView && widget.id == id));
  await tester.pumpAndSettle();
}

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

bool _isFocused(WidgetTester tester, Finder panel) =>
    tester.widget<Panel>(find.descendant(of: panel, matching: find.byType(Panel)).first).isFocused;

void main() {
  testOnMac('↑ and ↓ walk In progress and Activity as one list, and the panel follows', (tester) async {
    await _open(tester);
    await _click(tester, 'scheduled');

    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(_opened(tester), 'first');
    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(_opened(tester), 'second');
    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(_opened(tester), 'second', reason: 'the last stays');
    await _press(tester, LogicalKeyboardKey.arrowUp);
    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(_opened(tester), 'scheduled');
    expect(find.byType(ActivityInspector), findsOne);
  });

  testOnMac('a click puts the keys in the list: the panel holding the open row has the lighter border', (tester) async {
    await _open(tester);
    expect(_isFocused(tester, find.byType(ActivityPanel)), isFalse);

    await _click(tester, 'first');

    expect(_isFocused(tester, find.byType(ActivityPanel)), isTrue);
    expect(_isFocused(tester, find.byType(ActivityInspector)), isFalse);
  });

  testOnMac('Tab moves the keys into the panel at the right: its border brightens, the list\'s selection quiets', (
    tester,
  ) async {
    await _open(tester);
    await _click(tester, 'first');

    await _press(tester, LogicalKeyboardKey.tab);

    expect(_isFocused(tester, find.byType(ActivityInspector)), isTrue);
    expect(_isFocused(tester, find.byType(ActivityPanel)), isFalse);
    final row = tester.widget<ActivityRowView>(find.byWidgetPredicate((w) => w is ActivityRowView && w.id == 'first'));
    expect((row.isSelected, row.hasFocus), (true, false));
  });

  testOnMac('Esc closes the panel and leaves the keys in the list', (tester) async {
    await _open(tester);
    await _click(tester, 'first');

    await _press(tester, LogicalKeyboardKey.escape);

    expect(find.byType(ActivityInspector), findsNothing);
    expect(_isFocused(tester, find.byType(ActivityPanel)), isTrue);
    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(_opened(tester), isNotNull, reason: 'the keys still walk the list');
  });

  testOnMac('Esc in the panel at the right closes it too, and the keys go back to the list', (tester) async {
    await _open(tester);
    await _click(tester, 'first');
    await _press(tester, LogicalKeyboardKey.tab);

    await _press(tester, LogicalKeyboardKey.escape);

    expect(find.byType(ActivityInspector), findsNothing);
    expect(_isFocused(tester, find.byType(ActivityPanel)), isTrue);
  });

  testOnMac('in the smallest window, with the sidebar and the panel at the right, the rows are brief', (tester) async {
    await _open(tester, window: const Size(960, 640));
    await _click(tester, 'first');

    final forms = {
      for (final row in tester.widgetList<ActivityRowView>(
        find.descendant(of: find.byType(ActivityPanel), matching: find.byType(ActivityRowView)),
      ))
        row.form,
    };
    expect(forms, {ActivityRowForm.brief});
  });

  testOnMac('with the panel at the right open, a sheet still hangs centred on the panels beside the sidebar', (
    tester,
  ) async {
    await _open(tester);
    await _click(tester, 'first');

    await tester.tap(
      find.descendant(of: find.byType(AccountToolbar), matching: find.widgetWithText(ToolbarAction, 'Receive')),
    );
    await tester.pumpAndSettle();

    final left = tester.getRect(find.byType(Sidebar)).right + Panel.gap;
    expect(tester.getRect(find.byType(ShellSheetView)).center.dx, moreOrLessEquals((left + 1200 - Panel.gap) / 2));
  });
}
