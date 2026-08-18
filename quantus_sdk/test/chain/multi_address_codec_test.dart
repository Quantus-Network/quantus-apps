import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:polkadart/scale_codec.dart';
import 'package:quantus_sdk/generated/planck/types/sp_runtime/multiaddress/multi_address.dart' as multi_address;

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

    test('leaves the bytes after it to the next call, not to itself', () {
      final input = Input.fromBytes(Uint8List.fromList([1, 0, 0, 0]));
      multi_address.MultiAddress.codec.decode(input);

      expect(input.remainingLength, 3);
    });
  });
}
