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
import 'package:quantus_desktop_wallet/ui/components/sidebar_row.dart';
import 'package:quantus_desktop_wallet/ui/components/terminal_line.dart';
import 'package:quantus_desktop_wallet/ui/components/toolbar_action.dart';
import 'package:quantus_desktop_wallet/ui/shell/account_toolbar.dart';
import 'package:quantus_desktop_wallet/ui/shell/desktop_shell.dart';
import 'package:quantus_desktop_wallet/ui/shell/sidebar.dart';
import 'package:quantus_desktop_wallet/ui/swap/swap_detail.dart';
import 'package:quantus_desktop_wallet/ui/swap/swap_row_view.dart';
import 'package:quantus_desktop_wallet/ui/swap/swap_sheet.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/active_swaps_provider.dart';
import 'package:wallet_core/providers/swap_providers.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/utils/explorer_url.dart';

import '../../fakes.dart';

final _l10n = lookupAppLocalizations(const Locale('en'));

/// The official support server, spelled out so a changed link fails here.
const _discord = 'https://discord.gg/Ba9nTGUdgF';

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(DesktopShell)));

Finder _inRow(Finder finder) => find.descendant(of: find.byType(SwapRowView), matching: finder);
Finder _inPanel(Finder finder) => find.descendant(of: find.byType(SwapDetail), matching: finder);
Finder _text(String text) => find.text(text, findRichText: true);

/// The step named [step], as the panel lists it.
TerminalLine _line(WidgetTester tester, String step) =>
    tester.widget<TerminalLine>(_inPanel(find.byWidgetPredicate((w) => w is TerminalLine && w.name == step)));

/// Opens Main's wallet following [swap], or [followed] in the order they
/// started, on [active], Main unless said. What would open outside the app
/// is kept in [opened] instead.
Future<FakeSettingsService> _open(
  WidgetTester tester, {
  ActiveSwap? swap,
  List<ActiveSwap> followed = const [],
  DisplayAccount active = const RegularAccount(mainAccount),
  FakeSwapService? swaps,
  FakeSendChain? chain,
  List<Uri>? opened,
  bool swapAvailable = true,
}) async {
  final settings = FakeSettingsService(activeAccount: active)..activeSwaps = [?swap, ...followed];
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
        swapAvailable: swapAvailable,
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

/// Deposit addresses for swaps followed beside the usual one.
const _secondAddress = '0x1111111111111111111111111111111111111111';
const _thirdAddress = '0x2222222222222222222222222222222222222222';

/// The row of [swap], among the rows of several.
Finder _rowOf(ActiveSwap swap) => find.byWidgetPredicate((w) => w is SwapRowView && w.swap.id == swap.id);

Future<void> _openRow(WidgetTester tester, ActiveSwap swap) async {
  await tester.tap(_rowOf(swap));
  await tester.pumpAndSettle();
}

/// The ids of the swaps listed, from the top.
List<String> _rowIds(WidgetTester tester) => [
  for (final row in tester.widgetList<SwapRowView>(find.byType(SwapRowView))) row.swap.id,
];

/// The swap the panel at the right shows.
String _panelSwapId(WidgetTester tester) => tester.widget<SwapDetail>(find.byType(SwapDetail)).swapId;

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
      expect(_container(tester).read(openedActivityViewProvider), const OpenedSwap(swapDepositAddress));
    });

    testOnMac('the sidebar counts the swap on its account while it is under way', (tester) async {
      await _open(tester, swap: fakeActiveSwap());

      final count = find.descendant(of: find.byType(Sidebar), matching: find.byKey(DesktopAccountBadge.countKey));
      expect(count, findsOne);
      expect(find.descendant(of: count, matching: find.text('1')), findsOne);
    });
  });

  group('the Swap panel', () {
    testOnMac('a swap awaiting its deposit is still followed after a restart, its address with it', (tester) async {
      final settings = await _open(tester, swap: fakeActiveSwap(swapOut: false, status: SwapStatus.pendingDeposit));
      await tester.pump();

      expect(find.byType(SwapRowView), findsOneWidget);
      expect(settings.activeSwap, isNotNull, reason: 'it is not dropped from the device at launch');

      await _openSwap(tester);
      expect(_inPanel(find.byType(CopyAction)), findsWidgets);
      expect(_inPanel(find.text(_l10n.swapDepositSent)), findsOne);
    });

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
      expect(_container(tester).read(activeSwapsProvider), isEmpty);
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

    testOnMac('a swap that ended badly is put away by Done, and Contact Support opens Discord', (tester) async {
      final opened = <Uri>[];
      final settings = await _open(
        tester,
        swap: fakeActiveSwap(status: SwapStatus.failed),
        opened: opened,
      );
      await _openSwap(tester);

      await _press(tester, _inPanel(find.text(_l10n.commonContactSupport)));
      expect(opened, [Uri.parse(_discord)]);
      expect(settings.activeSwap, isNotNull);

      await _press(tester, _inPanel(find.text(_l10n.commonDone)));
      expect(settings.activeSwap, isNull);
      expect(find.byType(SwapDetail), findsNothing);
    });

    testOnMac('every way a swap ends badly sends support to Discord, with the warning against impostors', (
      tester,
    ) async {
      final ended = [
        fakeActiveSwap(status: SwapStatus.failed),
        fakeActiveSwap(swapOut: false, status: SwapStatus.refunded),
        fakeActiveSwap(swapOut: false, status: SwapStatus.incompleteDeposit),
        fakeActiveSwap(
          swapOut: false,
          status: SwapStatus.pendingDeposit,
          deadline: clock.now().subtract(const Duration(minutes: 1)),
        ),
      ];
      for (final swap in ended) {
        final reason = swap.order.status.wire;
        final opened = <Uri>[];
        await tester.pumpWidget(const SizedBox.shrink());
        await _open(tester, swap: swap, opened: opened);
        await _openSwap(tester);

        expect(_inPanel(find.text(_l10n.commonSupportScamWarning)), findsOne, reason: reason);
        await _press(tester, _inPanel(find.text(_l10n.commonContactSupport)));
        expect(opened, [Uri.parse(_discord)], reason: reason);
      }
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

  group('several swaps at once', () {
    testOnMac('each swap of the account has its row, the newest first, over what else is in progress', (tester) async {
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
      final first = fakeActiveSwap();
      final second = fakeActiveSwap(swapOut: false, depositSent: true, depositAddress: _secondAddress);
      await _open(tester, followed: [first, second], chain: sending);

      expect(find.descendant(of: find.byType(InProgressPanel), matching: find.byType(SwapRowView)), findsNWidgets(2));
      expect(_rowIds(tester), [second.id, first.id]);
      expect(tester.getTopLeft(_rowOf(first)).dy, lessThan(tester.getTopLeft(find.byType(ActivityRowView).first).dy));
      expect(find.descendant(of: _rowOf(first), matching: find.text('-250 QTC')), findsOne);
      expect(find.descendant(of: _rowOf(second), matching: find.text('+236.9 QTC')), findsOne);
    });

    testOnMac('an account lists its own swaps, and not those of another', (tester) async {
      final ofMain = fakeActiveSwap();
      final ofSavings = fakeActiveSwap(account: savingsAccount, depositAddress: _secondAddress);

      await _open(tester, followed: [ofMain, ofSavings]);
      expect(_rowIds(tester), [ofMain.id]);

      await tester.pumpWidget(const SizedBox.shrink());
      await _open(tester, followed: [ofMain, ofSavings], active: const RegularAccount(savingsAccount));
      expect(_rowIds(tester), [ofSavings.id]);
    });

    testOnMac('a swap whose account the wallet no longer holds is listed under the open account, and opens', (
      tester,
    ) async {
      // As after Trading was disconnected with its swap still followed.
      final orphaned = fakeActiveSwap(swapOut: false, status: SwapStatus.pendingDeposit, account: tradingAccount);
      final settings = await _open(tester, followed: [orphaned]);
      expect(_rowIds(tester), [orphaned.id]);

      await _openRow(tester, orphaned);
      expect(_panelSwapId(tester), orphaned.id);
      expect(_inPanel(find.text(swapDepositAddress)), findsOne, reason: 'where to send the deposit is still had');
      expect(_inPanel(find.text('Trading')), findsOne, reason: 'the account by the name it had');

      await _press(tester, _inPanel(find.text(_l10n.desktopSwapCancel)));
      expect(settings.activeSwaps, isEmpty, reason: 'its slot is given back');
      expect(find.byType(SwapRowView), findsNothing);
    });

    testOnMac("a swap whose account the wallet no longer holds counts on the open account's badge in the sidebar, "
        'beside its own', (tester) async {
      final own = fakeActiveSwap();
      final orphaned = fakeActiveSwap(account: tradingAccount, depositAddress: _secondAddress);
      await _open(tester, followed: [own, orphaned]);
      expect(_rowIds(tester), [orphaned.id, own.id]);

      Finder countOf(String account) => find.descendant(
        of: find.descendant(of: find.byType(Sidebar), matching: find.widgetWithText(SidebarRow, account)),
        matching: find.byKey(DesktopAccountBadge.countKey),
      );
      expect(find.descendant(of: countOf('Main'), matching: find.text('2')), findsOne);
      expect(find.descendant(of: countOf('Savings'), matching: find.text('1')), findsOne);
    });

    testOnMac('swaps kept from the last run are all listed, one still awaiting its deposit with them', (tester) async {
      final running = fakeActiveSwap();
      final awaited = fakeActiveSwap(swapOut: false, status: SwapStatus.pendingDeposit, depositAddress: _secondAddress);
      final settings = await _open(tester, followed: [running, awaited]);
      await tester.pump();

      expect(_rowIds(tester), [awaited.id, running.id]);
      expect(settings.activeSwaps.map((s) => s.id), [running.id, awaited.id], reason: 'none is dropped at launch');
    });

    testOnMac('a click opens that swap at the right, and marks its row alone', (tester) async {
      final first = fakeActiveSwap();
      final second = fakeActiveSwap(swapOut: false, depositSent: true, depositAddress: _secondAddress);
      await _open(tester, followed: [first, second]);

      await _openRow(tester, first);
      expect(_panelSwapId(tester), first.id);
      expect(_inPanel(find.text('250 QTC')), findsOne);
      expect(tester.widget<SwapRowView>(_rowOf(first)).isSelected, isTrue);
      expect(tester.widget<SwapRowView>(_rowOf(second)).isSelected, isFalse);

      await _openRow(tester, second);
      expect(_panelSwapId(tester), second.id);
      expect(_inPanel(find.text('100 USDC')), findsOne);
      expect(tester.widget<SwapRowView>(_rowOf(first)).isSelected, isFalse);
      expect(tester.widget<SwapRowView>(_rowOf(second)).isSelected, isTrue);
    });

    testOnMac('↑ and ↓ walk from swap to swap, then to the other rows', (tester) async {
      final chain = FakeSendChain()
        ..historyPages = [
          [_received('settled')],
        ];
      final first = fakeActiveSwap();
      final second = fakeActiveSwap(depositAddress: _secondAddress);
      await _open(tester, followed: [first, second], chain: chain);

      await _openRow(tester, second);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(_container(tester).read(openedActivityViewProvider), OpenedSwap(first.id));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(_container(tester).read(openedActivityViewProvider), isA<OpenedTransaction>());

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(_container(tester).read(openedActivityViewProvider), OpenedSwap(second.id));
    });

    testOnMac('Done puts away the swap it is pressed on, and leaves the other followed', (tester) async {
      final done = fakeActiveSwap(status: SwapStatus.success);
      final running = fakeActiveSwap(depositAddress: _secondAddress);
      final settings = await _open(tester, followed: [done, running]);

      await _openRow(tester, done);
      await _press(tester, _inPanel(find.text(_l10n.commonDone)));

      expect(settings.activeSwaps.map((s) => s.id), [running.id]);
      expect(_rowIds(tester), [running.id]);
      expect(find.byType(SwapDetail), findsNothing);
    });

    testOnMac('Stop tracking, confirmed, puts away its own swap alone', (tester) async {
      final first = fakeActiveSwap();
      final second = fakeActiveSwap(depositAddress: _secondAddress);
      final settings = await _open(tester, followed: [first, second]);

      await _openRow(tester, second);
      await _press(tester, _inPanel(find.widgetWithText(ToolbarAction, _l10n.swapStopTracking)));
      await _press(tester, _inPanel(find.byKey(SwapDetail.confirmStopKey)));

      expect(settings.activeSwaps.map((s) => s.id), [first.id]);
      expect(_rowIds(tester), [first.id]);
      expect(find.byType(SwapDetail), findsNothing);
    });

    testOnMac('Stop tracking asked of one swap is not asked of the next one opened', (tester) async {
      final first = fakeActiveSwap();
      final second = fakeActiveSwap(depositAddress: _secondAddress);
      final settings = await _open(tester, followed: [first, second]);

      await _openRow(tester, first);
      await _press(tester, _inPanel(find.widgetWithText(ToolbarAction, _l10n.swapStopTracking)));
      expect(_inPanel(find.byKey(SwapDetail.confirmStopKey)), findsOne);

      await _openRow(tester, second);
      expect(_panelSwapId(tester), second.id);
      expect(_inPanel(find.byKey(SwapDetail.confirmStopKey)), findsNothing);
      expect(_inPanel(find.widgetWithText(ToolbarAction, _l10n.swapStopTracking)), findsOne);
      expect(settings.activeSwaps, hasLength(2));
    });

    testOnMac("of two swaps awaiting a deposit, I've Sent It and Cancel Swap each act on their own", (tester) async {
      final first = fakeActiveSwap(swapOut: false, status: SwapStatus.pendingDeposit);
      final second = fakeActiveSwap(swapOut: false, status: SwapStatus.pendingDeposit, depositAddress: _secondAddress);
      final third = fakeActiveSwap(swapOut: false, status: SwapStatus.pendingDeposit, depositAddress: _thirdAddress);
      final settings = await _open(tester, followed: [first, second, third]);
      ActiveSwap kept(ActiveSwap swap) => settings.activeSwaps.singleWhere((s) => s.id == swap.id);

      await _openRow(tester, second);
      expect(_inPanel(find.text(_secondAddress)), findsOne);
      await _press(tester, _inPanel(find.text(_l10n.swapDepositSent)));

      expect(kept(second).depositSent, isTrue);
      expect(kept(first).depositSent, isFalse);
      expect(kept(third).depositSent, isFalse);

      await _openRow(tester, third);
      await _press(tester, _inPanel(find.text(_l10n.desktopSwapCancel)));

      expect(settings.activeSwaps.map((s) => s.id), [first.id, second.id]);
      expect(_rowIds(tester), [second.id, first.id]);
      expect(find.byType(SwapDetail), findsNothing);
    });

    testOnMac('the swap in the panel put away from elsewhere closes the panel; the rest stay', (tester) async {
      final first = fakeActiveSwap();
      final second = fakeActiveSwap(depositAddress: _secondAddress);
      await _open(tester, followed: [first, second]);
      await _openRow(tester, first);

      await _container(tester).read(activeSwapsProvider.notifier).remove(first.id);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(SwapDetail), findsNothing);
      expect(_rowIds(tester), [second.id]);
      expect(_container(tester).read(openedActivityProvider), isNull);
    });
  });

  group('Start a New Swap, on a swap that ended', () {
    testOnMac('puts the swap away and opens the Swap sheet', (tester) async {
      final settings = await _open(tester, swap: fakeActiveSwap(status: SwapStatus.failed));
      await _openSwap(tester);

      await _press(tester, _inPanel(find.byKey(SwapDetail.startNewKey)));

      expect(settings.activeSwap, isNull);
      expect(find.byType(SwapDetail), findsNothing);
      expect(find.byType(SwapRowView), findsNothing);
      expect(find.byType(SwapSheet), findsOneWidget);
    });

    testOnMac('is offered on each way a swap ends short, and not on one under way or complete', (tester) async {
      for (final (swap, isOffered) in [
        (fakeActiveSwap(status: SwapStatus.refunded), true),
        (fakeActiveSwap(swapOut: false, status: SwapStatus.incompleteDeposit, depositSent: true), true),
        (
          fakeActiveSwap(
            swapOut: false,
            status: SwapStatus.pendingDeposit,
            deadline: clock.now().subtract(const Duration(minutes: 1)),
          ),
          true,
        ),
        (fakeActiveSwap(status: SwapStatus.processing), false),
        (fakeActiveSwap(status: SwapStatus.success), false),
      ]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await _open(tester, swap: swap);
        await _openSwap(tester);

        expect(_inPanel(find.byKey(SwapDetail.startNewKey)), isOffered ? findsOne : findsNothing, reason: '$swap');
      }
    });

    testOnMac('leaves another swap followed, its row in place', (tester) async {
      final failed = fakeActiveSwap(status: SwapStatus.failed);
      final running = fakeActiveSwap(depositAddress: _secondAddress);
      final settings = await _open(tester, followed: [failed, running]);
      await _openRow(tester, failed);

      await _press(tester, _inPanel(find.byKey(SwapDetail.startNewKey)));

      expect(settings.activeSwaps.map((s) => s.id), [running.id]);
      expect(_rowIds(tester), [running.id]);
      expect(find.byType(SwapDetail), findsNothing);
      expect(find.byType(SwapSheet), findsOneWidget);
    });

    testOnMac('with as many others running as can be followed, puts the swap away and opens the sheet on the limit', (
      tester,
    ) async {
      final failed = fakeActiveSwap(status: SwapStatus.failed);
      final running = [
        for (var i = 1; i <= ActiveSwapsNotifier.maxFollowed; i++)
          fakeActiveSwap(depositAddress: '0x${i.toRadixString(16) * 40}'),
      ];
      // The newest, so that its row is at the top of a long list.
      final settings = await _open(tester, followed: [...running, failed]);
      await _openRow(tester, failed);

      await _press(tester, _inPanel(find.byKey(SwapDetail.startNewKey)));

      expect(settings.activeSwaps.map((s) => s.id), running.map((s) => s.id));
      expect(find.byType(SwapDetail), findsNothing);
      expect(find.byType(SwapSheet), findsOneWidget);
      expect(find.text(_l10n.swapTooManyFollowed(ActiveSwapsNotifier.maxFollowed)), findsOneWidget);
      expect(find.byKey(SwapSheet.amountFieldKey), findsNothing);
    });

    testOnMac('is not offered where swaps are no longer available', (tester) async {
      await _open(tester, swap: fakeActiveSwap(status: SwapStatus.failed), swapAvailable: false);
      await _openSwap(tester);

      expect(_inPanel(find.text(_l10n.commonDone)), findsOne);
      expect(_inPanel(find.byKey(SwapDetail.startNewKey)), findsNothing);
    });
  });

  group('Swap in the toolbar, with a swap followed', () {
    Finder swapAction() =>
        find.descendant(of: find.byType(AccountToolbar), matching: find.widgetWithText(ToolbarAction, _l10n.homeSwap));

    testOnMac('opens the form for another swap, and not the swap followed', (tester) async {
      final settings = await _open(tester, swap: fakeActiveSwap());

      await tester.tap(swapAction());
      await tester.pumpAndSettle();

      expect(find.byType(SwapSheet), findsOne);
      expect(_container(tester).read(shellSheetProvider), ShellSheet.swap);
      expect(find.byType(SwapDetail), findsNothing);
      expect(tester.widget<SwapRowView>(find.byType(SwapRowView)).isSelected, isFalse);
      expect(settings.activeSwaps, hasLength(1));
    });

    testOnMac('from another account opens the form on that account', (tester) async {
      await _open(tester, swap: fakeActiveSwap(), active: const RegularAccount(savingsAccount));
      expect(find.byType(SwapRowView), findsNothing);

      await tester.tap(swapAction());
      await tester.pumpAndSettle();

      expect(find.byType(SwapDetail), findsNothing);
      expect(
        find.descendant(of: find.byType(SwapSheet), matching: find.textContaining('Savings', findRichText: true)),
        findsWidgets,
      );
    });

    testOnMac('is offered by the account alone: a swap followed does not bring it where the account cannot swap', (
      tester,
    ) async {
      await _open(tester, swap: fakeActiveSwap(), active: const RegularAccount(encryptedAccount));
      expect(tester.widget<ToolbarAction>(swapAction()).onPressed, isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await _open(tester, swap: fakeActiveSwap(), swapAvailable: false);
      expect(swapAction(), findsNothing);
      expect(find.byType(SwapRowView), findsOne, reason: 'the swap is still reached by its row');
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
