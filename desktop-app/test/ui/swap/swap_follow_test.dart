import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/models/shell_sheet.dart';
import 'package:quantus_desktop_wallet/providers/activity_providers.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/services/external_links.dart';
import 'package:quantus_desktop_wallet/ui/activity/activity_inspector.dart';
import 'package:quantus_desktop_wallet/ui/activity/activity_panel.dart';
import 'package:quantus_desktop_wallet/ui/activity/activity_row_view.dart';
import 'package:quantus_desktop_wallet/ui/activity/in_progress_panel.dart';
import 'package:quantus_desktop_wallet/ui/components/copy_action.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_account_badge.dart';
import 'package:quantus_desktop_wallet/ui/components/terminal_line.dart';
import 'package:quantus_desktop_wallet/ui/components/toolbar_action.dart';
import 'package:quantus_desktop_wallet/ui/shell/account_toolbar.dart';
import 'package:quantus_desktop_wallet/ui/shell/desktop_shell.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_view.dart';
import 'package:quantus_desktop_wallet/ui/shell/sidebar.dart';
import 'package:quantus_desktop_wallet/ui/swap/swap_detail.dart';
import 'package:quantus_desktop_wallet/ui/swap/swap_row_view.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/active_swap_provider.dart';
import 'package:wallet_core/providers/swap_providers.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/utils/explorer_url.dart';

import '../../fakes.dart';

final _l10n = lookupAppLocalizations(const Locale('en'));

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(DesktopShell)));

Finder _inRow(Finder finder) => find.descendant(of: find.byType(SwapRowView), matching: finder);
Finder _inPanel(Finder finder) => find.descendant(of: find.byType(SwapDetail), matching: finder);
Finder _text(String text) => find.text(text, findRichText: true);

/// The step named [step], as the panel lists it.
TerminalLine _line(WidgetTester tester, String step) =>
    tester.widget<TerminalLine>(_inPanel(find.byWidgetPredicate((w) => w is TerminalLine && w.name == step)));

/// Opens Main's wallet following [swap], on [active], Main unless said. What
/// would open outside the app is kept in [opened] instead.
Future<FakeSettingsService> _open(
  WidgetTester tester, {
  ActiveSwap? swap,
  DisplayAccount active = const RegularAccount(mainAccount),
  FakeSwapService? swaps,
  FakeSendChain? chain,
  List<Uri>? opened,
}) async {
  final settings = FakeSettingsService(activeAccount: active)..activeSwap = swap;
  await pumpShell(
    tester,
    overrides: [
      ...shellOverrides(
        accounts: const [mainAccount, savingsAccount, encryptedAccount],
        settings: settings,
        balances: oneTokenEach,
        encryptedBalances: {0: oneToken},
        chain: chain,
        swaps: swaps,
      ),
      if (opened != null) openExternalUrlProvider.overrideWithValue((url) async => opened.add(url)),
    ],
  );
  return settings;
}

/// Presses [finder] in the panel, scrolled to first: the panel is a list.
Future<void> _press(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _openSwap(WidgetTester tester) async {
  await tester.tap(find.byType(SwapRowView));
  await tester.pumpAndSettle();
}

TransferEvent _received(String id) => TransferEvent(
  id: id,
  from: 'qzBob',
  to: 'qzMain',
  amount: oneToken * BigInt.from(5),
  timestamp: DateTime.now().subtract(const Duration(hours: 2)),
  fee: FakeSendChain.usualFee,
  extrinsicHash: '0x$id',
  blockNumber: 1,
  blockHash: '0xblock',
);

void main() {
  group('the row in In progress', () {
    testOnMac('a running swap is the first row of its account: what is paid, what for, and the step it is on', (
      tester,
    ) async {
      final sending = FakeSendChain()
        ..scheduledTransfers = [
          ReversibleTransferEvent(
            id: 'scheduled',
            from: 'qzMain',
            to: 'qzBob',
            amount: oneToken,
            timestamp: DateTime.now(),
            txId: '0xtxid',
            status: ReversibleTransferStatus.SCHEDULED,
            scheduledAt: DateTime.now().add(const Duration(hours: 23)),
            blockNumber: 1,
            blockHash: '0xblock',
          ),
        ];
      await _open(tester, swap: fakeActiveSwap(), chain: sending);

      expect(find.descendant(of: find.byType(InProgressPanel), matching: find.byType(SwapRowView)), findsOne);
      expect(
        tester.getTopLeft(find.byType(SwapRowView)).dy,
        lessThan(tester.getTopLeft(find.byType(ActivityRowView).first).dy),
      );
      expect(_inRow(find.text(_l10n.swapStepSwapping)), findsOne);
      expect(_inRow(find.textContaining(RegExp(r'^3:\d\d$'))), findsOne);
      expect(_inRow(find.text('-250 QTC')), findsOne);
      expect(_inRow(find.text(_l10n.desktopSwapAmountOnNetwork('104.37 USDC', 'Arbitrum'))), findsOne);
      expect(_inRow(find.text(_l10n.swapStepConfirming('Quantus'))), findsOne);
    });

    testOnMac('a swap alone is enough for In progress to be there', (tester) async {
      await _open(tester, swap: fakeActiveSwap());

      expect(find.byType(InProgressPanel), findsOne);
      expect(find.byType(SwapRowView), findsOne);
    });

    testOnMac('a swap awaiting its deposit says so, until when, and what will arrive', (tester) async {
      final deadline = clock.now().add(const Duration(minutes: 20));
      await _open(
        tester,
        swap: fakeActiveSwap(swapOut: false, status: SwapStatus.pendingDeposit, deadline: deadline),
      );

      final until = TimeOfDay.fromDateTime(deadline.toLocal()).format(tester.element(find.byType(SwapRowView)));
      expect(_inRow(find.text(_l10n.desktopSwapAwaitingDeposit)), findsOne);
      expect(_inRow(find.text(_l10n.desktopSwapUntil(until))), findsOne);
      expect(_inRow(find.text('+236.9 QTC')), findsOne);
      expect(_inRow(find.text(_l10n.desktopSwapAmountOnNetwork('100 USDC', 'Arbitrum'))), findsOne);
      expect(_inRow(find.text(_l10n.desktopSwapWaitingForDeposit)), findsOne);
    });

    testOnMac('a completed swap stays as Swapped; one that paid nothing out says how it ended', (tester) async {
      await _open(
        tester,
        swap: fakeActiveSwap(status: SwapStatus.success, age: const Duration(minutes: 4, seconds: 12)),
      );
      expect(_inRow(find.text(_l10n.swapLiveSwapped)), findsOne);
      expect(_inRow(find.text('4:12')), findsOne);

      final ended = <(ActiveSwap, String)>[
        (fakeActiveSwap(status: SwapStatus.failed), _l10n.swapFailedTitle),
        (fakeActiveSwap(status: SwapStatus.refunded), _l10n.swapRefundedLabel),
        (fakeActiveSwap(swapOut: false, status: SwapStatus.incompleteDeposit), _l10n.swapDepositIncompleteTitle),
        (
          fakeActiveSwap(
            swapOut: false,
            status: SwapStatus.pendingDeposit,
            deadline: clock.now().subtract(const Duration(minutes: 1)),
          ),
          _l10n.swapDepositExpiredTitle,
        ),
      ];
      for (final (swap, label) in ended) {
        await tester.pumpWidget(const SizedBox.shrink());
        await _open(tester, swap: swap);
        expect(_inRow(find.text(label)), findsOne, reason: label);
      }
    });

    testOnMac('the row is in the account the swap is from, and in no other; with no swap there is none', (
      tester,
    ) async {
      await _open(tester, swap: fakeActiveSwap(), active: const RegularAccount(savingsAccount));
      expect(find.byType(SwapRowView), findsNothing);
      expect(find.byType(InProgressPanel), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await _open(tester);
      expect(find.byType(SwapRowView), findsNothing);
      expect(find.byType(InProgressPanel), findsNothing);
    });

    testOnMac('a click opens the swap at the right and marks its row; ↑ and ↓ walk it with the other rows', (
      tester,
    ) async {
      final chain = FakeSendChain()
        ..historyPages = [
          [_received('settled')],
        ];
      await _open(tester, swap: fakeActiveSwap(), chain: chain);
      expect(find.byType(SwapDetail), findsNothing);

      await _openSwap(tester);
      expect(find.byType(SwapDetail), findsOne);
      expect(tester.widget<SwapRowView>(find.byType(SwapRowView)).isSelected, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(find.byType(SwapDetail), findsNothing);
      expect(_container(tester).read(openedActivityViewProvider), isA<OpenedTransaction>());

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(find.byType(SwapDetail), findsOne);
      expect(_container(tester).read(openedActivityViewProvider), const OpenedSwap());
    });

    testOnMac('the sidebar counts the swap on its account while it is under way', (tester) async {
      await _open(tester, swap: fakeActiveSwap());

      final count = find.descendant(of: find.byType(Sidebar), matching: find.byKey(DesktopAccountBadge.countKey));
      expect(count, findsOne);
      expect(find.descendant(of: count, matching: find.text('1')), findsOne);
    });
  });

  group('the Swap panel', () {
    testOnMac('a swap out under way: its amount, what for, who is paid, its steps and its terms', (tester) async {
      final opened = <Uri>[];
      await _open(tester, swap: fakeActiveSwap(), opened: opened);
      await _openSwap(tester);

      expect(find.descendant(of: find.byType(ActivityInspector), matching: find.text(_l10n.swapTitle)), findsOne);
      expect(_inPanel(find.text(_l10n.activityDetailStatusInProcess.toUpperCase())), findsOne);
      expect(_inPanel(find.text('250 QTC')), findsOne);
      expect(_inPanel(find.text(_l10n.desktopSwapForAmountOnNetwork('104.37 USDC', 'Arbitrum'))), findsOne);
      expect(_inPanel(find.text(_l10n.desktopSwapRecipientOn('Arbitrum').toUpperCase())), findsOne);
      expect(_inPanel(find.text(swapRecipient)), findsOne, reason: 'the address whole');

      // Sent by the app, so that is done; the chain is confirming it.
      expect(_line(tester, _l10n.swapStepSent('QTC')).status, '[OK]');
      final confirming = _line(tester, _l10n.swapStepConfirming('Quantus'));
      expect(confirming.isBusy, isTrue);
      expect(confirming.isDim, isFalse);
      expect(_line(tester, _l10n.swapStepSwapping).isDim, isTrue);
      expect(_line(tester, _l10n.swapStepSending('USDC', _l10n.desktopSwapTheRecipient)).isDim, isTrue);

      final rate = _container(
        tester,
      ).read(numberFormattingServiceProvider).formatAmount(swapQuoteRate(fakeSwapQuote()), decimals: 6);
      expect(_inPanel(find.text(_l10n.swapRateLabel('QTC', rate, 'USDC'))), findsOne);
      expect(_inPanel(find.text('103.33 USDC')), findsOne);
      expect(_inPanel(find.text('0.0012 QTC')), findsOne);
      expect(_inPanel(find.text('250.0012 QTC')), findsOne);
      expect(_inPanel(find.text(_l10n.desktopSwapPoweredByNearIntents)), findsOne);

      await _press(tester, _inPanel(find.text(_l10n.desktopSwapViewDeposit)));
      expect(opened, [Uri.parse(explorerUrl('transactions/$swapDepositTx'))]);
    });

    testOnMac('a swap in under way: the deposit was made by hand, and the account is who receives', (tester) async {
      await _open(tester, swap: fakeActiveSwap(swapOut: false, status: SwapStatus.processing, depositSent: true));
      await _openSwap(tester);

      expect(_inPanel(find.text('100 USDC')), findsOne);
      expect(_inPanel(find.text(_l10n.desktopSwapForAmountOnNetwork('236.9 QTC', 'Quantus'))), findsOne);
      expect(_line(tester, _l10n.swapStepDeposited('USDC')).status, '[OK]');
      expect(_line(tester, _l10n.swapStepConfirming('Arbitrum')).status, '[OK]');
      expect(_line(tester, _l10n.swapStepSwapping).isBusy, isTrue);
      expect(_line(tester, _l10n.swapStepSending('QTC', 'Main')).isDim, isTrue);
      // Where a refund would go, whole.
      expect(_inPanel(find.text(swapRecipient)), findsOne);
      expect(_inPanel(find.text(_l10n.desktopSwapViewDeposit)), findsNothing, reason: 'the app sent no deposit');
    });

    testOnMac('a status that cannot be checked says so, and Retry asks again', (tester) async {
      final swaps = FakeSwapService();
      await _open(
        tester,
        swap: fakeActiveSwap(pollError: 'offline'),
        swaps: swaps,
      );
      await _openSwap(tester);

      expect(_inPanel(_text(_l10n.swapProgressStatusUnavailable('offline'))), findsOne);
      final before = swaps.polls;
      await _press(tester, _inPanel(find.text(_l10n.commonRetry)));

      expect(swaps.polls, before + 1);
      expect(_inPanel(_text(_l10n.swapProgressStatusUnavailable('offline'))), findsNothing);
    });

    testOnMac('a swap that has not finished in time says so, and where a refund goes', (tester) async {
      await _open(
        tester,
        swap: fakeActiveSwap(
          status: SwapStatus.processing,
          age: const Duration(minutes: 41),
          deadline: clock.now().subtract(ActiveSwap.finishGrace + const Duration(minutes: 1)),
        ),
      );
      await _openSwap(tester);

      expect(_inPanel(_text(_l10n.swapProgressOverdue('Main'))), findsOne);
    });

    testOnMac('Stop tracking asks first: cancelled, the swap stays; confirmed, it is put away', (tester) async {
      final settings = await _open(tester, swap: fakeActiveSwap());
      await _openSwap(tester);

      await _press(tester, _inPanel(find.widgetWithText(ToolbarAction, _l10n.swapStopTracking)));
      expect(_inPanel(find.text(_l10n.swapStopTrackingConfirmTitle)), findsOne);
      expect(_inPanel(_text(_l10n.swapStopTrackingConfirmBody)), findsOne);
      expect(settings.activeSwap, isNotNull);

      await _press(tester, _inPanel(find.text(_l10n.commonCancel)));
      expect(_inPanel(find.text(_l10n.swapStopTrackingConfirmTitle)), findsNothing);
      expect(settings.activeSwap, isNotNull);

      await _press(tester, _inPanel(find.widgetWithText(ToolbarAction, _l10n.swapStopTracking)));
      await _press(tester, _inPanel(find.byKey(SwapDetail.confirmStopKey)));

      expect(settings.activeSwap, isNull);
      expect(_container(tester).read(activeSwapProvider), isNull);
      expect(find.byType(SwapDetail), findsNothing);
      expect(find.byType(SwapRowView), findsNothing);
    });

    testOnMac('a deposit awaited: the exact amount, the code and the whole address to copy, and by when', (
      tester,
    ) async {
      final deadline = clock.now().add(const Duration(minutes: 20));
      await _open(
        tester,
        swap: fakeActiveSwap(swapOut: false, status: SwapStatus.pendingDeposit, deadline: deadline),
      );
      await _openSwap(tester);
      final until = TimeOfDay.fromDateTime(deadline.toLocal()).format(tester.element(find.byType(SwapDetail)));

      expect(_inPanel(find.text(_l10n.desktopSwapAwaitingDeposit.toUpperCase())), findsOne);
      expect(_inPanel(find.text(_l10n.desktopSwapSendAmount('100 USDC'))), findsOne);
      expect(_inPanel(_text(_l10n.swapDepositOnly('USDC', 'Arbitrum'))), findsOne);
      expect(tester.widget<QuantusQr>(_inPanel(find.byType(QuantusQr))).accountId, swapDepositAddress);
      expect(_inPanel(find.text(swapDepositAddress)), findsOne);
      expect(tester.widget<CopyAction>(_inPanel(find.byType(CopyAction))).text, swapDepositAddress);
      expect(_inPanel(_text(_l10n.swapDepositDeadline(until))), findsOne);
      expect(_inPanel(find.text(_l10n.swapDepositMemo.toUpperCase())), findsNothing);
    });

    testOnMac('a chain that needs a memo shows it to copy, with its warning', (tester) async {
      await _open(
        tester,
        swap: fakeActiveSwap(swapOut: false, status: SwapStatus.pendingDeposit, depositMemo: '7741902'),
      );
      await _openSwap(tester);

      expect(_inPanel(find.text(_l10n.swapDepositMemo.toUpperCase())), findsOne);
      expect(_inPanel(find.text('7741902')), findsOne);
      expect(_inPanel(_text(_l10n.swapDepositMemoNotice)), findsOne);
      expect(tester.widgetList<CopyAction>(_inPanel(find.byType(CopyAction))).map((copy) => copy.text), [
        swapDepositAddress,
        '7741902',
      ]);
    });

    testOnMac("I've Sent It moves the swap on to its steps; Cancel Swap puts it away", (tester) async {
      final settings = await _open(tester, swap: fakeActiveSwap(swapOut: false, status: SwapStatus.pendingDeposit));
      await _openSwap(tester);

      await _press(tester, _inPanel(find.text(_l10n.swapDepositSent)));
      expect(settings.activeSwap!.depositSent, isTrue);
      expect(_inPanel(find.text(_l10n.activityDetailStatusInProcess.toUpperCase())), findsOne);
      expect(_inRow(find.text(_l10n.swapStepSwapping)), findsOne);

      await tester.pumpWidget(const SizedBox.shrink());
      final again = await _open(tester, swap: fakeActiveSwap(swapOut: false, status: SwapStatus.pendingDeposit));
      await _openSwap(tester);
      await _press(tester, _inPanel(find.text(_l10n.desktopSwapCancel)));

      expect(again.activeSwap, isNull);
      expect(find.byType(SwapDetail), findsNothing);
      expect(find.byType(SwapRowView), findsNothing);
    });

    testOnMac('a completed swap says what arrived, the amount 1Click reports when it gives one; Done puts it away', (
      tester,
    ) async {
      final settings = await _open(
        tester,
        swap: fakeActiveSwap(
          status: SwapStatus.success,
          amountOut: BigInt.from(104410000),
          age: const Duration(minutes: 4, seconds: 12),
        ),
      );
      await _openSwap(tester);

      expect(_inPanel(find.text(_l10n.activityDetailStatusCompleted.toUpperCase())), findsOne);
      expect(_inPanel(find.text(_l10n.desktopSwapReceived('104.41 USDC'))), findsOne);
      expect(_inPanel(find.text(_l10n.desktopSwapCompleteBody('250 QTC'))), findsOne);
      expect(_inPanel(find.text(swapRecipient)), findsOne);
      expect(_inPanel(find.byType(TerminalLine)), findsNothing);

      await _press(tester, _inPanel(find.text(_l10n.commonDone)));
      expect(settings.activeSwap, isNull);
      expect(find.byType(SwapDetail), findsNothing);
      expect(find.byType(SwapRowView), findsNothing);
    });

    testOnMac('a swap that paid nothing out says how it ended, with addresses whole', (tester) async {
      final ended = <(ActiveSwap, String, String)>[
        (
          fakeActiveSwap(status: SwapStatus.failed),
          _l10n.swapFailedTitle,
          _l10n.swapDepositFailedBody(swapDepositAddress),
        ),
        (
          fakeActiveSwap(status: SwapStatus.refunded, refundReason: 'PARTIAL_DEPOSIT'),
          _l10n.swapRefundedLabel,
          '${_l10n.swapRefundedBody('250 QTC', 'Main', 'USDC')}\n\n${_l10n.swapDepositRefundReason('PARTIAL_DEPOSIT')}',
        ),
        (
          fakeActiveSwap(swapOut: false, status: SwapStatus.refunded),
          _l10n.swapRefundedLabel,
          _l10n.swapRefundedBody('100 USDC', swapRecipient, 'QTC'),
        ),
        (
          fakeActiveSwap(swapOut: false, status: SwapStatus.incompleteDeposit),
          _l10n.swapDepositIncompleteTitle,
          _l10n.swapDepositIncompleteBody,
        ),
        (
          fakeActiveSwap(
            swapOut: false,
            status: SwapStatus.pendingDeposit,
            deadline: clock.now().subtract(const Duration(minutes: 1)),
          ),
          _l10n.swapDepositExpiredTitle,
          _l10n.swapDepositExpiredBody,
        ),
      ];
      for (final (swap, status, message) in ended) {
        await tester.pumpWidget(const SizedBox.shrink());
        await _open(tester, swap: swap);
        await _openSwap(tester);

        expect(_inPanel(find.text(status.toUpperCase())), findsOne, reason: status);
        expect(_inPanel(_text(message)), findsOne, reason: status);
        expect(_inPanel(find.byType(TerminalLine)), findsNothing, reason: status);
      }
    });

    testOnMac('a swap that ended badly is put away by Done, and Contact Support writes to support', (tester) async {
      final opened = <Uri>[];
      final settings = await _open(
        tester,
        swap: fakeActiveSwap(status: SwapStatus.failed),
        opened: opened,
      );
      await _openSwap(tester);

      await _press(tester, _inPanel(find.text(_l10n.commonContactSupport)));
      expect(opened, [Uri.parse('mailto:${AppConstants.emailSupport}')]);
      expect(settings.activeSwap, isNotNull);

      await _press(tester, _inPanel(find.text(_l10n.commonDone)));
      expect(settings.activeSwap, isNull);
      expect(find.byType(SwapDetail), findsNothing);
    });

    testOnMac('✕ and Esc close the panel and leave the swap followed, its row in place', (tester) async {
      final settings = await _open(tester, swap: fakeActiveSwap(swapOut: false, status: SwapStatus.pendingDeposit));

      await _openSwap(tester);
      await tester.tap(find.byKey(ActivityInspector.closeKey));
      await tester.pumpAndSettle();
      expect(find.byType(SwapDetail), findsNothing);
      expect(find.byType(SwapRowView), findsOne);
      expect(settings.activeSwap, isNotNull);

      await _openSwap(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(SwapDetail), findsNothing);
      expect(find.byType(SwapRowView), findsOne);
      expect(settings.activeSwap, isNotNull);
    });
  });

  group('Swap in the toolbar, with a swap followed', () {
    Finder swapAction() =>
        find.descendant(of: find.byType(AccountToolbar), matching: find.widgetWithText(ToolbarAction, _l10n.homeSwap));

    testOnMac("opens the swap's panel, and no sheet", (tester) async {
      await _open(tester, swap: fakeActiveSwap());

      await tester.tap(swapAction());
      await tester.pumpAndSettle();

      expect(find.byType(SwapDetail), findsOne);
      expect(find.byType(ShellSheetView), findsNothing);
      expect(_container(tester).read(shellSheetProvider), isNull);
      expect(tester.widget<SwapRowView>(find.byType(SwapRowView)).isSelected, isTrue);
    });

    testOnMac('from another account too, where the swap has no row', (tester) async {
      await _open(tester, swap: fakeActiveSwap(), active: const RegularAccount(savingsAccount));
      expect(find.byType(SwapRowView), findsNothing);

      await tester.tap(swapAction());
      await tester.pumpAndSettle();

      expect(find.byType(SwapDetail), findsOne);
      expect(_container(tester).read(shellSheetProvider), isNot(ShellSheet.swap));
      expect(_inPanel(find.text('250 QTC')), findsOne);
    });
  });

  group('in the smallest window, with the panels made their widest', () {
    final swaps = <(String, ActiveSwap Function())>[
      ('under way', () => fakeActiveSwap(pollError: 'offline')),
      (
        'awaiting its deposit',
        () => fakeActiveSwap(swapOut: false, status: SwapStatus.pendingDeposit, depositMemo: '7741902'),
      ),
      ('complete', () => fakeActiveSwap(status: SwapStatus.success)),
      ('refunded', () => fakeActiveSwap(swapOut: false, status: SwapStatus.refunded, refundReason: 'PARTIAL_DEPOSIT')),
    ];
    for (final (state, swap) in swaps) {
      testOnMac('a swap $state fits: its row, and its panel', (tester) async {
        final settings = FakeSettingsService(activeAccount: const RegularAccount(mainAccount))
          ..activeSwap = swap()
          ..strings[SidebarWidthNotifier.settingsKey] = '${SidebarWidthNotifier.maximum}'
          ..strings[InspectorWidthNotifier.settingsKey] = '${InspectorWidthNotifier.maximum}';
        await pumpShell(
          tester,
          overrides: shellOverrides(
            accounts: const [mainAccount, savingsAccount],
            settings: settings,
            balances: oneTokenEach,
          ),
        );
        tester.view.physicalSize = const Size(960, 640);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'the row alone');

        await _openSwap(tester);
        expect(tester.takeException(), isNull, reason: 'with its panel open');
        expect(find.byType(SwapDetail), findsOne);
        expect(find.byType(ActivityPanel), findsOne);
      });
    }
  });
}
