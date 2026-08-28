import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:polkadart/scale_codec.dart';
import 'package:quantus_sdk/generated/planck/types/sp_runtime/multiaddress/multi_address.dart' as multi_address;

import 'package:quantus_sdk/src/chain/call_decoder.dart';
import 'package:quantus_sdk/src/chain/call_policy.dart';
import 'package:quantus_sdk/src/testing/call_corpus.dart';
import 'package:convert/convert.dart';

void main() {
  group('MultiAddress::Index is zero-width', () {
    test('decodes from the variant byte alone, consuming nothing more', () {
      final input = Input.fromBytes(Uint8List.fromList([1]));
      final decoded = multi_address.MultiAddress.codec.decode(input);

      expect(decoded, isA<multi_address.Index>());
      expect(input.remainingLength, 0, reason: 'Index must not consume a compact integer');
    });

    test('encodes to the variant byte alone', () {
      expect(const multi_address.Index(null).encode(), [1]);
    });

    // The corpus encodes each call from the metadata's own type tree, while the
    // decoder reads it with the generated codecs. A codec that disagrees with
    // the metadata about a field's width re-frames everything after it, so an
    // exact-fit decode of every entry is what pins the two readings together.
    test('a call carrying an Index address decodes to the call the corpus wrote', () {
      final entry = refusedCallCorpus.entries.firstWhere((e) => e.key.contains('[dest=Index]'));
      final bytes = hex.decode(entry.value);

      // Two index bytes, the Option/variant byte, and the value - no compact.
      expect(bytes.length, lessThan(16), reason: 'Index must not carry a compact integer');
      expect(
        () => CallDecoder.decodeBytes(bytes, policy: const FullCallPolicy()),
        throwsA(isA<FormatException>()),
        reason: 'the address form is refused, but only after the bytes framed correctly',
      );
    });

    test('leaves the bytes after it to the next call, not to itself', () {
      final input = Input.fromBytes(Uint8List.fromList([1, 0, 0, 0]));
      multi_address.MultiAddress.codec.decode(input);

      expect(input.remainingLength, 3);
    });
  });
}
