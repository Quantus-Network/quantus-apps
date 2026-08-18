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
import 'package:quantus_cold_wallet/theme/app_theme.dart';

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
        addressesProvider.overrideWith((ref) => {signerAddress: ColdAccount(label: 'Account 1', index: 0)}),
        addressCheckphraseProvider.overrideWith((ref, address) async => 'check phrase'),
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

void main() {
  group('every call the runtime declares renders on the signing screen', () {
    for (final entry in callCorpus.entries) {
      testWidgets(entry.key, (tester) async {
        final payload = payloadFor(entry.value);

        for (final surface in surfaces) {
          await pumpAt(tester, payload, surface.size, surface.scale);

          expect(
            tester.takeException(),
            isNull,
            reason: '${entry.key} at ${surface.label}: the screen overflowed or threw',
          );

          final texts = renderedText(tester).toList();
          expect(texts, isNotEmpty, reason: '${entry.key} at ${surface.label}: nothing rendered');
          for (final text in texts) {
            expect(
              text,
              isNot(anyOf(contains("Instance of '"), contains('MapEntry('))),
              reason: '${entry.key} at ${surface.label}: a Dart object reached the screen',
            );
          }

          for (final paragraph in tester.renderObjectList<RenderParagraph>(find.byType(RichText))) {
            expect(
              paragraph.didExceedMaxLines,
              isFalse,
              reason: '${entry.key} at ${surface.label}: "${paragraph.text.toPlainText()}" was truncated',
            );
          }
        }
      });
    }
  });

  group('every field reaches the screen exactly once', () {
    for (final entry in callCorpus.entries) {
      test(entry.key, () {
        expectEveryFieldShownOnce(CallDecoder.decodeBytes(hex.decode(entry.value), policy: const FullCallPolicy()));
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
  });
}
