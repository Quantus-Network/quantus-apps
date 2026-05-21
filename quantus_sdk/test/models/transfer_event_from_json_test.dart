import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/src/models/transaction_event.dart';

void main() {
  group('TransferEvent.fromJson', () {
    test('parses nested maps from typical REST JSON', () {
      final json = <String, dynamic>{
        'amount': '1000000000',
        'sender': <String, dynamic>{'id': 'qzjij4Tiow9jtse9d7L1T3NEZuxgFW8JdUbaTLsfgubF7ZQAC'},
        'id': '0000197242-9c90c-000002',
        'receiver': <String, dynamic>{'id': 'qzpyxSr48YN9EQe2ito734iCReTXjnungmNCSY4Yph1YznEda'},
        'block': <String, dynamic>{
          'hash': '0x9c90cf5b0d7348e49c7ed427b42f5cc7cfe37e11bd7f4e3254c7fc4c7acbbf62',
          'height': 197242,
        },
        'extrinsic': <String, dynamic>{'id': '0x60db7af926aa917d0e15c02fa4ddf54ed759ae564b380b8e73b63570000924e7'},
        'fee': '8189972000',
        'timestamp': '2026-05-12T12:39:51.706Z',
      };

      final event = TransferEvent.fromJson(json);

      expect(event.blockNumber, 197242);
      expect(event.amount, BigInt.parse('1000000000'));
    });

    test('parses FCM-style string-encoded nested objects and int amounts', () {
      final json = <String, dynamic>{
        'amount': 1000000000,
        'fee': 8189972000,
        'sender': '{"id":"qzjij4Tiow9jtse9d7L1T3NEZuxgFW8JdUbaTLsfgubF7ZQAC"}',
        'id': '0000197378-4f5d2-000002',
        'receiver': '{"id":"qzpyxSr48YN9EQe2ito734iCReTXjnungmNCSY4Yph1YznEda"}',
        'block': '{"hash":"0x4f5d27e7b1c679e64292606c9560432f610f7a6fccab992f5ab6326f5171f90c","height":197378}',
        'extrinsicHash': '0xc399a24c2cd9b3a85f2b10cdb6a0bb98ff8f02eb8185c23959f9b7e7d943a9b7',
        'timestamp': '2026-05-12T13:08:21.846Z',
      };

      final event = TransferEvent.fromJson(json);

      expect(event.blockNumber, 197378);
      expect(event.extrinsicHash, '0xc399a24c2cd9b3a85f2b10cdb6a0bb98ff8f02eb8185c23959f9b7e7d943a9b7');
      expect(event.amount, BigInt.from(1000000000));
      expect(event.fee, BigInt.from(8189972000));
    });
  });
}
