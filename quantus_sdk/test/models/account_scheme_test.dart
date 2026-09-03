import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  group('Account scheme serialization', () {
    test('legacy JSON without a scheme reads as ML-DSA-87 at the legacy path', () {
      final account = Account.fromJson({'walletIndex': 0, 'index': 0, 'name': 'Account 1', 'accountId': 'id'});
      expect(account.scheme, DilithiumScheme.mlDsa87);
      expect(account.derivationPath, HdWalletService.pathForIndex(0, DilithiumScheme.mlDsa87));
    });

    test('a local account round-trips its scheme and path', () {
      final account = Account(
        walletIndex: 1,
        index: 2,
        name: 'Account 3',
        accountId: 'id',
        scheme: DilithiumScheme.mlDsa65,
        derivationPath: HdWalletService.pathForIndex(2, DilithiumScheme.mlDsa65),
      );
      final restored = Account.fromJson(account.toJson());
      expect(restored.scheme, DilithiumScheme.mlDsa65);
      expect(restored.derivationPath, account.derivationPath);
    });

    test('keystone and encrypted accounts carry no scheme', () {
      for (final type in [AccountType.keystone, AccountType.encrypted]) {
        final account = Account(walletIndex: 0, index: 0, name: 'x', accountId: 'id', accountType: type);
        final restored = Account.fromJson(account.toJson());
        expect(restored.scheme, isNull);
        expect(restored.derivationPath, isNull);
      }
    });

    test('accounts sort current-scheme first, then by index, keyless last', () {
      Account local(int i, DilithiumScheme s) => Account(
        walletIndex: 0,
        index: i,
        name: 'a',
        accountId: '${s.storageName}_$i',
        scheme: s,
        derivationPath: HdWalletService.pathForIndex(i, s),
      );
      const keystone = Account(walletIndex: 0, index: 3, name: 'k', accountId: 'k', accountType: AccountType.keystone);
      final sorted = [
        local(1, DilithiumScheme.mlDsa87),
        keystone,
        local(0, DilithiumScheme.mlDsa65),
        local(0, DilithiumScheme.mlDsa87),
      ]..sort(Account.compare);
      expect(sorted.map((a) => a.accountId), ['ml-dsa-65_0', 'ml-dsa-87_0', 'ml-dsa-87_1', 'k']);
    });
  });

  group('AccountsService.walletScheme', () {
    Account local(int wallet, DilithiumScheme s) =>
        Account(walletIndex: wallet, index: 0, name: 'a', accountId: '$wallet${s.storageName}', scheme: s);

    test('a wallet with only legacy accounts stays legacy', () {
      expect(AccountsService.walletScheme([local(0, DilithiumScheme.mlDsa87)], 0), DilithiumScheme.mlDsa87);
    });

    test('a wallet holding any current-scheme account grows as current', () {
      final accounts = [local(0, DilithiumScheme.mlDsa87), local(0, DilithiumScheme.mlDsa65)];
      expect(AccountsService.walletScheme(accounts, 0), DilithiumScheme.mlDsa65);
    });

    test('an empty or unrelated wallet defaults to legacy', () {
      expect(AccountsService.walletScheme([local(1, DilithiumScheme.mlDsa65)], 0), DilithiumScheme.mlDsa87);
    });
  });
}
