import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/generated/planck/pallets/balances.dart' as balances_pallet;
import 'package:quantus_sdk/generated/planck/pallets/multisig.dart' as multisig_pallet;
import 'package:quantus_sdk/generated/planck/pallets/tech_collective.dart' as collective_pallet;
import 'package:quantus_sdk/generated/planck/types/sp_runtime/multiaddress/multi_address.dart' as multi_address;
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/address_with_checkphrase.dart';
import 'package:quantus_cold_wallet/components/call_detail_view.dart';
import 'package:quantus_cold_wallet/debug/debug_payloads.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/screens/sign_transaction_screen.dart';
import 'package:quantus_cold_wallet/theme/app_theme.dart';

final aliceId = Uint8List.fromList(List.filled(32, 0xAA));
final bobId = Uint8List.fromList(List.filled(32, 0xBB));
final oneToken = BigInt.from(1000000000000);
const signerAddress = 'qz-test-signer-address';

multi_address.MultiAddress account(Uint8List id) => multi_address.MultiAddress.values.id(id);

DecodedCall roundTrip(RuntimeCall call) => CallDecoder.decodeBytes(call.encode());

/// The screen's contract: every field of [call] reaches the screen exactly
/// once — as its own row, or restated by the summary hero the body leads with.
/// A field is only ever suppressed for the exact hero widget that restates it.
void expectEveryFieldShownOnce(DecodedCall call) {
  final body = callSummaryBody(call);
  final rows = body.whereType<CallFieldView>().map((w) => w.field).toList();
  final summary = heroSummary(call);
  final showsAmount = body.any((w) => w is TransferAmount);
  final showsRecipient = body.any((w) => w is AddressWithCheckphrase && w.label == 'To');

  for (final field in call.fields) {
    final restated =
        (showsAmount && identical(field, summary?.amountField)) ||
        (showsRecipient && identical(field, summary?.recipientField));
    expect(
      rows.where((f) => identical(f, field)).length,
      restated ? 0 : 1,
      reason: '${call.displayTitle}: "${field.label}" must reach the screen exactly once',
    );
    if (field is NestedCallField) expectEveryFieldShownOnce(field.call);
  }
}

Future<void> pumpSignScreen(WidgetTester tester, Uint8List payload) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        addressProvider.overrideWith((ref) => signerAddress),
        addressCheckphraseProvider.overrideWith((ref, address) async => 'check phrase'),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Theme(
            data: AppTheme.darkTheme(context),
            child: SignTransactionScreen(payload: payload),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

AddressWithCheckphrase signerRow(WidgetTester tester) => tester.widget<AddressWithCheckphrase>(
  find.byWidgetPredicate((w) => w is AddressWithCheckphrase && w.address == signerAddress),
);

void main() {
  group('every field reaches the screen exactly once', () {
    final fixtures = <String, RuntimeCall>{
      'plain transfer': const balances_pallet.Txs().transferAllowDeath(dest: account(bobId), value: oneToken),
      'force_transfer with source == destination': const balances_pallet.Txs().forceTransfer(
        source: account(bobId),
        dest: account(bobId),
        value: oneToken,
      ),
      'multisig approve wrapping a transfer': const multisig_pallet.Txs().approve(
        multisigAddress: aliceId,
        proposalId: 12,
        call: const balances_pallet.Txs().transferAllowDeath(dest: account(bobId), value: oneToken).encode(),
      ),
      'governance vote (no transfer summary)': const collective_pallet.Txs().vote(poll: 7, aye: true),
    };

    for (final entry in fixtures.entries) {
      test(entry.key, () => expectEveryFieldShownOnce(roundTrip(entry.value)));
    }
  });

  test('force_transfer keeps its Source row even when it equals the recipient', () {
    final call = roundTrip(
      const balances_pallet.Txs().forceTransfer(source: account(bobId), dest: account(bobId), value: oneToken),
    );
    final body = callSummaryBody(call);
    final labels = body.whereType<CallFieldView>().map((w) => w.field.label).toList();
    expect(labels, contains('Source'));
    expect(labels, isNot(contains('Destination')), reason: 'the To row already restates the destination');
    expect(body.any((w) => w is AddressWithCheckphrase && w.label == 'To'), isTrue);
  });

  group('sign screen', () {
    testWidgets('the exact pallet · call is on screen at every depth', (tester) async {
      final inner = const balances_pallet.Txs().transferAllowDeath(dest: account(bobId), value: oneToken);
      final payload = DebugPayloads.withExtensions(
        const multisig_pallet.Txs().approve(multisigAddress: aliceId, proposalId: 12, call: inner.encode()),
      );
      await pumpSignScreen(tester, payload);

      expect(find.text('MULTISIG APPROVE'), findsOneWidget);
      expect(find.text('Multisig · approve'), findsOneWidget);
      expect(find.text('SEND'), findsOneWidget);
      expect(find.text('Balances · transfer_allow_death'), findsOneWidget);
    });

    testWidgets('signer row reads From for a plain send', (tester) async {
      await pumpSignScreen(
        tester,
        DebugPayloads.withExtensions(
          const balances_pallet.Txs().transferAllowDeath(dest: account(bobId), value: oneToken),
        ),
      );
      expect(find.text('SEND'), findsOneWidget);
      expect(find.text('Balances · transfer_allow_death'), findsOneWidget);
      expect(signerRow(tester).label, 'From');
    });

    testWidgets('signer row reads Signed by when the funds leave an explicit source', (tester) async {
      await pumpSignScreen(
        tester,
        DebugPayloads.withExtensions(
          const balances_pallet.Txs().forceTransfer(source: account(aliceId), dest: account(bobId), value: oneToken),
        ),
      );
      expect(signerRow(tester).label, 'Signed by');
    });

    testWidgets('signer row reads Signed by when nothing is sent', (tester) async {
      await pumpSignScreen(tester, DebugPayloads.governanceVoteAye());
      expect(signerRow(tester).label, 'Signed by');
    });
  });
}
