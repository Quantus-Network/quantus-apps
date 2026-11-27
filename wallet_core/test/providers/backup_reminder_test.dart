import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/wallet_providers.dart';

import '../fakes.dart';

/// 0.0001 QTC, the balance at or below which no reminder is shown.
final _threshold = BigInt.from(10).pow(AppConstants.decimals - 4);

void main() {
  /// The reminder's wallet index with [active] as the active account, holding
  /// [balance], in a wallet of [origin] whose phrase has [viewed] or not.
  Future<int?> reminderFor(
    DisplayAccount active, {
    BigInt? balance,
    WalletOrigin? origin = WalletOrigin.created,
    bool viewed = false,
  }) async {
    final settings = FakeSettingsService()..activeAccount = active;
    final container = ProviderContainer(
      overrides: [
        settingsServiceProvider.overrideWithValue(settings),
        walletOriginProvider.overrideWith((ref, walletIndex) => origin),
        recoveryPhraseViewedProvider.overrideWith((ref, walletIndex) => viewed),
        balanceProvider.overrideWithValue(AsyncValue.data(balance ?? _threshold + BigInt.one)),
      ],
    );
    addTearDown(container.dispose);
    container.listen(backupReminderWalletIndexProvider, (_, _) {});
    await pumpEventQueue();
    return container.read(backupReminderWalletIndexProvider);
  }

  final account = Account(walletIndex: 2, index: 0, name: 'Account 1', accountId: 'qzaccount${'x' * 40}');

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

  test('no reminder at or below 0.0001 QTC', () async {
    expect(await reminderFor(RegularAccount(account), balance: _threshold), isNull);
  });

  test('no reminder on a cold wallet, Encrypted or multisig account', () async {
    for (final type in [AccountType.keystone, AccountType.encrypted]) {
      final other = Account(
        walletIndex: 2,
        index: 0,
        name: 'Account 1',
        accountId: 'qzaccount${'x' * 40}',
        accountType: type,
      );
      expect(await reminderFor(RegularAccount(other)), isNull, reason: '$type');
    }
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
