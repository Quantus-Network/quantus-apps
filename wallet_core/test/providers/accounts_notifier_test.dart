import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/wallet_providers.dart';

const _main = Account(walletIndex: 0, index: 0, name: 'Main', accountId: 'qzMain');
const _savings = Account(walletIndex: 0, index: 1, name: 'Savings', accountId: 'qzSavings');

/// Stored accounts on a slow disk: each read waits until the test answers it.
class _SlowAccountsService extends Fake implements AccountsService {
  final reads = <Completer<List<Account>>>[];

  @override
  Future<List<Account>> getAccounts() {
    final read = Completer<List<Account>>();
    reads.add(read);
    return read.future;
  }
}

void main() {
  test('a list replaced while it loads drops what its read answers, and the new one loads', () async {
    final service = _SlowAccountsService();
    final container = ProviderContainer(overrides: [accountsServiceProvider.overrideWithValue(service)]);
    addTearDown(container.dispose);
    container.listen(accountsProvider, (_, _) {});
    expect(service.reads, hasLength(1));

    container.invalidate(accountsProvider);
    expect(container.read(accountsProvider).isLoading, isTrue);
    expect(service.reads, hasLength(2));

    service.reads[0].complete(const [_main]);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(accountsProvider).isLoading, isTrue, reason: 'the replaced list answers no one');

    service.reads[1].complete(const [_main, _savings]);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(accountsProvider).value, const [_main, _savings]);
  });

  test('a list replaced while it loads drops a read that fails, too', () async {
    final service = _SlowAccountsService();
    final container = ProviderContainer(overrides: [accountsServiceProvider.overrideWithValue(service)]);
    addTearDown(container.dispose);
    container.listen(accountsProvider, (_, _) {});

    container.invalidate(accountsProvider);
    expect(container.read(accountsProvider).isLoading, isTrue);

    service.reads[0].completeError(StateError('the disk is gone'));
    await Future<void>.delayed(Duration.zero);

    expect(container.read(accountsProvider).isLoading, isTrue);
  });
}
