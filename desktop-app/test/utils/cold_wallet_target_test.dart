import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/utils/cold_wallet_target.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

const _main = Account(walletIndex: 0, index: 0, name: 'Main', accountId: 'qzMain');
const _trading = Account(walletIndex: 2, index: 0, name: 'Trading', accountId: 'qzTrading');

Account _cold(int walletIndex, int index, String name) => Account(
  walletIndex: walletIndex,
  index: index,
  name: name,
  accountId: 'qzCold$walletIndex-$index',
  accountType: AccountType.keystone,
);

void main() {
  test('with no cold wallet, a new one at the next free wallet index, called Cold Wallet', () {
    final target = coldWalletTarget([_main, _trading], activeAccountId: _main.accountId);

    expect(target, (walletIndex: 1, name: 'Cold Wallet', isNewWallet: true));
  });

  test('with one, that wallet, and the account is called Cold Wallet 2', () {
    final target = coldWalletTarget([_main, _cold(1, 0, 'Cold Wallet')], activeAccountId: _main.accountId);

    expect(target, (walletIndex: 1, name: 'Cold Wallet 2', isNewWallet: false));
  });

  group('the name is the lowest Cold Wallet N from 2 that its wallet does not use', () {
    test('with Cold Wallet and Cold Wallet 3, Cold Wallet 2', () {
      final accounts = [_main, _cold(1, 0, 'Cold Wallet'), _cold(1, 1, 'Cold Wallet 3')];

      expect(coldWalletTarget(accounts, activeAccountId: _main.accountId).name, 'Cold Wallet 2');
    });

    test('with the first renamed Vault, still Cold Wallet 2', () {
      final accounts = [_main, _cold(1, 0, 'Vault')];

      expect(coldWalletTarget(accounts, activeAccountId: _main.accountId).name, 'Cold Wallet 2');
    });

    test('with Cold Wallet 2 and 3, Cold Wallet 4', () {
      final accounts = [_main, _cold(1, 0, 'Cold Wallet'), _cold(1, 1, 'Cold Wallet 2'), _cold(1, 2, 'Cold Wallet 3')];

      expect(coldWalletTarget(accounts, activeAccountId: _main.accountId).name, 'Cold Wallet 4');
    });

    test('names in another cold wallet do not count', () {
      final accounts = [_main, _cold(1, 0, 'Cold Wallet'), _cold(3, 0, 'Cold Wallet 2')];

      expect(coldWalletTarget(accounts, activeAccountId: _main.accountId), (
        walletIndex: 1,
        name: 'Cold Wallet 2',
        isNewWallet: false,
      ));
    });
  });

  group('with two cold wallets from before', () {
    final accounts = [_main, _cold(1, 0, 'Cold Wallet'), _trading, _cold(3, 0, 'Cold Wallet')];

    test('the active account\'s, when it is in one', () {
      expect(coldWalletTarget(accounts, activeAccountId: 'qzCold3-0').walletIndex, 3);
    });

    test('the lowest index, when the active account is not in one', () {
      expect(coldWalletTarget(accounts, activeAccountId: _trading.accountId).walletIndex, 1);
      expect(coldWalletTarget(accounts, activeAccountId: 'qzTeam').walletIndex, 1);
      expect(coldWalletTarget(accounts, activeAccountId: null).walletIndex, 1);
    });
  });
}
