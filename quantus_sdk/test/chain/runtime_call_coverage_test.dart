import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/src/chain/call_decoder.dart';
import 'package:quantus_sdk/src/chain/call_policy.dart';
import 'package:quantus_sdk/src/chain/decoded_call.dart';
import 'package:quantus_sdk/src/constants/app_constants.dart';
import 'package:quantus_sdk/src/testing/call_corpus.dart';
import 'package:ss58/ss58.dart';

Uint8List bytesOf(String h) => Uint8List.fromList(hex.decode(h));

Iterable<CallField> everyField(DecodedCall call) sync* {
  for (final field in call.fields) {
    yield field;
    if (field is FieldGroup) yield* _group(field);
    if (field is NestedCallField) yield* everyField(field.call);
  }
}

Iterable<CallField> _group(FieldGroup group) sync* {
  for (final item in group.items) {
    yield item;
    if (item is FieldGroup) yield* _group(item);
    if (item is NestedCallField) yield* everyField(item.call);
  }
}

Iterable<DecodedCall> everyCall(DecodedCall call) sync* {
  yield call;
  for (final field in everyField(call)) {
    if (field is NestedCallField) yield* everyCall(field.call);
  }
}

void main() {
  test('the corpus covers the runtime this build decodes', () {
    expect(callCorpus, isNotEmpty);
    expect(callCorpus.length, greaterThan(60));
    expect(
      callCorpus.keys.map((k) => k.split('.').first).toSet(),
      containsAll(<String>{'System', 'Balances', 'Multisig', 'Utility', 'ReversibleTransfers', 'Vesting'}),
      reason: 'regenerate the corpus after changing the bindings',
    );
    expect(
      callCorpus.keys.where((k) => k.startsWith('Assets.')),
      isEmpty,
      reason: 'the runtime no longer declares an assets pallet',
    );
  });

  group('every call the runtime declares', () {
    for (final entry in callCorpus.entries) {
      final expected = entry.key.split(' ').first;

      test('${entry.key} decodes and describes itself', () {
        final decoded = CallDecoder.decodeBytes(bytesOf(entry.value), policy: const FullCallPolicy());

        expect(
          '${decoded.pallet}.${decoded.call}',
          expected,
          reason: 'the decoder must name a call the way the runtime does',
        );

        for (final call in everyCall(decoded)) {
          expect(call.actionTitle.trim(), isNotEmpty);
          expect(call.displayTitle.trim(), isNotEmpty);
        }

        for (final field in everyField(decoded)) {
          expect(field.label.trim(), isNotEmpty, reason: '${entry.key}: a field reached the screen with no label');

          if (field is ValueField) {
            expect(
              field.value,
              isNot(anyOf(contains("Instance of '"), contains('MapEntry('), matches(RegExp(r'^\{.*\}$')))),
              reason: '${entry.key}: "${field.label}" renders a Dart object rather than a value',
            );
            expect(field.value.trim(), isNotEmpty, reason: '${entry.key}: "${field.label}" renders empty');

            if (field.kind == ValueKind.address) {
              expect(
                Address.decode(field.value).prefix,
                AppConstants.ss58prefix,
                reason: '${entry.key}: "${field.label}" is not an address of this network',
              );
            }
            if (field.kind == ValueKind.hash) {
              expect(field.value, matches(RegExp(r'^0x[0-9a-f]{64}')));
            }
          }
        }
      });
    }
  });

  group('an address form this runtime cannot resolve', () {
    for (final entry in refusedCallCorpus.entries) {
      test('${entry.key} is never presented as an address', () {
        final DecodedCall decoded;
        try {
          decoded = CallDecoder.decodeBytes(bytesOf(entry.value), policy: const FullCallPolicy());
        } on FormatException {
          return;
        }

        // A call with a describer refuses outright; one that falls through to
        // the generic walk shows the raw shape, which claims nothing.
        expect(
          everyField(decoded).whereType<ValueField>().where((f) => f.kind == ValueKind.address),
          isEmpty,
          reason: '${entry.key}: an unresolvable address form was rendered as an address',
        );
      });
    }
  });

  test('the bundled codecs reject indices the runtime does not declare', () {
    final declared = {
      for (final h in [...callCorpus.values, ...refusedCallCorpus.values]) (bytesOf(h)[0], bytesOf(h)[1]),
    };
    final padding = List.filled(256, 0);
    var checked = 0;

    for (var pallet = 0; pallet < 256; pallet++) {
      for (var call = 0; call < 256; call++) {
        if (declared.contains((pallet, call))) continue;
        checked++;
        expect(
          () => CallDecoder.decodeBytes([pallet, call, ...padding], policy: const FullCallPolicy()),
          throwsA(anything),
          reason: 'pallet $pallet call $call decodes, but the runtime does not declare it',
        );
      }
    }
    expect(checked, greaterThan(60000));
  });
}
