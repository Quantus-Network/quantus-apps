import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/wallet_providers.dart';

import '../fakes.dart';

/// 0.0001 QTC, the balance at or below which no reminder is shown.
final _threshold = BigInt.from(10).pow(AppConstants.decimals - 4);

void main() {
  /// The reminder's wallet index with [active] as the active account, among
  /// [accounts] (just [active]'s own when not given), each holding its entry
  /// in [balances] (an Encrypted account by its wallet index in
  /// [encryptedBalances]), in a wallet of [origin] whose phrase has [viewed]
  /// or not.
  Future<int?> reminderFor(
    DisplayAccount active, {
    List<Account>? accounts,
    Map<String, BigInt>? balances,
    Map<int, BigInt> encryptedBalances = const {},
    WalletOrigin? origin = WalletOrigin.created,
    bool viewed = false,
  }) async {
    final settings = FakeSettingsService()..activeAccount = active;
    settings.accounts.addAll(accounts ?? [if (active is RegularAccount) active.account]);
    final funded = balances ?? {active.account.accountId: _threshold + BigInt.one};
    final container = ProviderContainer(
      overrides: [
        settingsServiceProvider.overrideWithValue(settings),
        accountsServiceProvider.overrideWithValue(FakeAccountsService(settings)),
        walletOriginProvider.overrideWith((ref, walletIndex) => origin),
        recoveryPhraseViewedProvider.overrideWith((ref, walletIndex) => viewed),
        balanceProviderFamily.overrideWith((ref, accountId) async => funded[accountId] ?? BigInt.zero),
        encryptedBalanceProvider.overrideWith(
          (ref, walletIndex) => AsyncValue.data(encryptedBalances[walletIndex] ?? BigInt.zero),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(backupReminderWalletIndexProvider, (_, _) {});
    await pumpEventQueue();
    return container.read(backupReminderWalletIndexProvider);
  }

  final account = Account(walletIndex: 2, index: 0, name: 'Account 1', accountId: 'qzaccount${'x' * 40}');
  final savings = Account(walletIndex: 2, index: 1, name: 'Savings', accountId: 'qzsavings${'x' * 40}');
  final encrypted = Account(
    walletIndex: 2,
    index: AppConstants.encryptedAccountIndex,
    name: 'Encrypted Account',
    accountId: 'qzencrypted${'x' * 38}',
    accountType: AccountType.encrypted,
  );

  test('a created wallet whose phrase was never seen, holding more than 0.0001 QTC, gets the reminder', () async {
    expect(await reminderFor(RegularAccount(account)), 2);
  });

  test('a legacy wallet of unknown origin gets the reminder too', () async {
    expect(await reminderFor(RegularAccount(account), origin: null), 2);
  });

  test('no reminder once the phrase has been seen', () async {
    expect(await reminderFor(RegularAccount(account), viewed: true), isNull);
  });

  test('no reminder for an imported wallet', () async {
    expect(await reminderFor(RegularAccount(account), origin: WalletOrigin.imported), isNull);
  });

  test('no reminder while the wallet\'s accounts together hold 0.0001 QTC or less', () async {
    final half = _threshold ~/ BigInt.two;
    expect(
      await reminderFor(
        RegularAccount(account),
        accounts: [account, savings, encrypted],
        balances: {account.accountId: half, savings.accountId: half},
      ),
      isNull,
    );
  });

  test('an empty account gets the reminder when another account of its wallet holds the money', () async {
    expect(
      await reminderFor(
        RegularAccount(account),
        accounts: [account, savings],
        balances: {savings.accountId: _threshold + BigInt.one},
      ),
      2,
    );
  });

  test('the money in the wallet\'s Encrypted account counts', () async {
    expect(
      await reminderFor(
        RegularAccount(account),
        accounts: [account, encrypted],
        balances: {},
        encryptedBalances: {2: _threshold + BigInt.one},
      ),
      2,
    );
  });

  test('the wallet\'s Encrypted account gets the reminder too', () async {
    expect(
      await reminderFor(
        RegularAccount(encrypted),
        accounts: [account, encrypted],
        balances: {account.accountId: _threshold + BigInt.one},
      ),
      2,
    );
  });

  test('the money in another wallet does not count', () async {
    final elsewhere = Account(walletIndex: 3, index: 0, name: 'Account 1', accountId: 'qzelsewhere${'x' * 38}');
    expect(
      await reminderFor(
        RegularAccount(account),
        accounts: [account, elsewhere],
        balances: {elsewhere.accountId: _threshold + BigInt.one},
      ),
      isNull,
    );
  });

  test('no reminder on a cold wallet or multisig account', () async {
    final cold = Account(
      walletIndex: 2,
      index: 0,
      name: 'Account 1',
      accountId: 'qzaccount${'x' * 40}',
      accountType: AccountType.keystone,
    );
    expect(await reminderFor(RegularAccount(cold)), isNull);
    final multisig = MultisigAccount(
      name: 'Team',
      accountId: 'qzteam${'x' * 40}',
      signers: [account.accountId],
      threshold: 1,
      nonce: BigInt.zero,
      myMemberAccountId: account.accountId,
    );
    expect(await reminderFor(MultisigDisplayAccount(multisig)), isNull);
  });
}
