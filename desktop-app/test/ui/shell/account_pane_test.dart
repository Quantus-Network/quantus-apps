import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/providers/activity_providers.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/ui/activity/activity_inspector.dart';
import 'package:quantus_desktop_wallet/ui/activity/activity_panel.dart';
import 'package:quantus_desktop_wallet/ui/activity/activity_row_view.dart';
import 'package:quantus_desktop_wallet/ui/shell/panel_widths.dart';
import 'package:quantus_desktop_wallet/ui/shell/sidebar.dart';
import 'package:quantus_desktop_wallet/ui/components/balance_card.dart';
import 'package:quantus_desktop_wallet/ui/components/panel.dart';
import 'package:quantus_desktop_wallet/ui/components/toolbar_action.dart';
import 'package:quantus_desktop_wallet/ui/shell/account_pane.dart';
import 'package:quantus_desktop_wallet/ui/settings/settings_sheet.dart';
import 'package:quantus_desktop_wallet/ui/shell/account_toolbar.dart';
import 'package:quantus_desktop_wallet/ui/shell/backup_reminder.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_header.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_view.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/wallet_providers.dart';

import '../../fakes.dart';

Finder _inPane(Finder matching) => find.descendant(of: find.byType(AccountPane), matching: matching);

Finder _toolbarButton(String label) =>
    find.descendant(of: find.byType(AccountToolbar), matching: find.widgetWithText(ToolbarAction, label));

List<String> _toolbarLabels(WidgetTester tester) => [
  for (final label in ['Receive', 'Send', 'Propose', 'Swap'])
    if (_toolbarButton(label).evaluate().isNotEmpty) label,
];

Finder _inBalanceCard(Finder matching) => find.descendant(of: find.byType(BalanceCard), matching: matching);

Finder _sheetTitled(String title) => find.descendant(of: find.byType(ShellSheetView), matching: find.text(title));

Future<void> _pumpWithActive(WidgetTester tester, DisplayAccount active, {bool swapAvailable = true}) {
  return pumpShell(
    tester,
    overrides: shellOverrides(
      accounts: const [mainAccount, encryptedAccount, vaultAccount],
      settings: FakeSettingsService(activeAccount: active, multisigs: [teamMultisig]),
      balances: oneTokenEach,
      encryptedBalances: {0: oneToken},
      swapAvailable: swapAvailable,
    ),
  );
}

void main() {
  testOnMac('the balance\'s panel shows the active account\'s balance, and no name above it', (tester) async {
    final balance = oneToken * BigInt.from(5);
    await pumpShell(
      tester,
      overrides: shellOverrides(
        accounts: const [mainAccount],
        settings: FakeSettingsService(activeAccount: const RegularAccount(mainAccount)),
        balances: {'qzMain': balance},
      ),
    );

    final container = ProviderScope.containerOf(tester.element(find.byType(AccountPane)));
    final formatted = container.read(numberFormattingServiceProvider).formatBalance(balance);
    expect(find.descendant(of: find.byType(ShellTopBar), matching: find.text('Main')), findsNothing);
    expect(_inPane(find.text('Main')), findsNothing);
    expect(_inBalanceCard(find.text(formatted)), findsOneWidget);
  });

  testOnMac('the balance sits in a card labelled BALANCE: the amount large, the token symbol small after it', (
    tester,
  ) async {
    await _pumpWithActive(tester, const RegularAccount(mainAccount));

    final container = ProviderScope.containerOf(tester.element(find.byType(AccountPane)));
    final amount = _inBalanceCard(find.text(container.read(numberFormattingServiceProvider).formatBalance(oneToken)));
    final symbol = _inBalanceCard(find.text(AppConstants.tokenSymbol));
    expect(_inBalanceCard(find.text('BALANCE')), findsOneWidget);
    expect(_inBalanceCard(find.bySemanticsLabel('Balance')), findsOneWidget);
    expect(tester.getTopLeft(_inBalanceCard(find.text('BALANCE'))).dy, lessThan(tester.getTopLeft(amount).dy));
    expect(tester.getTopLeft(symbol).dx, greaterThan(tester.getTopRight(amount).dx));
    expect(tester.widget<Text>(amount).style!.fontSize, greaterThan(2 * tester.widget<Text>(symbol).style!.fontSize!));
    // The card runs the width of the pane; the shell keeps the gaps around it.
    final card = tester.getRect(find.byType(BalanceCard));
    final pane = tester.getRect(find.byType(AccountPane));
    expect(card.left, pane.left);
    expect(card.right, pane.right);
  });

  testOnMac('while the balance loads the card says so, and it says when the balance is unavailable', (tester) async {
    final arrives = Completer<BigInt>();
    await pumpShell(
      tester,
      overrides: shellOverrides(
        accounts: const [mainAccount],
        settings: FakeSettingsService(activeAccount: const RegularAccount(mainAccount)),
        balanceOf: (_) => arrives.future,
      ),
      settle: false,
    );
    await tester.pump();

    expect(_inBalanceCard(find.text('Loading...')), findsOneWidget);
    expect(_inBalanceCard(find.text(AppConstants.tokenSymbol)), findsNothing);

    arrives.completeError(StateError('offline'));
    await tester.pumpAndSettle();

    expect(_inBalanceCard(find.text('Balance unavailable')), findsOneWidget);
    expect(_inBalanceCard(find.text(AppConstants.tokenSymbol)), findsNothing);
  });

  testOnMac('the balance is a panel right under the top bar', (tester) async {
    await _pumpWithActive(tester, const RegularAccount(mainAccount));

    final bar = tester.getRect(find.byType(ShellTopBar));
    final balance = tester.getRect(find.byType(BalanceCard));
    expect(balance.top, bar.bottom);
    expect(find.descendant(of: find.byType(BalanceCard), matching: find.byType(Panel)), findsOneWidget);
  });

  testOnMac('a local account\'s toolbar offers Receive, Send and Swap', (tester) async {
    await _pumpWithActive(tester, const RegularAccount(mainAccount));

    expect(_toolbarLabels(tester), ['Receive', 'Send', 'Swap']);
  });

  testOnMac('each toolbar action carries the icon the mobile app gives it', (tester) async {
    QuantusIcons iconOf(String label) =>
        tester.widget<QuantusIcon>(find.descendant(of: _toolbarButton(label), matching: find.byType(QuantusIcon))).icon;

    await _pumpWithActive(tester, const RegularAccount(mainAccount));

    expect(iconOf('Receive'), QuantusIcons.actionReceive);
    expect(iconOf('Send'), QuantusIcons.actionSend);
    expect(iconOf('Swap'), QuantusIcons.actionSwap);
  });

  testOnMac('Propose carries the Send icon, as on the mobile app', (tester) async {
    await _pumpWithActive(tester, MultisigDisplayAccount(teamMultisig));

    expect(
      tester
          .widget<QuantusIcon>(find.descendant(of: _toolbarButton('Propose'), matching: find.byType(QuantusIcon)))
          .icon,
      QuantusIcons.actionSend,
    );
  });

  testOnMac('where swaps are not offered the toolbar has no Swap', (tester) async {
    await _pumpWithActive(tester, const RegularAccount(mainAccount), swapAvailable: false);

    expect(_toolbarLabels(tester), ['Receive', 'Send']);
  });

  testOnMac('a multisig\'s toolbar offers Receive and Propose', (tester) async {
    await _pumpWithActive(tester, MultisigDisplayAccount(teamMultisig));

    expect(_toolbarLabels(tester), ['Receive', 'Propose']);
  });

  testOnMac('a Keystone account\'s Swap is shown disabled and opens nothing', (tester) async {
    await _pumpWithActive(tester, const RegularAccount(vaultAccount));

    expect(_toolbarLabels(tester), ['Receive', 'Send', 'Swap']);

    await tester.tap(_toolbarButton('Swap'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.byType(ShellSheetView), findsNothing);
  });

  for (final (account, label) in <(DisplayAccount, String)>[
    (const RegularAccount(mainAccount), 'Receive'),
    (const RegularAccount(mainAccount), 'Send'),
    (const RegularAccount(mainAccount), 'Swap'),
    (MultisigDisplayAccount(teamMultisig), 'Propose'),
  ]) {
    testOnMac('$label opens a sheet with its title, and Esc closes it', (tester) async {
      await _pumpWithActive(tester, account);

      await tester.tap(_toolbarButton(label));
      await tester.pumpAndSettle();

      expect(_sheetTitled(label), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(ShellSheetView), findsNothing);
    });
  }

  testOnMac('a sheet\'s Close button closes it, and another sheet can open afterwards', (tester) async {
    await _pumpWithActive(tester, const RegularAccount(mainAccount));

    await tester.tap(_toolbarButton('Send'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(ShellSheetView), matching: find.byTooltip('Close')));
    await tester.pumpAndSettle();

    expect(find.byType(ShellSheetView), findsNothing);

    await tester.tap(_toolbarButton('Receive'));
    await tester.pumpAndSettle();

    expect(_sheetTitled('Receive'), findsOneWidget);
  });

  // The sidebar's row and its lock already say it is the Encrypted account
  // (the user's call, round 31): the phone's notice is not needed here.
  testOnMac('on the encrypted account the pane shows no private-account notice', (tester) async {
    await _pumpWithActive(tester, const RegularAccount(encryptedAccount));

    expect(_inPane(find.byType(PrivateActivityNotice)), findsNothing);
    expect(_inPane(find.text('Hides the link between your account and the recipient')), findsNothing);
  });

  testOnMac('on a transparent account the pane shows no private-account notice', (tester) async {
    await _pumpWithActive(tester, const RegularAccount(mainAccount));

    expect(_inPane(find.byType(PrivateActivityNotice)), findsNothing);
    expect(_inPane(find.byType(EncryptedLockBadge)), findsNothing);
  });

  testOnMac('with no active account the pane says so and has no toolbar', (tester) async {
    await pumpShell(
      tester,
      overrides: shellOverrides(accounts: const [mainAccount], balances: oneTokenEach),
    );

    expect(_inPane(find.text('No active account')), findsOneWidget);
    expect(find.byType(AccountToolbar), findsNothing);
  });

  group('the lists keep their least width: the sidebar gives way first, then the panel at the right', () {
    final now = DateTime.now();
    const smallest = Size(960, 640);
    late FakeSettingsService settings;

    /// The window at [window], with the sidebar and the panel at the right
    /// both made their widest.
    Future<void> open(
      WidgetTester tester, {
      required Size window,
      DisplayAccount active = const RegularAccount(mainAccount),
      List<MultisigAccount> multisigs = const [],
      required FakeSendChain chain,
    }) async {
      settings = FakeSettingsService(activeAccount: active, multisigs: multisigs)
        ..strings[SidebarWidthNotifier.settingsKey] = '${SidebarWidthNotifier.maximum}'
        ..strings[InspectorWidthNotifier.settingsKey] = '${InspectorWidthNotifier.maximum}';
      await pumpShell(
        tester,
        overrides: shellOverrides(
          accounts: const [mainAccount, savingsAccount],
          settings: settings,
          balances: oneTokenEach,
          chain: chain,
        ),
      );
      tester.view.physicalSize = window;
      await tester.pumpAndSettle();
    }

    FakeSendChain history() => FakeSendChain()
      ..scheduledTransfers = [
        ReversibleTransferEvent(
          id: 'scheduled',
          from: 'qzMain',
          to: 'qzBob4hGy7UwE2nXk9VcMp3QsLd6TfRa8ZoJi1Wb5eNt9cPu',
          amount: oneToken,
          timestamp: now,
          txId: '0xtxid',
          status: ReversibleTransferStatus.SCHEDULED,
          scheduledAt: now.add(const Duration(hours: 5)),
          blockNumber: 1,
          blockHash: '0xblock',
        ),
      ]
      ..historyPages = [
        [
          TransferEvent(
            id: 'sent',
            from: 'qzMain',
            to: 'qzBob4hGy7UwE2nXk9VcMp3QsLd6TfRa8ZoJi1Wb5eNt9cPu',
            amount: oneToken * BigInt.from(1250),
            timestamp: now.subtract(const Duration(hours: 2)),
            fee: FakeSendChain.usualFee,
            extrinsicHash: '0xsent',
            blockNumber: 1,
            blockHash: '0xblock',
          ),
        ],
      ];

    Future<void> openSent(WidgetTester tester) async {
      await tester.tap(find.byWidgetPredicate((w) => w is ActivityRowView && w.id == 'sent'));
      await tester.pumpAndSettle();
    }

    double widthOf(WidgetTester tester, Type panel) => tester.getSize(find.byType(panel)).width;

    testOnMac('in the smallest window, the sidebar narrows to its least, the panel at the right gives the rest', (
      tester,
    ) async {
      await open(tester, window: smallest, chain: history());

      await openSent(tester);

      expect(tester.takeException(), isNull, reason: 'nothing overflows');
      expect(widthOf(tester, Sidebar), SidebarWidthNotifier.minimum);
      // 960, less the window's gaps and the two handles (8 each), the
      // sidebar's 200 and the lists' least.
      expect(widthOf(tester, ActivityInspector), 960 - 4 * 8 - 200 - listsLeast);
      expect(widthOf(tester, ActivityPanel), listsLeast);
    });

    testOnMac('what was made stays: the saved widths are unchanged, and a closed panel gives the sidebar back', (
      tester,
    ) async {
      await open(tester, window: smallest, chain: history());
      await openSent(tester);

      expect(settings.strings[SidebarWidthNotifier.settingsKey], '${SidebarWidthNotifier.maximum}');
      expect(settings.strings[InspectorWidthNotifier.settingsKey], '${InspectorWidthNotifier.maximum}');

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(ActivityInspector), findsNothing);
      expect(widthOf(tester, Sidebar), SidebarWidthNotifier.maximum);
    });

    testOnMac('a sheet hangs centred on the panels beside the sidebar as it is shown', (tester) async {
      await open(tester, window: smallest, chain: history());
      await openSent(tester);

      await tester.tap(
        find.descendant(of: find.byType(AccountToolbar), matching: find.widgetWithText(ToolbarAction, 'Receive')),
      );
      await tester.pumpAndSettle();

      final left = tester.getRect(find.byType(Sidebar)).right + 8;
      expect(tester.getRect(find.byType(ShellSheetView)).center.dx, moreOrLessEquals((left + 960 - 8) / 2));
    });

    testOnMac('with room, both keep the widths they were made', (tester) async {
      await open(tester, window: const Size(1600, 900), chain: history());

      await openSent(tester);

      expect(widthOf(tester, Sidebar), SidebarWidthNotifier.maximum);
      expect(widthOf(tester, ActivityInspector), InspectorWidthNotifier.maximum);
    });
  });

  group('the backup reminder', () {
    testOnMac('shows under the balance while the active wallet\'s phrase has not been seen', (tester) async {
      await _pumpWithActive(tester, const RegularAccount(mainAccount));

      final reminder = _inPane(find.byType(BackupReminder));
      expect(reminder, findsOneWidget);
      expect(_inPane(find.text('Back up your recovery phrase')), findsOneWidget);
      expect(tester.getRect(reminder).top, greaterThan(tester.getRect(find.byType(BalanceCard)).bottom));
    });

    testOnMac('is not there once the wallet\'s phrase has been seen', (tester) async {
      final device = FakeWalletDevice()..store([mainAccount]);
      device.storage.viewedPhrases.add(0);
      await pumpShell(tester, overrides: device.overrides);
      expect(find.byType(BalanceCard), findsOneWidget);

      expect(find.byType(BackupReminder), findsNothing);
      expect(find.text('Back up your recovery phrase'), findsNothing);
    });

    testOnMac('opens Settings on the wallet\'s recovery phrase caution', (tester) async {
      await _pumpWithActive(tester, const RegularAccount(mainAccount));

      await tester.tap(find.byKey(BackupReminder.backUpKey));
      await tester.pumpAndSettle();

      expect(_sheetTitled('Recovery Phrase'), findsOneWidget);
      expect(
        find.descendant(of: find.byType(ShellSheetView), matching: find.byKey(SettingsSheet.continueKey)),
        findsOneWidget,
      );
    });
  });
}
