import 'package:convert/convert.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/src/testing/call_corpus.dart';
import 'package:resonance_network_wallet/v2/components/decoded_call_view.dart';

import 'package:resonance_network_wallet/models/fiat_currency.dart';
import 'package:resonance_network_wallet/providers/currency_display_provider.dart';

import '../extensions.dart';

/// What the mobile wallet is willing to show as a proposal's inner call. Kept
/// as names rather than ids so a drift in either direction is visible here.
const allowedInProposal = {
  'Balances.transfer_allow_death',
  'Balances.transfer_keep_alive',
  'Balances.transfer_all',
  'ReversibleTransfers.schedule_transfer',
  'ReversibleTransfers.schedule_transfer_with_delay',
  'ReversibleTransfers.cancel',
  'ReversibleTransfers.execute_transfer',
  'ReversibleTransfers.set_high_security',
  'Multisig.create_multisig',
  'Utility.batch_all',
};

Iterable<String> renderedText(WidgetTester tester) sync* {
  for (final widget in tester.allWidgets) {
    if (widget is Text && widget.data != null) yield widget.data!;
    if (widget is RichText) yield widget.text.toPlainText();
  }
}

void main() {
  test('the corpus and the policy agree on what a proposal may carry', () {
    final corpusCalls = callCorpus.keys.map((k) => k.split(' ').first).toSet();
    expect(
      allowedInProposal.difference(corpusCalls),
      isEmpty,
      reason: 'the policy names a call the runtime no longer declares',
    );
  });

  group('a proposal the wallet cannot display fails closed', () {
    for (final entry in callCorpus.entries) {
      final name = entry.key.split(' ').first;
      if (allowedInProposal.contains(name)) continue;

      test('${entry.key} decodes to nothing', () {
        expect(
          () => MultisigProposal.decodeProposalCall(hex.decode(entry.value)),
          throwsA(isA<FormatException>()),
          reason: '$name reached the mobile wallet, which cannot describe it',
        );
      });
    }
  });

  group('a proposal the wallet does display renders every field', () {
    for (final entry in callCorpus.entries) {
      final name = entry.key.split(' ').first;
      if (!allowedInProposal.contains(name)) continue;
      if (name == 'Utility.batch_all') continue; // its children are covered by the transfers below

      testWidgets(entry.key, (tester) async {
        final decoded = MultisigProposal.decodeProposalCall(hex.decode(entry.value));
        await tester.pumpApp(
          SingleChildScrollView(child: DecodedCallView(call: decoded)),
          overrides: [
            txAmountDisplayProvider.overrideWithValue(
              (
                BigInt amount, {
                required bool isSend,
                int tokenDecimals = 12,
                bool withTokenSymbol = true,
                bool withSignPrefix = false,
                String? customHiddenText,
              }) => CurrencyDisplayState(
                primaryAmount: '$amount',
                secondaryAmount: '',
                isFlipped: false,
                selectedFiat: FiatCurrency.usd,
              ),
            ),
          ],
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: '${entry.key}: the sheet overflowed or threw');

        final texts = renderedText(tester).toList();
        expect(texts, isNotEmpty);
        for (final text in texts) {
          expect(text, isNot(anyOf(contains("Instance of '"), contains('MapEntry('))));
        }
        expect(texts.any((t) => t.contains(decoded.call.split('_').first)), isTrue);
      });
    }
  });
}
