import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

QuantusSigningPayload _payload({int eraPeriod = 64, int blockNumber = 42}) => QuantusSigningPayload(
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
  test('maxAge leaves the full round-trip reserve of era lifetime unused', () {
    final expectedSeconds = (64 - ColdSignEra.reserveBlocks) * AppConstants.avgBlockTimeSeconds;
    expect(ColdSignEra.maxAge(_payload()), Duration(seconds: expectedSeconds));
  });

  test('the live era period keeps a positive usable window', () {
    expect(AppConstants.txMortalEraPeriodBlocks, greaterThan(ColdSignEra.reserveBlocks));
  });

  test('an era no longer than the reserve is refused', () {
    expect(() => ColdSignEra.maxAge(_payload(eraPeriod: ColdSignEra.reserveBlocks)), throwsStateError);
  });

  test('immortal payloads stay usable for a day', () {
    expect(ColdSignEra.maxAge(_payload(eraPeriod: 0)), const Duration(days: 1));
  });

  test('isStale flips exactly at maxAge', () {
    final payload = _payload();
    final createdAt = DateTime(2026, 1, 1, 12);
    final maxAge = ColdSignEra.maxAge(payload);
    expect(ColdSignEra.isStale(payload, createdAt, createdAt.add(maxAge - const Duration(seconds: 1))), isFalse);
    expect(ColdSignEra.isStale(payload, createdAt, createdAt.add(maxAge)), isTrue);
  });

  test('ensureNotExpired refuses the submit margin before expiry', () {
    final payload = _payload(eraPeriod: 16, blockNumber: 100);
    expect(ColdSignEra.expiryBlock(payload), 116);
    ColdSignEra.ensureNotExpired(payload, 113);
    expect(
      () => ColdSignEra.ensureNotExpired(payload, 114),
      throwsA(
        isA<ColdSignEraExpiredException>()
            .having((e) => e.currentBlock, 'currentBlock', 114)
            .having((e) => e.expiryBlock, 'expiryBlock', 116),
      ),
    );
  });

  test('immortal payloads never expire', () {
    ColdSignEra.ensureNotExpired(_payload(eraPeriod: 0), 1 << 40);
  });
}
