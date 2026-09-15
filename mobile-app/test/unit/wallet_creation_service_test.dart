import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/services/wallet_creation_service.dart';

@GenerateNiceMocks([MockSpec<SettingsService>(), MockSpec<AccountsService>()])
import 'wallet_creation_service_test.mocks.dart';

void main() {
  group('WalletCreationService.createNewWallet', () {
    const mnemonic = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
    const accountId = 'abc';
    const name = 'Account 1';
    final root = isA<Account>().having((a) => a.accountId, 'accountId', accountId);

    late MockSettingsService settings;
    late MockAccountsService accounts;
    late WalletCreationService service;

    setUp(() {
      settings = MockSettingsService();
      accounts = MockAccountsService();
      service = WalletCreationService(settingsService: settings, accountsService: accounts);
    });

    Future<Account> create() => service.createNewWallet(
      name: name,
      mnemonic: mnemonic,
      walletIndex: 0,
      accountId: accountId,
      scheme: DilithiumSchemeExtension.current,
      derivationPath: HdWalletService.pathForIndex(0, DilithiumSchemeExtension.current),
    );

    test('persists the mnemonic, inserts the root, then activates it and marks the migration done', () async {
      final created = await create();

      verifyInOrder([
        settings.setMnemonic(mnemonic, 0),
        accounts.addAccount(argThat(root)),
        settings.setWalletOrigin(0, WalletOrigin.created),
        settings.setActiveAccount(
          argThat(isA<RegularAccount>().having((a) => a.account.accountId, 'accountId', accountId)),
        ),
        settings.setMainnetMigrationDone(),
      ]);
      verifyNever(settings.deleteMnemonic(any));
      expect(created.accountId, accountId);
      expect(created.name, name);
    });

    test('a failed mnemonic write inserts nothing and leaves the migration pending', () async {
      when(settings.setMnemonic(any, any)).thenThrow(Exception('secure storage unavailable'));

      await expectLater(create(), throwsException);

      verifyNever(accounts.addAccount(any));
      verifyNever(settings.setMainnetMigrationDone());
      verifyNever(settings.setActiveAccount(any));
    });

    test('a failed root insert removes the mnemonic again and leaves the migration pending', () async {
      when(accounts.addAccount(any)).thenThrow(Exception('disk full'));

      await expectLater(create(), throwsException);

      verify(settings.deleteMnemonic(0)).called(1);
      verifyNever(settings.setWalletOrigin(any, any));
      verifyNever(settings.setMainnetMigrationDone());
      verifyNever(settings.setActiveAccount(any));
    });

    test('a failed activation after the insert still finishes with the created wallet', () async {
      when(settings.setActiveAccount(any)).thenThrow(Exception('disk full'));

      final created = await create();

      expect(created.accountId, accountId);
      verify(accounts.addAccount(argThat(root))).called(1);
      verifyNever(settings.deleteMnemonic(any));
    });

    test('a failed completion write after the insert still finishes with the created wallet', () async {
      when(settings.setMainnetMigrationDone()).thenThrow(Exception('disk full'));

      final created = await create();

      expect(created.accountId, accountId);
      verify(settings.setActiveAccount(any)).called(1);
      verifyNever(settings.deleteMnemonic(any));
    });
  });
}
