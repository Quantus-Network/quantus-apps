import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  group('QuantusPayloadParser', () {
    test('parses balance transfer', () {
      // Create a mock balance transfer payload
      // Pallet index 2 (Balances), call index 0 (transfer_allow_death)
      final payload = Uint8List.fromList([
        2, // pallet index
        0, // call index
        0, // MultiAddress::Id
        ...List.filled(32, 1), // mock account ID (32 bytes)
        0x0b, 0x00, 0xa0, 0x72, 0x4e, 0x18, 0x09, // Compact encoded amount (10000000000000)
      ]);

      final result = QuantusPayloadParser.parsePayload(payload);

      expect(result, isNotNull);
      expect(result!.toAddress, startsWith('qz'));
      expect(result.amount, BigInt.from(10000000000000));
      expect(result.isReversible, false);
    });

    test('parses real world balance transfer (0.9 QUAN)', () {
      // Test with real world value as follows
      // final hexPayload = '020000ef5f320156894f0fde742921c6990bf446e82c89fae5a23e701900abcd92dfb40700282e8cd185012800007400000002000000826beefbe2be72645ff376f18de745ac196dc77637436090de4174180706118e3d3e081c6e3599f8ae31d404d9f087f50c25b4e08c35712e23470a60da5799ca00';
      // final expectedAmount = (BigInt): 900000000000
      // final expectedTargetAddress = 'qzps6MnSixszZAWiwcpjtw6uXBjWg2aEyrXBdp9thijzY1g86';

      // Real world hex payload from production
      final hexPayload =
          '020000ef5f320156894f0fde742921c6990bf446e82c89fae5a23e701900abcd92dfb40700282e8cd185012800007400000002000000826beefbe2be72645ff376f18de745ac196dc77637436090de4174180706118e3d3e081c6e3599f8ae31d404d9f087f50c25b4e08c35712e23470a60da5799ca00';
      final expectedTargetAddress = 'qzps6MnSixszZAWiwcpjtw6uXBjWg2aEyrXBdp9thijzY1g86';
      final expectedAmount = BigInt.from(900000000000);
      final payload = Uint8List.fromList(hex.decode(hexPayload));

      final result = QuantusPayloadParser.parsePayload(payload);

      expect(result, isNotNull);
      expect(result!.amount, expectedAmount);
      expect(result.isReversible, false);
      expect(result.reversibleTimeframe, null);
      expect(result.toAddress, expectedTargetAddress);
    });

    // flutter: Showing confirmation for amount (BigInt): 1440000000000
    // Reverisble transfer to qzn5St24cMsjE4JKYdXLBctusWj5zom67dnrW22SweAahLGeG
    // delay 5 minutes = 300 seconds.
    // flutter: KAT raw encoded payload: 0d04007416854906f03a9dff66e3270a736c44e15970ac03a638471523a03069f276ca0040b0464f010000000000000000000001e093040000000000d5010c00007400000002000000826beefbe2be72645ff376f18de745ac196dc77637436090de4174180706118efeebb9b31159a679a1e49ccc34d363b5d4a00b836ad4f85cbba8c6274ac2566800
    test('Real world reversible transfer (1.44 QUAN, delay 5 minutes)', () {
      final hexPayload =
          '0d04007416854906f03a9dff66e3270a736c44e15970ac03a638471523a03069f276ca0040b0464f010000000000000000000001e093040000000000d5010c00007400000002000000826beefbe2be72645ff376f18de745ac196dc77637436090de4174180706118efeebb9b31159a679a1e49ccc34d363b5d4a00b836ad4f85cbba8c6274ac2566800';
      final expectedTargetAddress = 'qzn5St24cMsjE4JKYdXLBctusWj5zom67dnrW22SweAahLGeG';
      final expectedAmount = BigInt.from(1440000000000);
      final expectedReversibleTimeframe = 5 * 60 * 1000; // 5 minutes in millisecond
      final payload = Uint8List.fromList(hex.decode(hexPayload));

      final result = QuantusPayloadParser.parsePayload(payload);

      expect(result, isNotNull);
      expect(result!.amount, expectedAmount);
      expect(result.isReversible, true);
      expect(result.reversibleTimeframe, expectedReversibleTimeframe);
      expect(result.toAddress, expectedTargetAddress);
    });

    test('parses reversible transfer', () {
      // Create a mock reversible transfer payload
      // Pallet index 13 (ReversibleTransfers), call index 3 (schedule_transfer)
      final payload = Uint8List.fromList([
        13, // pallet index
        3, // call index
        0, // MultiAddress::Id
        ...List.filled(32, 2), // mock account ID (32 bytes)
        0x00,
        0xa0,
        0x72,
        0x4e,
        0x18,
        0x09,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00, // amount (16 bytes, little endian) - 10000000000000 as u128
      ]);

      final result = QuantusPayloadParser.parsePayload(payload);

      expect(result, isNotNull);
      expect(result!.toAddress, startsWith('qz'));
      expect(result.amount, BigInt.from(10000000000000));
      expect(result.isReversible, true);
      expect(result.reversibleTimeframe, null); // Uses configured delay
    });

    test('parses reversible transfer with custom delay', () {
      // Create a mock reversible transfer with delay payload
      // Pallet index 13 (ReversibleTransfers), call index 4 (schedule_transfer_with_delay)
      final payload = Uint8List.fromList([
        13, // pallet index
        4, // call index
        0, // MultiAddress::Id
        ...List.filled(32, 3), // mock account ID (32 bytes)
        0x00,
        0xa0,
        0x72,
        0x4e,
        0x18,
        0x09,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00, // amount (16 bytes, little endian) - 10000000000000 as u128
        0, // BlockNumber variant
        100, 0, 0, 0, // delay: 100 blocks
      ]);

      final result = QuantusPayloadParser.parsePayload(payload);

      expect(result, isNotNull);
      expect(result!.toAddress, startsWith('qz'));
      expect(result.amount, BigInt.from(10000000000000));
      expect(result.isReversible, true);
      expect(result.reversibleTimeframe, 100);
    });

    test('returns null for unknown pallet', () {
      final payload = Uint8List.fromList([99, 0]); // Unknown pallet index 99
      final result = QuantusPayloadParser.parsePayload(payload);
      expect(result, null);
    });

    test('TransactionInfo toString formats correctly', () {
      final tx = TransactionInfo(
        toAddress: '0x01010101010101010101010101010101010101010101010101010101010101',
        amount: BigInt.from(10000000000000), // 1000 QUS with 10 decimals
        isReversible: true,
        reversibleTimeframe: 7200,
      );

      final output = tx.toString();
      expect(output, contains('To Address: 0x01010101010101010101010101010101010101010101010101010101010101'));
      expect(output, contains('Amount: 1000.0000 QUS'));
      expect(output, contains('Reversible: true'));
      expect(output, contains('Reversible Timeframe: 7200 blocks'));
    });
  });
}
