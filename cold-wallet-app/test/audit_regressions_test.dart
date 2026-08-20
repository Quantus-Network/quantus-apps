import 'package:convert/convert.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/generated/planck/pallets/utility.dart' as utility_pallet;
import 'package:quantus_sdk/quantus_sdk.dart';
// ignore: implementation_imports — the generated corpus is test data, deliberately not public SDK API.
import 'package:quantus_sdk/src/testing/call_corpus.dart';
import 'package:quantus_cold_wallet/components/address_with_checkphrase.dart';
import 'package:quantus_cold_wallet/components/quantus_button.dart';
import 'package:quantus_cold_wallet/debug/debug_payloads.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/screens/sign_transaction_screen.dart';
import 'package:quantus_cold_wallet/theme/app_theme.dart';

import 'every_call_renders_test.dart' show renderedText;

/// Every payload here is one an audit researcher used against the previous
/// wallet, where it produced a screen that did not describe what would execute:
/// a multisig approval showing a zero amount, a batch showing no calls at all,
/// a headline taken from a branch that was guaranteed to fail, or a benign
/// `add_member` standing in for a `transfer_all` the chain would run.
///
/// These are negative tests. Each asserts the payload never reaches a signable
/// screen, and — the part that matters — that none of the benign text the
/// attack depended on is rendered on the way to refusing it. A screen that
/// refuses while still showing "SEND 1000 QUAN" has not fixed anything.
///
/// Each group names the audit report it comes from.
const wallet = AppConstants.debugTestAddress;

Future<void> pumpRequest(WidgetTester tester, SigningRequest request) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        addressesProvider.overrideWith((ref) => {wallet: ColdAccount(label: 'Account 1', index: 0)}),
        addressCheckphraseProvider.overrideWith((ref, address) async => 'check phrase'),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Theme(
            data: AppTheme.darkTheme(context),
            child: SignTransactionScreen(request: request),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The signer's only safe response to a payload it cannot read in full: say so,
/// and offer no way to sign it.
void expectFailedClosed(WidgetTester tester) {
  expect(tester.takeException(), isNull);
  expect(find.text('Could not read transaction'), findsOneWidget);
  expect(
    find.widgetWithText(QuantusButton, 'Sign'),
    findsNothing,
    reason: 'the screen offered a way to sign a payload it could not read',
  );
}

void expectNothingReads(WidgetTester tester, List<String> forbidden) {
  final shown = renderedText(tester).join('\n');
  for (final text in forbidden) {
    expect(
      shown,
      isNot(contains(text)),
      reason: 'the refusing screen still showed "$text", which the attack relied on the signer reading',
    );
  }
}

DebugCall attack(String fragment) =>
    DebugPayloads.invalidQrData.firstWhere((c) => c.label.contains(fragment), orElse: () => throw StateError(fragment));

Future<void> expectRefused(
  WidgetTester tester,
  String fragment, {
  required String because,
  List<String> nothingReads = const [],
}) async {
  final call = attack(fragment);
  expect(
    () => CallDecoder.decodeBytes(call.call, policy: const FullCallPolicy()),
    throwsA(isA<FormatException>().having((e) => e.message, 'message', contains(because))),
  );

  await pumpRequest(
    tester,
    SigningRequest(signer: call.signer ?? wallet, payload: DebugPayloads.payloadForCall(call.call)),
  );
  expectFailedClosed(tester);
  expectNothingReads(tester, nothingReads);
}

void main() {
  group('#88483 — a call padded with a trailing byte is not the call it decodes to', () {
    testWidgets('a multisig approval carrying a padded inner call is refused', (tester) async {
      // The pallet stores all 44 bytes and executes the 43-byte transfer inside
      // them. A wallet that reads 43 and ignores the 44th describes a different
      // proposal from the one it approves, so the whole payload is refused.
      await expectRefused(
        tester,
        'inner call padded',
        because: 'trailing bytes after nested call',
        nothingReads: ['MULTISIG APPROVE', 'SEND', 'QUAN'],
      );
    });

    testWidgets('a top-level call padded with a trailing byte is refused', (tester) async {
      await expectRefused(
        tester,
        'transfer padded',
        because: 'trailing bytes after nested call',
        nothingReads: ['SEND', 'QUAN'],
      );
    });
  });

  group('#89008 — a call inside a batch that cannot be decoded refuses the batch', () {
    testWidgets('one undecodable child is not summarised away', (tester) async {
      // The previous wallet caught this failure, showed the batch's generic
      // label with no amount and no recipient, and left Approve enabled.
      await expectRefused(
        tester,
        'second call cannot be decoded',
        because: 'Invalid variant index',
        nothingReads: ['UTILITY BATCH ALL', 'BATCH', 'CALL 1', 'SEND'],
      );
    });
  });

  group('#88914 / #88348 — a call whose headline comes from a branch that will not run', () {
    testWidgets('if_else is refused rather than headlined by its main branch', (tester) async {
      await expectRefused(
        tester,
        'if_else headlining',
        because: 'Utility: invalid call index',
        nothingReads: ['IF ELSE', 'SEND', 'QUAN'],
      );
    });

    testWidgets('force_batch, which continues past a failing call, is refused', (tester) async {
      await expectRefused(
        tester,
        'force_batch',
        because: 'Utility: invalid call index',
        nothingReads: ['FORCE BATCH', 'SEND'],
      );
    });

    test('the only Utility call this wallet reads is batch_all', () {
      // The exponential-decode and hidden-fallback reports both turned on a
      // second Utility wrapper existing. Every index but batch_all is refused
      // at the index byte, before an argument is read.
      final batchAll = const utility_pallet.Txs().batchAll(calls: []).encode();
      for (var index = 0; index < 16; index++) {
        if (index == batchAll[1]) continue;
        expect(
          () => CallDecoder.decodeBytes([batchAll[0], index, 0, 0, 0], policy: const FullCallPolicy()),
          throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('invalid call index'))),
          reason: 'Utility call index $index was read instead of refused',
        );
      }
    });
  });

  group('#88730 — bytes that decode to different calls under two schemas', () {
    testWidgets('the 268-byte cross-schema payload never renders its benign reading', (tester) async {
      // Under the runtime's schema these bytes are a force_batch containing
      // transfer_all; under the codec the old wallet used they were an
      // add_member and an opaque proof. Neither reading reaches the screen.
      await expectRefused(
        tester,
        'cross-schema payload',
        because: 'Utility: invalid call index',
        nothingReads: ['ADD MEMBER', 'TECH COLLECTIVE', 'WORMHOLE', 'SEND', 'TRANSFER ALL'],
      );
    });

    testWidgets('an Index destination is refused, not read as an account', (tester) async {
      await expectRefused(
        tester,
        'Index address',
        because: 'only a plain account id is accepted',
        nothingReads: ['SEND', 'QUAN'],
      );
    });

    testWidgets('an Address20 destination is refused', (tester) async {
      await expectRefused(
        tester,
        'Address20',
        because: 'only a plain account id is accepted',
        nothingReads: ['SEND', 'QUAN'],
      );
    });

    // The boundary shift the payload is built on needs an address form the two
    // schemas frame differently. The decoder resolves none of them, so this
    // asserts what the signer sees: for every encoding the corpus generates of
    // such a form, the only address drawn as an address — the only one carrying
    // a checkphrase to verify — is the signer's own row. A call the describers
    // do not cover still renders, through the generic walk, but it claims
    // nothing about the bytes it shows.
    for (final entry in refusedCallCorpus.entries) {
      testWidgets('${entry.key} is never drawn as an address', (tester) async {
        await pumpRequest(
          tester,
          SigningRequest(signer: wallet, payload: DebugPayloads.payloadForCall(hex.decode(entry.value))),
        );

        expect(tester.takeException(), isNull);
        for (final row in tester.widgetList<AddressWithCheckphrase>(find.byType(AddressWithCheckphrase))) {
          expect(
            row.address,
            wallet,
            reason: '${entry.key}: "${row.address}" was drawn as an address the runtime cannot resolve',
          );
        }
      });
    }
  });

  group('a request for an account this wallet does not hold', () {
    testWidgets('names the account and offers no way to sign', (tester) async {
      final call = attack('addressed to another account');
      await pumpRequest(tester, SigningRequest(signer: call.signer!, payload: DebugPayloads.payloadForCall(call.call)));

      expect(tester.takeException(), isNull);
      expect(find.textContaining('which this wallet does not hold'), findsOneWidget);
      expect(find.widgetWithText(QuantusButton, 'Sign'), findsNothing);
    });
  });

  group('every payload in the invalid-QR catalogue fails closed', () {
    for (final call in DebugPayloads.invalidQrData) {
      testWidgets(call.label, (tester) async {
        await pumpRequest(
          tester,
          SigningRequest(signer: call.signer ?? wallet, payload: DebugPayloads.payloadForCall(call.call)),
        );

        expect(tester.takeException(), isNull);
        expect(
          find.widgetWithText(QuantusButton, 'Sign'),
          findsNothing,
          reason: '${call.label} reached a signable screen',
        );
      });
    }
  });
}
