import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/quantus_sdk_riverpod.dart';
import 'package:quantus_sdk/testing.dart';

void main() {
  late ColdSignCacheNotifier notifier;
  final account = makeAccount(1, accountType: AccountType.keystone);
  final key = ColdSignRequestKey(accountId: account.accountId, recipientAddress: 'recipient', amount: BigInt.from(100));
  final otherKey = ColdSignRequestKey(
    accountId: account.accountId,
    recipientAddress: 'other',
    amount: BigInt.from(100),
  );

  ColdSignRequest request({List<String> urParts = const ['ur:part1'], DateTime? createdAt}) => ColdSignRequest(
    account: account,
    unsignedData: makeUnsignedTransactionData(),
    urParts: urParts,
    createdAt: createdAt ?? DateTime.now(),
    key: key,
  );

  setUp(() => notifier = ColdSignCacheNotifier());

  test('lookup returns null when the cache is empty', () {
    expect(notifier.lookup(key), isNull);
  });

  test('store and lookup return the request for a matching key only', () {
    final stored = request(urParts: const ['ur:part1', 'ur:part2']);
    notifier.store(stored);
    expect(notifier.lookup(key), same(stored));
    expect(notifier.lookup(otherKey), isNull);
  });

  test('a new session invalidates the request until re-stored', () {
    notifier.store(request());
    notifier.startNewSession();
    expect(notifier.lookup(key), isNull);

    final second = request(urParts: const ['ur:second']);
    notifier.store(second);
    expect(notifier.lookup(key)!.urParts, const ['ur:second']);
  });

  test('a stale request is dropped on lookup', () {
    final createdAt = DateTime(2026, 1, 1, 12);
    final stored = request(createdAt: createdAt);
    final maxAge = ColdSignEra.maxAge(stored.unsignedData.payloadToSign);
    notifier.store(stored);

    expect(notifier.lookup(key, now: createdAt.add(maxAge - const Duration(seconds: 1))), isNotNull);
    expect(notifier.lookup(key, now: createdAt.add(maxAge)), isNull);
    expect(notifier.lookup(key, now: createdAt), isNull);
  });
}
