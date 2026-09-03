import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/src/testing/call_corpus.dart';
import 'package:quantus_cold_wallet/debug/debug_payloads.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/screens/sign_transaction_screen.dart';

import 'call_display_test.dart' show expectEveryFieldShownOnce, signerAddress;

/// The smallest supported handset, the reference size, and the smallest at the
/// largest text scale — where fixed-height bottom content actually breaks.
const surfaces = [
  (label: '320x568', size: Size(320, 568), scale: 1.0),
  (label: '375x667', size: Size(375, 667), scale: 1.0),
  (label: '320x568 @2x text', size: Size(320, 568), scale: 2.0),
];

Uint8List payloadFor(String callHex) => DebugPayloads.payloadForCall(Uint8List.fromList(hex.decode(callHex)));

Future<void> pumpAt(WidgetTester tester, Uint8List payload, Size size, double scale) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        addressesProvider.overrideWith(
          (ref) => {signerAddress: ColdAccount(label: 'Account 1', index: 0, scheme: DilithiumSchemeExtension.legacy)},
        ),
        checksumNameProvider.overrideWith((ref, address) async => 'check phrase'),
      ],
      child: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: MaterialApp(
          home: Builder(
            builder: (context) => Theme(
              data: AppTheme.darkTheme(context),
              child: SignTransactionScreen(
                request: SigningRequest(signer: signerAddress, payload: payload),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Iterable<String> renderedText(WidgetTester tester) sync* {
  for (final widget in tester.allWidgets) {
    if (widget is Text && widget.data != null) yield widget.data!;
    if (widget is RichText) yield widget.text.toPlainText();
  }
}

/// Everything the debug catalogue offers: every call the runtime declares, plus
/// the wrapper shapes composed by hand because the corpus fills every nested
/// call slot with the same placeholder remark.
final catalogue = [for (final entry in DebugPayloads.byPallet.entries) ...entry.value];

String nameOf(DebugCall call) => '${call.pallet}.${call.label}';

void main() {
  group('every call the debug catalogue offers renders on the signing screen', () {
    for (final call in catalogue) {
      testWidgets(nameOf(call), (tester) async {
        final payload = DebugPayloads.payloadForCall(call.call);

        for (final surface in surfaces) {
          await pumpAt(tester, payload, surface.size, surface.scale);

          expect(
            tester.takeException(),
            isNull,
            reason: '${nameOf(call)} at ${surface.label}: the screen overflowed or threw',
          );

          final texts = renderedText(tester).toList();
          expect(texts, isNotEmpty, reason: '${nameOf(call)} at ${surface.label}: nothing rendered');
          for (final text in texts) {
            expect(
              text,
              isNot(anyOf(contains("Instance of '"), contains('MapEntry('))),
              reason: '${nameOf(call)} at ${surface.label}: a Dart object reached the screen',
            );
          }

          for (final paragraph in tester.renderObjectList<RenderParagraph>(find.byType(RichText))) {
            expect(
              paragraph.didExceedMaxLines,
              isFalse,
              reason: '${nameOf(call)} at ${surface.label}: "${paragraph.text.toPlainText()}" was truncated',
            );
          }
        }
      });
    }
  });

  group('every field reaches the screen exactly once', () {
    for (final call in catalogue) {
      test(nameOf(call), () {
        expectEveryFieldShownOnce(CallDecoder.decodeBytes(call.call, policy: const FullCallPolicy()));
      });
    }
  });

  group('a nested call renders at every level', () {
    test('the boxed inner call is rendered once per nesting level', () {
      final decoded = CallDecoder.decodeBytes(
        hex.decode(callCorpus['Multisig.propose']!),
        policy: const FullCallPolicy(),
      );

      expect(decoded.isWrapper, isTrue);
      expect(decoded.fields.whereType<NestedCallField>(), hasLength(1));
    });

    test('a multisig approval carries every call of the batch it approves', () {
      final approval = catalogue.firstWhere((c) => c.label == 'approve [batch_all of 16 transfers]');
      final decoded = CallDecoder.decodeBytes(approval.call, policy: const FullCallPolicy());

      final batch = decoded.fields.whereType<NestedCallField>().single.call;
      expect(batch.call, 'batch_all');
      // Pins the pure-Dart ss58 decode the catalogue builds addresses with
      // against the address it was given.
      final first = batch.fields.whereType<NestedCallField>().first.call;
      expect(
        first.fields.whereType<ValueField>().singleWhere((f) => f.kind == ValueKind.address).value,
        AppConstants.debugTestAddress,
      );
      expect(batch.fields.whereType<NestedCallField>(), hasLength(16));
      // The batch moves value but is not itself a send, so the approval must not
      // borrow one of the sixteen amounts for its headline.
      expect(decoded.actionTitle, 'MULTISIG APPROVE');
    });

    testWidgets('all sixteen batched transfers reach the screen', (tester) async {
      final approval = catalogue.firstWhere((c) => c.label == 'approve [batch_all of 16 transfers]');
      await pumpAt(tester, DebugPayloads.payloadForCall(approval.call), surfaces.first.size, surfaces.first.scale);

      expect(tester.takeException(), isNull);
      for (var i = 1; i <= 16; i++) {
        await tester.scrollUntilVisible(find.text('CALL $i'), 200);
        expect(find.text('CALL $i'), findsOneWidget, reason: 'batched transfer $i never reached the screen');
      }
    });
  });

  group('the shapes the signer refuses fail closed', () {
    for (final call in DebugPayloads.refused) {
      testWidgets(nameOf(call), (tester) async {
        expect(
          () => CallDecoder.decodeBytes(call.call, policy: const FullCallPolicy()),
          throwsA(isA<FormatException>()),
          reason: '${nameOf(call)} decoded, but the catalogue lists it as refused',
        );

        await pumpAt(tester, DebugPayloads.payloadForCall(call.call), surfaces.first.size, surfaces.first.scale);

        expect(tester.takeException(), isNull);
        expect(find.text('Could not read transaction'), findsOneWidget);
        expect(find.text('Sign'), findsNothing, reason: '${nameOf(call)} offered a Sign button');
      });
    }
  });
}
