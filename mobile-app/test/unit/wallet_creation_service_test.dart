import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/services/wallet_creation_service.dart';

@GenerateNiceMocks([MockSpec<SettingsService>(), MockSpec<AccountsService>()])
import 'wallet_creation_service_test.mocks.dart';

void main() {
  group('WalletCreationService.createNewWallet', () {
    test('persists mnemonic, adds root account, and submits referral when no root exists', () async {
      final settings = MockSettingsService();
      final accounts = MockAccountsService();

      final service = WalletCreationService(settingsService: settings, accountsService: accounts);

      const mnemonic = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
      const accountId = 'abc';
      const name = 'Account 1';

      final created = await service.createNewWallet(
        name: name,
        mnemonic: mnemonic,
        walletIndex: 0,
        accountId: accountId,
        scheme: DilithiumSchemeExtension.current,
        derivationPath: HdWalletService.pathForIndex(0, DilithiumSchemeExtension.current),
        existingAccounts: const [],
      );

      verify(settings.setMnemonic(mnemonic, 0)).called(1);
      verify(accounts.addAccount(argThat(isA<Account>().having((a) => a.accountId, 'accountId', 'abc')))).called(1);

      expect(created.accountId, accountId);
      expect(created.name, name);
    });

    test('skips add and referral when root account already exists', () async {
      final settings = MockSettingsService();
      final accounts = MockAccountsService();

      final service = WalletCreationService(settingsService: settings, accountsService: accounts);

      const existing = Account(walletIndex: 0, index: 0, name: 'Existing', accountId: 'existing_addr');

      final created = await service.createNewWallet(
        name: 'Account 1',
        mnemonic: 'word ' * 12,
        walletIndex: 0,
        accountId: 'new_derived_addr',
        scheme: DilithiumSchemeExtension.current,
        derivationPath: HdWalletService.pathForIndex(0, DilithiumSchemeExtension.current),
        existingAccounts: const [existing],
      );

      verify(settings.setMnemonic('word ' * 12, 0)).called(1);
      verifyNever(accounts.addAccount(any));
      expect(created, same(existing));
    });
  });
}
