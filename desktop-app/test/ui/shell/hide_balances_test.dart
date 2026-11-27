import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/ui/activity/activity_inspector.dart';
import 'package:quantus_desktop_wallet/ui/activity/activity_row_view.dart';
import 'package:quantus_desktop_wallet/ui/activity/open_proposals_panel.dart';
import 'package:quantus_desktop_wallet/ui/components/balance_card.dart';
import 'package:quantus_desktop_wallet/ui/components/sidebar_row.dart';
import 'package:quantus_desktop_wallet/ui/components/toolbar_action.dart';
import 'package:quantus_desktop_wallet/ui/shell/account_toolbar.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_view.dart';
import 'package:quantus_desktop_wallet/ui/shell/sidebar.dart';
import 'package:quantus_desktop_wallet/ui/swap/swap_row_view.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/utils/hidden_amount.dart';

import '../../fakes.dart';

const _bob = 'qzBob4hGy7UwE2nXk9VcMp3QsLd6TfRa8ZoJi1Wb5eNt9cPu';
final _now = DateTime.now();

/// Main (active) and Savings in Wallet 1, Trading in a closed Wallet 2; Main
/// sent 75 QTC to Bob a day ago. Balances are hidden when [hidden].
Future<FakeSettingsService> _pump(WidgetTester tester, {bool hidden = false}) async {
  final settings = FakeSettingsService(activeAccount: const RegularAccount(mainAccount))..balanceHidden = hidden;
  await pumpShell(
    tester,
    overrides: shellOverrides(
      accounts: const [mainAccount, savingsAccount, tradingAccount],
      settings: settings,
      balances: oneTokenEach,
      chain: FakeSendChain()
        ..historyPages = [
          [
            TransferEvent(
              id: 'sent',
              from: 'qzMain',
              to: _bob,
              amount: oneToken * BigInt.from(75),
              timestamp: _now.subtract(const Duration(days: 1)),
              fee: FakeSendChain.usualFee,
              extrinsicHash: '0xsent',
              blockNumber: 1,
              blockHash: '0xblock',
            ),
          ],
        ],
    ),
  );
  return settings;
}

List<PlatformMenuItem> _viewItems(WidgetTester tester) {
  final menus = tester.widget<PlatformMenuBar>(find.byType(PlatformMenuBar)).menus.cast<PlatformMenu>();
  return [
    for (final entry in menus.singleWhere((menu) => menu.label == 'View').menus)
      if (entry is PlatformMenuItemGroup) ...entry.members else entry,
  ];
}

PlatformMenuItem? _viewItem(WidgetTester tester, String label) =>
    _viewItems(tester).where((item) => item.label == label).firstOrNull;

Future<void> _choose(WidgetTester tester, String label) async {
  _viewItem(tester, label)!.onSelected!();
  await tester.pumpAndSettle();
}

Finder _inCard(Finder finder) => find.descendant(of: find.byType(BalanceCard), matching: finder);

Finder _inSidebar(Finder finder) => find.descendant(of: find.byType(Sidebar), matching: finder);

Finder _row(String title) => _inSidebar(find.widgetWithText(SidebarRow, title));

Finder _activityRow(String id) => find.byWidgetPredicate((widget) => widget is ActivityRowView && widget.id == id);

Finder get _eye => find.byKey(BalanceCard.hideBalancesKey);

void main() {
  testOnMac('View › Hide Balances (⇧⌘B) hides the amounts; then Show Balances shows them again', (tester) async {
    await _pump(tester);
    final hide = _viewItem(tester, 'Hide Balances')!;
    final keys = hide.shortcut! as SingleActivator;
    expect(
      (keys.trigger, keys.meta, keys.shift, keys.control, keys.alt),
      (LogicalKeyboardKey.keyB, true, true, false, false),
    );
    expect(_inCard(find.text(hiddenAmountText)), findsNothing);

    await _choose(tester, 'Hide Balances');
    expect(_inCard(find.text(hiddenAmountText)), findsOneWidget);
    expect(_viewItem(tester, 'Hide Balances'), isNull);

    await _choose(tester, 'Show Balances');
    expect(_inCard(find.text(hiddenAmountText)), findsNothing);
    expect(_viewItem(tester, 'Hide Balances'), isNotNull);
  });

  testOnMac('the balance card\'s eye hides and shows them, and says which it will do', (tester) async {
    await _pump(tester);
    expect(tester.widget<ToolbarAction>(_eye).label, 'Hide Balances');
    expect(find.descendant(of: _eye, matching: find.byIcon(CupertinoIcons.eye)), findsOneWidget);

    await tester.tap(_eye);
    await tester.pumpAndSettle();
    expect(_inCard(find.text(hiddenAmountText)), findsOneWidget);
    expect(tester.widget<ToolbarAction>(_eye).label, 'Show Balances');
    expect(find.descendant(of: _eye, matching: find.byIcon(CupertinoIcons.eye_slash)), findsOneWidget);

    await tester.tap(_eye);
    await tester.pumpAndSettle();
    expect(_inCard(find.text(hiddenAmountText)), findsNothing);
  });

  testOnMac('the choice is saved, and the app opens with balances hidden when they were left hidden', (tester) async {
    final settings = await _pump(tester);
    await tester.tap(_eye);
    await tester.pumpAndSettle();
    expect(settings.balanceHidden, isTrue);
  });

  testOnMac('opened with balances hidden, they are hidden', (tester) async {
    await _pump(tester, hidden: true);
    expect(_inCard(find.text(hiddenAmountText)), findsOneWidget);
    expect(_viewItem(tester, 'Show Balances'), isNotNull);
  });

  testOnMac('while hidden, the card shows the mask with no token symbol, and its line in dollars is masked too', (
    tester,
  ) async {
    await _pump(tester, hidden: true);
    expect(_inCard(find.text(hiddenAmountText)), findsOneWidget);
    expect(_inCard(find.text(AppConstants.tokenSymbol)), findsNothing);
    expect(_inCard(find.text('≈ $hiddenAmountText')), findsOneWidget);
    expect(_inCard(find.textContaining(r'$')), findsNothing);
  });

  testOnMac('while hidden, every sidebar row and a closed group\'s total are masked, and heard as Hidden', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, hidden: true);

    for (final name in ['Main', 'Savings']) {
      expect(
        find.descendant(of: _row(name), matching: find.text(hiddenAmountText)),
        findsOneWidget,
        reason: name,
      );
      expect(
        find.descendant(of: _row(name), matching: find.textContaining('QTC')),
        findsNothing,
        reason: name,
      );
    }
    expect(
      find.descendant(of: find.byKey(const ValueKey('sidebar-wallet-2')), matching: find.text(hiddenAmountText)),
      findsOneWidget,
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Wallet 2')),
      isSemantics(label: 'Wallet 2', value: '1 account, Hidden'),
    );
    semantics.dispose();
  });

  testOnMac('while hidden, an activity row shows the mask with no sign', (tester) async {
    await _pump(tester, hidden: true);
    expect(find.descendant(of: _activityRow('sent'), matching: find.text(hiddenAmountText)), findsOneWidget);
    expect(find.descendant(of: _activityRow('sent'), matching: find.textContaining('75')), findsNothing);
  });

  testOnMac('while hidden, the panel at the right still shows what a transaction moved', (tester) async {
    await _pump(tester, hidden: true);
    await tester.tap(_activityRow('sent'));
    await tester.pumpAndSettle();

    final inspector = find.byType(ActivityInspector);
    expect(find.descendant(of: inspector, matching: find.text('75 QTC')), findsOneWidget);
    expect(find.descendant(of: inspector, matching: find.text(hiddenAmountText)), findsNothing);
  });

  testOnMac('while hidden, Send still shows what is available to send', (tester) async {
    await _pump(tester, hidden: true);
    await tester.tap(
      find.descendant(of: find.byType(AccountToolbar), matching: find.widgetWithText(ToolbarAction, 'Send')),
    );
    await tester.pumpAndSettle();

    final sheet = find.byType(ShellSheetView);
    final available = find.descendant(
      of: sheet,
      matching: find.ancestor(of: find.text('Available'), matching: find.byType(Row)),
    );
    expect(find.descendant(of: available.first, matching: find.text('1 QTC')), findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text(hiddenAmountText)), findsNothing);
  });

  testOnMac('while hidden, an open proposal\'s row shows the mask', (tester) async {
    final settings = FakeSettingsService(activeAccount: MultisigDisplayAccount(teamMultisig), multisigs: [teamMultisig])
      ..balanceHidden = true;
    await pumpShell(
      tester,
      overrides: shellOverrides(
        accounts: const [mainAccount],
        settings: settings,
        balances: oneTokenEach,
        chain: FakeSendChain()
          ..openProposals = [
            MultisigProposal(
              entityId: 'proposal-1',
              id: 1,
              multisigAddress: teamMultisig.accountId,
              proposer: 'qzOther',
              createdAt: _now.subtract(const Duration(hours: 1)),
              updatedAt: _now.subtract(const Duration(hours: 1)),
              pallet: '',
              call: '',
              recipient: _bob,
              amount: oneToken * BigInt.from(100),
              expiryBlock: 1300000,
              approvals: const [],
              deposit: oneToken,
              status: MultisigProposalStatus.active,
              threshold: teamMultisig.threshold,
              signerCount: teamMultisig.signers.length,
            ),
          ],
      ),
    );

    final row = find.byType(OpenProposalRowView);
    expect(find.descendant(of: row, matching: find.text(hiddenAmountText)), findsOneWidget);
    expect(find.descendant(of: row, matching: find.textContaining('100')), findsNothing);
  });

  testOnMac('while hidden, a swap\'s row masks what is paid and what for', (tester) async {
    final settings = FakeSettingsService(activeAccount: const RegularAccount(mainAccount))
      ..activeSwaps = [fakeActiveSwap()]
      ..balanceHidden = true;
    await pumpShell(
      tester,
      overrides: shellOverrides(accounts: const [mainAccount], settings: settings, balances: oneTokenEach),
    );

    final row = find.byType(SwapRowView);
    expect(find.descendant(of: row, matching: find.text(hiddenAmountText)), findsOneWidget);
    expect(find.descendant(of: row, matching: find.textContaining('250')), findsNothing);
    expect(find.descendant(of: row, matching: find.textContaining('104.37')), findsNothing);
  });
}
