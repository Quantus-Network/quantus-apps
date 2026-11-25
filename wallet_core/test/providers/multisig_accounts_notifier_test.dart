import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
import 'package:wallet_core/providers/wallet_providers.dart';

final _team = MultisigAccount(
  name: 'Team',
  accountId: 'qzTeam',
  signers: const ['qzMain', 'qzOther'],
  threshold: 2,
  nonce: BigInt.zero,
  myMemberAccountId: 'qzMain',
);
final _board = MultisigAccount(
  name: 'Board',
  accountId: 'qzBoard',
  signers: const ['qzMain', 'qzOther', 'qzThird'],
  threshold: 3,
  nonce: BigInt.zero,
  myMemberAccountId: 'qzMain',
);

/// Stored multisigs on a slow disk: each read waits until the test answers it.
class _SlowSettingsService extends Fake implements SettingsService {
  final reads = <Completer<List<MultisigAccount>>>[];

  @override
  Future<List<MultisigAccount>> getMultisigAccounts() {
    final read = Completer<List<MultisigAccount>>();
    reads.add(read);
    return read.future;
  }
}

void main() {
  test('a multisig list replaced while it loads drops what its read answers, and the new one loads', () async {
    final service = _SlowSettingsService();
    final container = ProviderContainer(overrides: [settingsServiceProvider.overrideWithValue(service)]);
    addTearDown(container.dispose);
    container.listen(multisigAccountsProvider, (_, _) {});
    expect(service.reads, hasLength(1));

    container.invalidate(multisigAccountsProvider);
    expect(container.read(multisigAccountsProvider).isLoading, isTrue);
    expect(service.reads, hasLength(2));

    service.reads[0].complete([_team]);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(multisigAccountsProvider).isLoading, isTrue, reason: 'the replaced list answers no one');

    service.reads[1].complete([_team, _board]);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(multisigAccountsProvider).value, [_team, _board]);
  });

  test('a multisig list replaced while it loads drops a read that fails, too', () async {
    final service = _SlowSettingsService();
    final container = ProviderContainer(overrides: [settingsServiceProvider.overrideWithValue(service)]);
    addTearDown(container.dispose);
    container.listen(multisigAccountsProvider, (_, _) {});

    container.invalidate(multisigAccountsProvider);
    expect(container.read(multisigAccountsProvider).isLoading, isTrue);

    service.reads[0].completeError(StateError('the disk is gone'));
    await Future<void>.delayed(Duration.zero);

    expect(container.read(multisigAccountsProvider).isLoading, isTrue);
  });
}
