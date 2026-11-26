import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/keystone_sign_cache.dart';

/// A payload built at [blockNumber] that the chain accepts for [eraPeriod]
/// blocks; 0 never expires.
QuantusSigningPayload _payload({int blockNumber = 100, int eraPeriod = 64}) => QuantusSigningPayload(
  method: Uint8List(0),
  specVersion: 1,
  transactionVersion: 1,
  genesisHash: '0x00',
  blockHash: '0x00',
  blockNumber: blockNumber,
  eraPeriod: eraPeriod,
  nonce: 0,
  tip: 0,
);

void main() {
  group('ensureKeystoneEraNotExpired', () {
    test('passes a payload that never expires without asking for the current block', () async {
      var asked = 0;

      await ensureKeystoneEraNotExpired(
        _payload(eraPeriod: 0),
        currentBlock: () async {
          asked++;
          return 1 << 30;
        },
      );

      expect(asked, 0);
    });

    test('passes while more than the margin of the era is left', () async {
      // The era ends at block 164; the margin is 2 blocks.
      await ensureKeystoneEraNotExpired(
        _payload(),
        currentBlock: () async => 164 - keystoneSignSubmitEraMarginBlocks - 1,
      );
    });

    test('refuses at the margin before the era ends, naming both blocks', () async {
      final atMargin = 164 - keystoneSignSubmitEraMarginBlocks;

      await expectLater(
        ensureKeystoneEraNotExpired(_payload(), currentBlock: () async => atMargin),
        throwsA(
          isA<KeystoneEraExpiredException>()
              .having((e) => e.currentBlock, 'currentBlock', atMargin)
              .having((e) => e.expiryBlock, 'expiryBlock', 164),
        ),
      );
    });

    test('refuses once the era has ended', () async {
      await expectLater(
        ensureKeystoneEraNotExpired(_payload(), currentBlock: () async => 200),
        throwsA(isA<KeystoneEraExpiredException>()),
      );
    });
  });

  group('isKeystonePayloadStale', () {
    final storedAt = DateTime.utc(2026, 11, 24, 10);
    final payload = _payload();
    final maxAge = keystoneSignCacheMaxAge(payload);

    test('is not stale before the payload reaches its maximum age', () {
      expect(
        isKeystonePayloadStale(payload, storedAt: storedAt, now: storedAt.add(maxAge - const Duration(seconds: 1))),
        isFalse,
      );
    });

    test('is stale once the payload reaches its maximum age', () {
      expect(isKeystonePayloadStale(payload, storedAt: storedAt, now: storedAt.add(maxAge)), isTrue);
    });
  });
}
