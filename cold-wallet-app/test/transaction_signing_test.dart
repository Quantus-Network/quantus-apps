import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  // Real SCALE-encoded signing payload (transfer of 0.1 QUAN) reused from the
  // quantus_sdk keystone test, so the cold wallet is verified against the exact
  // bytes the hot wallet produces.
  const keystoneHex =
      '0200007416854906f03a9dff66e3270a736c44e15970ac03a638471523a03069f276ca0700e876481755010000007400000002000000826beefbe2be72645ff376f18de745ac196dc77637436090de4174180706118e5a77ae1c95817ee664cf733fafa7baa8e6244b396a54e57a5bc414b24c52800600';

  group('QuantusSigningPayload.signablePayload (shared hot/cold signing rule)', () {
    test('keystone transfer payload is signed raw (<= 256 bytes)', () {
      final payload = Uint8List.fromList(hex.decode(keystoneHex));
      expect(payload.length, lessThanOrEqualTo(256));
      expect(QuantusSigningPayload.signablePayload(payload), equals(payload));
    });

    test('payload longer than 256 bytes is signed as a 32-byte Blake2b hash', () {
      final payload = Uint8List.fromList(List<int>.generate(300, (i) => i % 256));
      final signed = QuantusSigningPayload.signablePayload(payload);
      expect(payload.length, greaterThan(256));
      expect(signed.length, 32);
      expect(signed, isNot(equals(payload)));
    });
  });

  group('QuantusPayloadParser.parsePayload (scan -> display path)', () {
    test('keystone transfer payload decodes to a displayable transaction', () {
      final payload = Uint8List.fromList(hex.decode(keystoneHex));
      final info = QuantusPayloadParser.parsePayload(payload);

      expect(info, isNotNull);
      expect(info!.isReversible, isFalse);
      expect(info.reversibleTimeframe, isNull);
      expect(info.toAddress, startsWith('qz'));
      expect(info.amount, BigInt.parse('100000000000')); // 0.1 QUAN at 12 decimals
    });

    test('non-transaction bytes parse to null (rejected, never signed)', () {
      final garbage = Uint8List.fromList(List<int>.generate(40, (i) => 0xff - i));
      expect(QuantusPayloadParser.parsePayload(garbage), isNull);
    });
  });
}
