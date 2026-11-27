import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/services/external_links.dart';
import 'package:quantus_desktop_wallet/ui/activity/activity_inspector.dart';
import 'package:quantus_desktop_wallet/ui/activity/activity_row_view.dart';
import 'package:quantus_desktop_wallet/ui/activity/wormhole_batches.dart';
import 'package:quantus_desktop_wallet/ui/components/copy_action.dart';
import 'package:quantus_desktop_wallet/ui/components/summary_row.dart';
import 'package:quantus_desktop_wallet/ui/components/toolbar_action.dart';
import 'package:quantus_desktop_wallet/ui/shell/desktop_shell.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/utils/explorer_url.dart';

import '../../fakes.dart';

final _l10n = lookupAppLocalizations(const Locale('en'));
final _now = DateTime.now();
const _bob = 'qzBob4hGy7UwE2nXk9VcMp3QsLd6TfRa8ZoJi1Wb5eNt9cPu';

/// A nullifier of 64 hex digits, all [digit].
String _nullifier(String digit) => '0x${digit * 64}';

/// An input of [tokens] spent with [nullifier].
WormholeUtxo _input(int tokens, String nullifier) {
  final utxo = encryptedUtxo(tokens);
  return WormholeUtxo(transfer: utxo.transfer, owner: utxo.owner, nullifierHex: nullifier);
}

WormholeSendBatch _batch(
  String extrinsicId, {
  required List<WormholeUtxo> inputs,
  int sent = 0,
  int change = 0,
  BigInt? fee,
  Duration ago = const Duration(hours: 3),
}) => WormholeSendBatch(
  extrinsicId: extrinsicId,
  blockHeight: 1,
  timestamp: _now.subtract(ago),
  inputs: inputs,
  sentToken: oneToken * BigInt.from(sent),
  changeToken: oneToken * BigInt.from(change),
  feeToken: fee ?? BigInt.zero,
);

WormholeTransferEvent _send(
  String id, {
  String to = _bob,
  List<WormholeSendBatch> batches = const [],
  Duration ago = const Duration(hours: 3),
}) => WormholeTransferEvent(
  id: id,
  from: 'qzEncrypted',
  to: to,
  amount: oneToken * BigInt.from(40),
  timestamp: _now.subtract(ago),
  fee: FakeSendChain.usualFee,
  extrinsicHash: '0x$id',
  blockNumber: 1,
  batches: batches,
);

/// A send in two batches: the first sent 25 with 3 of change, paying a fee,
/// from two inputs; the second sent 15 from one, with no change and no fee.
WormholeTransferEvent _twoBatches(String id, {String to = _bob}) => _send(
  id,
  to: to,
  batches: [
    _batch(
      '0x${id}first',
      sent: 25,
      change: 3,
      fee: FakeSendChain.usualFee,
      inputs: [_input(10, _nullifier('a')), _input(18, _nullifier('b'))],
      ago: const Duration(hours: 3, minutes: 2),
    ),
    _batch('0x${id}second', sent: 15, inputs: [_input(15, _nullifier('c'))]),
  ],
);

/// URLs handed to the browser.
final _opened = <Uri>[];

/// Opens the Encrypted account, whose history is [history].
Future<void> _openEncrypted(WidgetTester tester, List<TransactionEvent> history) async {
  _opened.clear();
  await pumpShell(
    tester,
    overrides: [
      ...shellOverrides(
        accounts: const [mainAccount, encryptedAccount],
        settings: FakeSettingsService(activeAccount: const RegularAccount(encryptedAccount)),
        balances: oneTokenEach,
        encryptedBalances: {0: oneToken},
      ),
      encryptedHistoryProvider.overrideWith((ref, walletIndex) => AsyncValue.data(history)),
      openExternalUrlProvider.overrideWithValue((url) async => _opened.add(url)),
    ],
  );
}

Future<void> _openRow(WidgetTester tester, String id) async {
  await tester.tap(find.byWidgetPredicate((widget) => widget is ActivityRowView && widget.id == id));
  await tester.pumpAndSettle();
}

Finder _inPanel(Finder finder) => find.descendant(of: find.byType(ActivityInspector), matching: finder);

Finder get _heading => _inPanel(find.byKey(WormholeBatches.headingKey));

Finder _inBatch(String extrinsicId, Finder finder) =>
    find.descendant(of: find.byKey(WormholeBatches.batchKey(extrinsicId)), matching: finder);

Future<void> _toggle(WidgetTester tester) async {
  await tester.ensureVisible(_heading);
  await tester.pumpAndSettle();
  await tester.tap(_heading);
  await tester.pumpAndSettle();
}

String _money(WidgetTester tester, BigInt amount) {
  final container = ProviderScope.containerOf(tester.element(find.byType(DesktopShell)));
  final formatting = container.read(numberFormattingServiceProvider);
  return _l10n.commonAmountBalance(formatting.formatBalance(amount), AppConstants.tokenSymbol);
}

/// The label and figure of each row of the batch of [extrinsicId].
List<(String, String?)> _figures(WidgetTester tester, String extrinsicId) => [
  for (final row in tester.widgetList<FigureRow>(_inBatch(extrinsicId, find.byType(FigureRow)))) (row.label, row.value),
];

void main() {
  testOnMac('a send in batches shows them closed under BATCHES (2), last, below its own View in Explorer', (
    tester,
  ) async {
    await _openEncrypted(tester, [_twoBatches('out')]);
    await _openRow(tester, 'out');

    expect(_inPanel(find.text('BATCHES (2)')), findsOneWidget);
    expect(_inPanel(find.byIcon(CupertinoIcons.chevron_right)), findsOneWidget);
    expect(_inPanel(find.text('BATCH 1 OF 2')), findsNothing);
    final explorer = _inPanel(find.widgetWithText(ToolbarAction, _l10n.desktopViewInExplorer));
    expect(explorer, findsOneWidget);
    expect(tester.getTopLeft(_heading).dy, greaterThan(tester.getBottomLeft(explorer).dy));
  });

  testOnMac('a click opens the batches in chain order, and another closes them', (tester) async {
    await _openEncrypted(tester, [_twoBatches('out')]);
    await _openRow(tester, 'out');

    await _toggle(tester);
    expect(_inPanel(find.byIcon(CupertinoIcons.chevron_down)), findsOneWidget);
    final first = _inPanel(find.text('BATCH 1 OF 2'));
    final second = _inPanel(find.text('BATCH 2 OF 2'));
    expect(first, findsOneWidget);
    expect(second, findsOneWidget);
    expect(tester.getTopLeft(first).dy, lessThan(tester.getTopLeft(second).dy));
    // A hairline over each batch parts it from what comes before.
    for (final id in ['0xoutfirst', '0xoutsecond']) {
      final hairline = _inBatch(id, find.byType(MenuDivider));
      expect(hairline, findsOneWidget);
      expect(
        tester.getTopLeft(hairline).dy,
        lessThan(tester.getTopLeft(_inBatch(id, find.textContaining('BATCH '))).dy),
      );
    }
    expect(
      tester.getTopLeft(find.byKey(WormholeBatches.batchKey('0xoutfirst'))).dy,
      lessThan(tester.getTopLeft(find.byKey(WormholeBatches.batchKey('0xoutsecond'))).dy),
    );

    await _toggle(tester);
    expect(_inPanel(find.text('BATCH 1 OF 2')), findsNothing);
  });

  testOnMac('the heading takes the keyboard\'s focus, opens and closes with Space and Return, and is heard', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _openEncrypted(tester, [_twoBatches('out')]);
    await _openRow(tester, 'out');

    expect(
      tester.getSemantics(_heading),
      isSemantics(label: 'Batches (2)', isButton: true, hasExpandedState: true, isExpanded: false, hasTapAction: true),
    );

    Focus.of(tester.element(_inPanel(find.text('BATCHES (2)')))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(_inPanel(find.text('BATCH 1 OF 2')), findsOneWidget);
    expect(tester.getSemantics(_heading), isSemantics(label: 'Batches (2)', isButton: true, isExpanded: true));

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(_inPanel(find.text('BATCH 1 OF 2')), findsNothing);
    semantics.dispose();
  });

  testOnMac('a batch shows its date, what it sent, its change and fee, its whole hash to copy, and its page', (
    tester,
  ) async {
    await _openEncrypted(tester, [_twoBatches('out')]);
    await _openRow(tester, 'out');
    await _toggle(tester);

    final date = DatetimeFormattingService.formatTxDateTime(_now.subtract(const Duration(hours: 3, minutes: 2)));
    expect(_inBatch('0xoutfirst', find.text(date)), findsOneWidget);
    expect(_figures(tester, '0xoutfirst'), [
      ('Sent', _money(tester, oneToken * BigInt.from(25))),
      ('Change', _money(tester, oneToken * BigInt.from(3))),
      (_l10n.desktopSendTransactionFee, _money(tester, FakeSendChain.usualFee)),
    ]);
    expect(_inBatch('0xoutfirst', find.text('0xoutfirst')), findsOneWidget);
    expect(tester.widget<CopyAction>(_inBatch('0xoutfirst', find.byType(CopyAction))).text, '0xoutfirst');

    final explorer = _inBatch('0xoutfirst', find.widgetWithText(ToolbarAction, _l10n.desktopViewInExplorer));
    await tester.ensureVisible(explorer);
    await tester.pumpAndSettle();
    await tester.tap(explorer);
    await tester.pumpAndSettle();
    expect(_opened, [Uri.parse(wormholeExplorerUrl('0xoutfirst'))]);
  });

  testOnMac('a batch leaves out a change and a fee of nothing, and what it sent when the recipient is unknown', (
    tester,
  ) async {
    await _openEncrypted(tester, [_twoBatches('out'), _twoBatches('unknown', to: '')]);

    await _openRow(tester, 'out');
    await _toggle(tester);
    expect(_figures(tester, '0xoutsecond'), [('Sent', _money(tester, oneToken * BigInt.from(15)))]);

    await _openRow(tester, 'unknown');
    await _toggle(tester);
    expect(_figures(tester, '0xunknownfirst'), [
      ('Change', _money(tester, oneToken * BigInt.from(3))),
      (_l10n.desktopSendTransactionFee, _money(tester, FakeSendChain.usualFee)),
    ]);
  });

  testOnMac('INPUTS (2) lists each input\'s amount with its whole nullifier under it', (tester) async {
    await _openEncrypted(tester, [_twoBatches('out')]);
    await _openRow(tester, 'out');
    await _toggle(tester);

    expect(_inBatch('0xoutfirst', find.text('INPUTS (2)')), findsOneWidget);
    for (final (tokens, digit) in [(10, 'a'), (18, 'b')]) {
      final amount = _inBatch('0xoutfirst', find.text(_money(tester, oneToken * BigInt.from(tokens))));
      final nullifier = _inBatch('0xoutfirst', find.text(_nullifier(digit)));
      expect(amount, findsOneWidget);
      expect(nullifier, findsOneWidget);
      expect(tester.getTopLeft(nullifier).dy, greaterThanOrEqualTo(tester.getBottomLeft(amount).dy));
    }
    expect(_inBatch('0xoutsecond', find.text('INPUTS (1)')), findsOneWidget);
  });

  testOnMac('a transparent transfer has no batches heading', (tester) async {
    await pumpShell(
      tester,
      overrides: shellOverrides(
        accounts: const [mainAccount],
        settings: FakeSettingsService(activeAccount: const RegularAccount(mainAccount)),
        balances: oneTokenEach,
        chain: FakeSendChain()
          ..historyPages = [
            [
              TransferEvent(
                id: 'sent',
                from: 'qzMain',
                to: _bob,
                amount: oneToken,
                timestamp: _now.subtract(const Duration(hours: 1)),
                fee: FakeSendChain.usualFee,
                extrinsicHash: '0xsent',
                blockNumber: 1,
                blockHash: '0xblock',
              ),
            ],
          ],
      ),
    );
    await _openRow(tester, 'sent');
    expect(find.byType(ActivityInspector), findsOneWidget);
    expect(_heading, findsNothing);
  });

  testOnMac('a private send with no batches and a private receipt have no batches heading', (tester) async {
    await _openEncrypted(tester, [
      _send('plain', ago: const Duration(hours: 1)),
      WormholeTransferEvent(
        id: 'in',
        from: _bob,
        to: 'qzEncrypted',
        amount: oneToken,
        timestamp: _now.subtract(const Duration(hours: 2)),
        fee: FakeSendChain.usualFee,
        extrinsicHash: '0xin',
        blockNumber: 1,
      ),
    ]);
    await _openRow(tester, 'plain');
    expect(_heading, findsNothing);
    await _openRow(tester, 'in');
    expect(_heading, findsNothing);
  });

  testOnMac('with one send\'s batches open, another send opens with its batches closed', (tester) async {
    await _openEncrypted(tester, [
      _twoBatches('first', to: _bob),
      _send(
        'second',
        ago: const Duration(hours: 5),
        batches: [
          _batch('0xsecondonly', sent: 40, inputs: [_input(40, _nullifier('d'))]),
        ],
      ),
    ]);
    await _openRow(tester, 'first');
    await _toggle(tester);
    expect(_inPanel(find.text('BATCH 1 OF 2')), findsOneWidget);

    await _openRow(tester, 'second');
    expect(_inPanel(find.text('BATCHES (1)')), findsOneWidget);
    expect(_inPanel(find.text('BATCH 1 OF 1')), findsNothing);
  });
}
