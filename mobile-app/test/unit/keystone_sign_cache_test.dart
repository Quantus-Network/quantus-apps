import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/v2/screens/send/keystone_sign_cache.dart';

import '../fakes.dart';

/// Mortal era validity for Keystone payloads: the era minus the round-trip reserve.
Duration _mortalEraMaxCacheAge(QuantusSigningPayload payload) => keystoneSignCacheMaxAge(payload);

void main() {
  group('KeystoneSignCacheKey', () {
    test('trims recipient address in fromSendParams', () {
      final key = KeystoneSignCacheKey.fromSendParams(
        accountId: 'account-a',
        recipientAddress: '  recipient  ',
        amount: BigInt.from(100),
      );

      expect(key.recipientAddress, 'recipient');
    });

    test('equal keys match regardless of recipient whitespace', () {
      final keyA = KeystoneSignCacheKey.fromSendParams(
        accountId: 'account-a',
        recipientAddress: 'recipient',
        amount: BigInt.from(100),
      );
      final keyB = KeystoneSignCacheKey.fromSendParams(
        accountId: 'account-a',
        recipientAddress: ' recipient ',
        amount: BigInt.from(100),
      );

      expect(keyA, keyB);
    });

    test('forExtrinsic keys distinguish by identity', () {
      final approve = KeystoneSignCacheKey.forExtrinsic(accountId: 'account-a', identity: 'approve|msig|1');
      final execute = KeystoneSignCacheKey.forExtrinsic(accountId: 'account-a', identity: 'execute|msig|1');
      final approveAgain = KeystoneSignCacheKey.forExtrinsic(accountId: 'account-a', identity: 'approve|msig|1');

      expect(approve, approveAgain);
      expect(approve, isNot(execute));
    });
  });

  group('KeystoneSignCacheNotifier', () {
    late KeystoneSignCacheNotifier notifier;

    setUp(() {
      notifier = KeystoneSignCacheNotifier();
    });

    final key = KeystoneSignCacheKey(accountId: 'account-a', recipientAddress: 'recipient', amount: BigInt.from(100));

    final otherKey = KeystoneSignCacheKey(
      accountId: 'account-a',
      recipientAddress: 'other-recipient',
      amount: BigInt.from(100),
    );

    test('lookup returns null when cache is empty', () {
      expect(notifier.lookup(key), isNull);
    });

    test('store and lookup return entry for matching key', () {
      final unsigned = makeUnsignedTransactionData();
      const urParts = ['ur:part1', 'ur:part2'];

      notifier.store(key: key, unsignedData: unsigned, urParts: urParts);

      final entry = notifier.lookup(key);
      expect(entry, isNotNull);
      expect(entry!.key, key);
      expect(entry.unsignedData, unsigned);
      expect(entry.urParts, urParts);
    });

    test('lookup returns null for different key', () {
      notifier.store(key: key, unsignedData: makeUnsignedTransactionData(), urParts: const ['ur:part1']);

      expect(notifier.lookup(otherKey), isNull);
    });

    test('startNewSendSession invalidates prior entry until re-stored', () {
      notifier.store(key: key, unsignedData: makeUnsignedTransactionData(), urParts: const ['ur:part1']);
      expect(notifier.lookup(key), isNotNull);

      notifier.startNewSendSession();

      expect(notifier.lookup(key), isNull);
    });

    test('second startNewSendSession requires fresh store even when params unchanged', () {
      notifier.store(key: key, unsignedData: makeUnsignedTransactionData(), urParts: const ['ur:first']);
      notifier.startNewSendSession();

      final unsigned = makeUnsignedTransactionData();
      notifier.store(key: key, unsignedData: unsigned, urParts: const ['ur:second']);

      final entry = notifier.lookup(key);
      expect(entry, isNotNull);
      expect(entry!.urParts, const ['ur:second']);
    });
  });

  group('keystoneSignCacheMaxAge', () {
    test('leaves the full round-trip reserve of era lifetime unused', () {
      final payload = makeUnsignedTransactionData().payloadToSign;
      final expectedSeconds = (payload.eraPeriod - keystoneSignEraReserveBlocks) * AppConstants.avgBlockTimeSeconds;
      expect(keystoneSignCacheMaxAge(payload), Duration(seconds: expectedSeconds));
    });

    test('the live era period keeps a positive usable window', () {
      expect(AppConstants.txMortalEraPeriodBlocks, greaterThan(keystoneSignEraReserveBlocks));
    });
  });

  group('stale mortal era payload', () {
    late KeystoneSignCacheNotifier notifier;

    setUp(() {
      notifier = KeystoneSignCacheNotifier();
    });

    final key = KeystoneSignCacheKey(accountId: 'account-a', recipientAddress: 'recipient', amount: BigInt.from(100));

    test('lookup returns null when user returns after mortal era expires', () {
      final unsigned = makeUnsignedTransactionData();
      final storedAt = DateTime(2026, 1, 1, 12, 0, 0);
      final now = storedAt.add(_mortalEraMaxCacheAge(unsigned.payloadToSign));

      notifier.store(key: key, unsignedData: unsigned, urParts: const ['ur:stale'], storedAt: storedAt);

      expect(notifier.lookup(key, now: now), isNull);
    });

    test('lookup still returns entry within mortal era window', () {
      final unsigned = makeUnsignedTransactionData();
      final storedAt = DateTime(2026, 1, 1, 12, 0, 0);
      final now = storedAt.add(_mortalEraMaxCacheAge(unsigned.payloadToSign) - const Duration(seconds: 1));

      notifier.store(key: key, unsignedData: unsigned, urParts: const ['ur:fresh'], storedAt: storedAt);

      expect(notifier.lookup(key, now: now), isNotNull);
    });
  });
}
