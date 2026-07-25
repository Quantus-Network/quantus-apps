import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  // The 0.1 QUAN keystone transfer call with a Planck extension suffix (era 5501 =
  // period 64 phase 21, nonce 0, tip 0, spec 131, tx version 2, metadata None), so the
  // cold wallet is verified against the exact byte layout the hot wallet produces.
  const planckHex =
      '0200007416854906f03a9dff66e3270a736c44e15970ac03a638471523a03069f276ca0700e876481755010000008300000002000000'
      '4901bf5c57fd3f9e726af399c763de6670dbdb115a91c0237e173f16eef65e72'
      '111111111111111111111111111111111111111111111111111111111111111100';

  // The same transfer as originally captured on the retired devnet (genesis 826beefb…).
  // Regression: the signer must reject payloads for networks it does not know.
  const retiredDevnetHex =
      '0200007416854906f03a9dff66e3270a736c44e15970ac03a638471523a03069f276ca0700e876481755010000007400000002000000826beefbe2be72645ff376f18de745ac196dc77637436090de4174180706118e5a77ae1c95817ee664cf733fafa7baa8e6244b396a54e57a5bc414b24c52800600';

  group('QuantusSigningPayload.signablePayload (shared hot/cold signing rule)', () {
    test('keystone transfer payload is signed raw (<= 256 bytes)', () {
      final payload = Uint8List.fromList(hex.decode(planckHex));
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
      final payload = Uint8List.fromList(hex.decode(planckHex));
      final parsed = QuantusPayloadParser.parsePayload(payload);

      expect(parsed.call.isReversible, isFalse);
      expect(parsed.call.reversibleTimeframe, isNull);
      expect(parsed.call.toAddress, startsWith('qz'));
      expect(parsed.call.amount, BigInt.parse('100000000000')); // 0.1 QUAN at 12 decimals
      expect(parsed.network, 'Planck');
      expect(parsed.extensions.era.toString(), '64 blocks');
      expect(parsed.extensions.nonce, 0);
      expect(parsed.extensions.tip, BigInt.zero);
    });

    test('retired devnet payload is rejected with unknown genesis (never signed)', () {
      final payload = Uint8List.fromList(hex.decode(retiredDevnetHex));
      expect(
        () => QuantusPayloadParser.parsePayload(payload),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('Unknown genesis hash'))),
      );
    });

    test('non-transaction bytes are rejected (never signed)', () {
      final garbage = Uint8List.fromList(List<int>.generate(40, (i) => 0xff - i));
      expect(() => QuantusPayloadParser.parsePayload(garbage), throwsFormatException);
    });
  });
}
