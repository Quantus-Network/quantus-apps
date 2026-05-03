import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/services/referral_service.dart';
import 'package:resonance_network_wallet/services/wallet_creation_service.dart';

@GenerateNiceMocks([MockSpec<SettingsService>(), MockSpec<AccountsService>(), MockSpec<ReferralService>()])
import 'wallet_creation_service_test.mocks.dart';

void main() {
  group('WalletCreationService.createNewWallet', () {
    test('persists mnemonic, adds root account, and submits referral when no root exists', () async {
      final settings = MockSettingsService();
      final accounts = MockAccountsService();
      final referral = MockReferralService();

      final service = WalletCreationService(
        settingsService: settings,
        accountsService: accounts,
        referralService: referral,
      );

      const mnemonic = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
      const accountId = 'abc';
      const name = 'Account 1';

      final created = await service.createNewWallet(
        name: name,
        mnemonic: mnemonic,
        walletIndex: 0,
        accountId: accountId,
        existingAccounts: const [],
      );

      verify(settings.setMnemonic(mnemonic, 0)).called(1);
      verify(accounts.addAccount(argThat(isA<Account>().having((a) => a.accountId, 'accountId', 'abc')))).called(1);
      verify(referral.submitAddressToBackend()).called(1);

      expect(created.accountId, accountId);
      expect(created.name, name);
    });

    test('skips add and referral when root account already exists', () async {
      final settings = MockSettingsService();
      final accounts = MockAccountsService();
      final referral = MockReferralService();

      final service = WalletCreationService(
        settingsService: settings,
        accountsService: accounts,
        referralService: referral,
      );

      const existing = Account(walletIndex: 0, index: 0, name: 'Existing', accountId: 'existing_addr');

      final created = await service.createNewWallet(
        name: 'Account 1',
        mnemonic: 'word ' * 12,
        walletIndex: 0,
        accountId: 'new_derived_addr',
        existingAccounts: const [existing],
      );

      verify(settings.setMnemonic('word ' * 12, 0)).called(1);
      verifyNever(accounts.addAccount(any));
      verifyNever(referral.submitAddressToBackend());
      expect(created, same(existing));
    });
  });
}
