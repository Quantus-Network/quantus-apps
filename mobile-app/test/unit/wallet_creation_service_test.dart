import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/services/wallet_creation_service.dart';

@GenerateNiceMocks([MockSpec<SettingsService>(), MockSpec<AccountsService>(), MockSpec<AccountDiscoveryService>()])
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

  group('WalletCreationService.discoverImportedAccounts', () {
    const mnemonic = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
    Account at(int index, DilithiumScheme scheme) => Account(
      walletIndex: 0,
      index: index,
      name: 'Account ${index + 1}',
      accountId: '${scheme.storageName}_$index',
      scheme: scheme,
      derivationPath: HdWalletService.pathForIndex(index, scheme),
    );
    final root = at(0, DilithiumScheme.mlDsa87);
    final found = [at(3, DilithiumScheme.mlDsa87), at(0, DilithiumScheme.mlDsa65)];
    const encrypted = Account(
      walletIndex: 0,
      index: AppConstants.encryptedAccountIndex,
      name: 'Encrypted',
      accountId: 'encrypted',
      accountType: AccountType.encrypted,
    );
    Matcher account(String accountId, {String? name}) {
      var m = isA<Account>().having((a) => a.accountId, 'accountId', accountId);
      return name == null ? m : m.having((a) => a.name, 'name', name);
    }

    late MockSettingsService settings;
    late MockAccountsService accounts;
    late MockAccountDiscoveryService discovery;
    late WalletCreationService service;
    late bool pending;

    void activeIs(Account? active) =>
        when(settings.getActiveAccount()).thenAnswer((_) async => active == null ? null : RegularAccount(active));

    setUp(() {
      settings = MockSettingsService();
      accounts = MockAccountsService();
      discovery = MockAccountDiscoveryService();
      service = WalletCreationService(
        settingsService: settings,
        accountsService: accounts,
        discoveryService: discovery,
      );
      pending = false;
      when(settings.setAccountScanPending(any, any)).thenAnswer((i) async {
        pending = i.positionalArguments[1] as bool;
      });
      when(settings.isAccountScanPending(0)).thenAnswer((_) => pending);
      when(settings.getMnemonic(0)).thenAnswer((_) async => mnemonic);
      when(accounts.getAccounts()).thenAnswer((_) async => [root]);
      activeIs(root);
    });

    void scanReturns(Future<List<Account>> Function() answer) => when(
      discovery.discoverAccounts(
        mnemonic: anyNamed('mnemonic'),
        walletIndex: anyNamed('walletIndex'),
        gapLimit: anyNamed('gapLimit'),
      ),
    ).thenAnswer((_) => answer());

    Future<void> discover(Future<bool> Function(Object error) onScanFailed) => service.discoverImportedAccounts(
      mnemonic: mnemonic,
      walletIndex: 0,
      defaultAccountId: root.accountId,
      onScanFailed: onScanFailed,
    );

    test(
      'adds every account found, whatever its scheme or index, and activates the first when the root is empty',
      () async {
        scanReturns(() async => found);
        final failures = <Object>[];

        await discover((e) async {
          failures.add(e);
          return false;
        });

        expect(failures, isEmpty);
        verifyInOrder([
          settings.setAccountScanPending(0, true),
          accounts.addAccount(argThat(account('ml-dsa-87_3', name: 'Account 2'))),
          accounts.addAccount(argThat(account('ml-dsa-65_0', name: 'Account 3'))),
          settings.setActiveAccount(
            argThat(isA<RegularAccount>().having((a) => a.account.accountId, 'accountId', 'ml-dsa-87_3')),
          ),
          settings.setAccountScanPending(0, false),
        ]);
      },
    );

    test('keeps the root active and does not re-add it when the scan finds it', () async {
      scanReturns(() async => [root, found.first]);

      await discover((_) async => false);

      verify(accounts.addAccount(argThat(account('ml-dsa-87_3')))).called(1);
      verifyNever(accounts.addAccount(argThat(account(root.accountId))));
      verifyNever(settings.setActiveAccount(any));
    });

    test('a failed scan is retried when asked and adds the accounts on the second attempt', () async {
      var scans = 0;
      scanReturns(() async {
        if (scans++ == 0) throw Exception('indexer unreachable');
        return found;
      });
      final failures = <Object>[];

      await discover((e) async {
        failures.add(e);
        return true;
      });

      expect(failures, hasLength(1));
      expect(scans, 2);
      verify(accounts.addAccount(any)).called(2);
    });

    test('declining the retry ends the scan without adding anything', () async {
      scanReturns(() async => throw Exception('indexer unreachable'));
      var asked = 0;

      await discover((_) async {
        asked++;
        return false;
      });

      expect(asked, 1);
      verifyNever(accounts.addAccount(any));
      verifyNever(settings.setActiveAccount(any));
      verify(settings.setAccountScanPending(0, true)).called(1);
      verifyNever(settings.setAccountScanPending(0, false));
    });

    test('a skipped scan finishes on a later start, restores the ML-DSA-65 account and makes it active', () async {
      var online = false;
      scanReturns(() async => online ? [found.last] : throw Exception('indexer unreachable'));

      await discover((_) async => false);
      expect(pending, isTrue);
      verifyNever(accounts.addAccount(any));

      online = true;
      expect(await service.resumePendingAccountScans([root]), isTrue);

      expect(pending, isFalse);
      verify(accounts.addAccount(argThat(account('ml-dsa-65_0', name: 'Account 2')))).called(1);
      verify(
        settings.setActiveAccount(
          argThat(isA<RegularAccount>().having((a) => a.account.accountId, 'accountId', 'ml-dsa-65_0')),
        ),
      ).called(1);
    });

    test("a resumed scan leaves an active account outside the wallet's transparent accounts alone", () async {
      final otherWallet = at(0, DilithiumScheme.mlDsa87).copyWith(walletIndex: 1, accountId: 'other_wallet');
      for (final active in [encrypted, otherWallet]) {
        pending = true;
        activeIs(active);
        scanReturns(() async => [found.last]);

        await service.resumePendingAccountScans([root]);
      }

      verify(accounts.addAccount(argThat(account('ml-dsa-65_0')))).called(2);
      verifyNever(settings.setActiveAccount(any));
    });

    test('an account selected while the scan runs stays selected', () async {
      scanReturns(() async {
        activeIs(encrypted);
        return found;
      });

      await discover((_) async => false);

      verify(accounts.addAccount(any)).called(2);
      verifyNever(settings.setActiveAccount(any));
    });

    test('a wallet removed while the scan runs is not written back', () async {
      scanReturns(() async {
        pending = false;
        return found;
      });

      await discover((_) async => false);

      verifyNever(accounts.addAccount(any));
      verifyNever(settings.setActiveAccount(any));
    });

    test('resume leaves wallets whose scan finished alone', () async {
      expect(await service.resumePendingAccountScans([root]), isFalse);

      verifyNever(
        discovery.discoverAccounts(
          mnemonic: anyNamed('mnemonic'),
          walletIndex: anyNamed('walletIndex'),
          gapLimit: anyNamed('gapLimit'),
        ),
      );
    });
  });
}
