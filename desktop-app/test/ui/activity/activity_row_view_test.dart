import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/ui/activity/activity_row_view.dart';
import 'package:quantus_desktop_wallet/ui/components/account_label.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_address_checkphrase.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/activity/activity_row.dart';
import 'package:wallet_core/l10n/app_localizations.dart';

import '../../fakes.dart';

final _l10n = lookupAppLocalizations(const Locale('en'));
const _colors = AppColorsV3.dark();
const _bob = 'qzBob4hGy7UwE2nXk9VcMp3QsLd6TfRa8ZoJi1Wb5eNt9cPu';

ActivityRow _row({
  String label = 'Sent',
  ActivityHighlight highlight = ActivityHighlight.none,
  bool isSend = true,
  bool hidesAmount = false,
  bool movedNothing = false,
  ActivityCounterparty counterparty = const ActivityAccount(_bob, isRecipient: true),
}) => ActivityRow(
  label: label,
  timeLabel: '1d ago',
  highlight: highlight,
  icon: ActivityIcon.direction,
  isSend: isSend,
  amount: oneToken,
  hidesAmount: hidesAmount,
  counterparty: counterparty,
  movedNothing: movedNothing,
);

Future<void> _pump(
  WidgetTester tester,
  ActivityRow row, {
  ActivityRowForm form = ActivityRowForm.wide,
  BaseAccount? ownCounterparty,
  bool isSelected = false,
  bool hasFocus = true,
  double width = 900,
}) async {
  useFakeCheckphrases(fakeCheckphrase);
  await tester.pumpWidget(
    ProviderScope(
      child: Builder(
        builder: (context) => MaterialApp(
          theme: AppTheme.darkTheme(context, text: const AppTextThemeV3.desktop()),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: ActivityRowView(
                  id: 'tx',
                  row: row,
                  amountText: '1 QTC',
                  form: form,
                  l10n: _l10n,
                  ownCounterparty: ownCounterparty,
                  isSelected: isSelected,
                  hasFocus: hasFocus,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Text _text(WidgetTester tester, String data) => tester.widget<Text>(find.text(data));

Color? _backing(WidgetTester tester) {
  final box = tester.widget<Container>(
    find.descendant(of: find.byType(ActivityRowView), matching: find.byType(Container)).first,
  );
  return (box.decoration as BoxDecoration?)?.color;
}

void main() {
  test('its form follows the width it has: wide, then tight, then brief', () {
    expect(ActivityRowForm.of(ActivityRowForm.wideFrom), ActivityRowForm.wide);
    expect(ActivityRowForm.of(ActivityRowForm.wideFrom - 1), ActivityRowForm.tight);
    expect(ActivityRowForm.of(ActivityRowForm.tightFrom), ActivityRowForm.tight);
    expect(ActivityRowForm.of(ActivityRowForm.tightFrom - 1), ActivityRowForm.brief);
  });

  testWidgets('wide: on one line, what over when, then To and the whole address over its checkphrase, '
      'then the amount', (tester) async {
    await _pump(tester, _row());

    final label = tester.getRect(find.text('Sent'));
    final time = tester.getRect(find.text('1d ago'));
    final to = tester.getRect(find.text(_l10n.activityTxTo));
    final address = tester.getRect(find.text(_bob));
    final amount = tester.getRect(find.text('-1 QTC'));
    expect(time.top, greaterThan(label.top));
    expect(to.left, greaterThan(label.right));
    expect(address.left, greaterThanOrEqualTo(to.right));
    expect(find.text('Phrase-$_bob'), findsOne);
    expect(amount.left, greaterThan(address.right));
    expect((amount.center.dy - label.center.dy).abs(), lessThan(24));
  });

  testWidgets('tight: what, when and the amount on top, who under them', (tester) async {
    await _pump(tester, _row(), form: ActivityRowForm.tight, width: 520);

    final label = tester.getRect(find.text('Sent'));
    expect((tester.getRect(find.text('1d ago')).center.dy - label.center.dy).abs(), lessThan(4));
    expect((tester.getRect(find.text('-1 QTC')).center.dy - label.center.dy).abs(), lessThan(4));
    expect(tester.getRect(find.text(_bob)).top, greaterThan(label.bottom));
    // The amount keeps to the row's right end, the time close after the label.
    expect(tester.getRect(find.text('-1 QTC')).right, moreOrLessEquals(520 - 8, epsilon: 0.5));
    expect(tester.getRect(find.text('1d ago')).left, moreOrLessEquals(label.right + 8, epsilon: 0.5));
  });

  testWidgets('brief: no who', (tester) async {
    await _pump(tester, _row(), form: ActivityRowForm.brief, width: 300);

    expect(find.text(_bob), findsNothing);
    expect(find.byType(DesktopAddressCheckphrase), findsNothing);
    expect(find.text('-1 QTC'), findsOne);
  });

  testWidgets('one of the wallet\'s own accounts shows as its badge and name, not its address', (tester) async {
    await _pump(tester, _row(), ownCounterparty: savingsAccount);

    expect(find.byType(AccountLabel), findsOne);
    expect(find.text('Savings'), findsOne);
    expect(find.byType(DesktopAddressCheckphrase), findsNothing);
  });

  testWidgets('a sender with no address is named in words after From', (tester) async {
    await _pump(tester, _row(label: 'Received', isSend: false, counterparty: const ActivityMiningReward()));

    expect(find.text(_l10n.activityTxFrom), findsOne);
    expect(find.text(_l10n.activitySenderMiningReward), findsOne);
  });

  group('colours', () {
    testWidgets('settled: plain; what came in is sage', (tester) async {
      await _pump(tester, _row());
      expect(_text(tester, 'Sent').style?.color, _colors.textContent);
      expect(_text(tester, '-1 QTC').style?.color, _colors.textContent);

      await _pump(tester, _row(label: 'Received', isSend: false));
      expect(_text(tester, 'Received').style?.color, _colors.textContent);
      expect(_text(tester, '+1 QTC').style?.color, _colors.semanticSage);
    });

    testWidgets('under way: glacier on its way out, sage on its way in', (tester) async {
      await _pump(tester, _row(label: 'Sending', highlight: ActivityHighlight.leaving));
      expect(_text(tester, 'Sending').style?.color, _colors.semanticGlacier);
      expect(_text(tester, '-1 QTC').style?.color, _colors.semanticGlacier);

      await _pump(tester, _row(label: 'Receiving', isSend: false, highlight: ActivityHighlight.arriving));
      expect(_text(tester, 'Receiving').style?.color, _colors.semanticSage);
      expect(_text(tester, '+1 QTC').style?.color, _colors.semanticSage);
    });

    testWidgets('what moved nothing is muted and unsigned; no amount is a dash', (tester) async {
      await _pump(tester, _row(label: 'Proposal cancelled', movedNothing: true));
      expect(_text(tester, '1 QTC').style?.color, _colors.textMuted);

      await _pump(tester, _row(label: 'Proposal approved', hidesAmount: true));
      expect(find.text('—'), findsOne);
    });
  });

  testWidgets('a selected row has a backing, quieter while the keys are in another panel', (tester) async {
    await _pump(tester, _row());
    expect(_backing(tester), isNull);

    await _pump(tester, _row(), isSelected: true);
    final selected = _backing(tester);
    await _pump(tester, _row(), isSelected: true, hasFocus: false);
    final quieter = _backing(tester);

    expect(selected, _colors.textContent.useOpacity(0.1));
    expect(quieter, _colors.textContent.useOpacity(0.05));
  });
}
