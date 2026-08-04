import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/shared/utils/accounts_grouping.dart';

Account _acc(int wallet, int index, {AccountType type = AccountType.local, String? id}) => Account(
  walletIndex: wallet,
  index: index,
  name: 'A$wallet-$index',
  accountId: id ?? 'addr-$wallet-$index',
  accountType: type,
);

MultisigAccount _msig(String id, String myMember, {String name = 'Multisig'}) => MultisigAccount(
  name: name,
  accountId: id,
  signers: const ['a', 'b'],
  threshold: 2,
  nonce: BigInt.zero,
  myMemberAccountId: myMember,
);

void main() {
  group('groupWallets', () {
    test('empty input has no wallets', () {
      final r = groupWallets(accounts: [], multisigs: []);
      expect(r.wallets, isEmpty);
      expect(r.standaloneMultisigs, isEmpty);
    });

    test('single wallet groups transparent accounts sorted by index', () {
      final r = groupWallets(accounts: [_acc(0, 1), _acc(0, 0)], multisigs: []);
      expect(r.wallets.length, 1);
      final w = r.wallets.single;
      expect(w.walletIndex, 0);
      expect(w.kind, WalletKind.software);
      expect(w.number, 1);
      expect(w.accounts.map((a) => a.index), [0, 1]);
      expect(w.encryptedAccount, isNull);
      expect(w.accountCount, 2);
    });

    test('encrypted account is split out of the account list', () {
      final r = groupWallets(
        accounts: [
          _acc(0, 0),
          _acc(0, 1024, type: AccountType.encrypted, id: 'enc'),
        ],
        multisigs: [],
      );
      final w = r.wallets.single;
      expect(w.accounts.length, 1);
      expect(w.encryptedAccount?.accountId, 'enc');
      expect(w.accountCount, 2);
    });

    test('multiple software wallets are ordered and numbered by walletIndex', () {
      final r = groupWallets(accounts: [_acc(1, 0), _acc(0, 0)], multisigs: []);
      expect(r.wallets.map((w) => w.walletIndex), [0, 1]);
      expect(r.wallets.map((w) => w.number), [1, 2]);
      expect(r.wallets.every((w) => w.kind == WalletKind.software), isTrue);
    });

    test('active wallet moves to front keeping its number, others stay in order', () {
      final r = groupWallets(
        accounts: [_acc(0, 0), _acc(1, 0), _acc(2, 0)],
        multisigs: [],
        activeAccountId: 'addr-1-0',
      );
      expect(r.wallets.map((w) => w.walletIndex), [1, 0, 2]);
      expect(r.wallets.map((w) => w.number), [2, 1, 3]);
    });

    test('unknown active account leaves wallet order unchanged', () {
      final r = groupWallets(accounts: [_acc(0, 0), _acc(1, 0)], multisigs: [], activeAccountId: 'stranger');
      expect(r.wallets.map((w) => w.walletIndex), [0, 1]);
    });

    test('keystone wallets come after software wallets with own numbering', () {
      final r = groupWallets(
        accounts: [
          _acc(1, 0),
          _acc(0, 0, type: AccountType.keystone, id: 'k'),
        ],
        multisigs: [],
      );
      expect(r.wallets.length, 2);
      expect(r.wallets[0].kind, WalletKind.software);
      expect(r.wallets[0].walletIndex, 1);
      expect(r.wallets[0].number, 1);
      expect(r.wallets[1].kind, WalletKind.keystone);
      expect(r.wallets[1].walletIndex, 0);
      expect(r.wallets[1].number, 1);
    });

    test('multisig is grouped under its owner wallet and counted', () {
      final accounts = [_acc(0, 0, id: 'mine0'), _acc(1, 0, id: 'mine1')];
      final r = groupWallets(accounts: accounts, multisigs: [_msig('msigaddr', 'mine1')]);
      expect(r.wallets[0].multisigs, isEmpty);
      expect(r.wallets[1].multisigs.single.accountId, 'msigaddr');
      expect(r.wallets[1].accountCount, 2);
      expect(r.standaloneMultisigs, isEmpty);
    });

    test('unresolved multisig trails as standalone', () {
      final r = groupWallets(
        accounts: [_acc(0, 0, id: 'mine')],
        multisigs: [_msig('msigaddr', 'stranger')],
      );
      expect(r.wallets.single.multisigs, isEmpty);
      expect(r.standaloneMultisigs.single.accountId, 'msigaddr');
    });
  });

  group('softwareWalletNumber', () {
    test('numbers software wallets by display order, skipping keystone', () {
      final accounts = [_acc(0, 0, type: AccountType.keystone, id: 'k'), _acc(1, 0), _acc(3, 0)];
      expect(softwareWalletNumber(accounts, 1), 1);
      expect(softwareWalletNumber(accounts, 3), 2);
      expect(softwareWalletNumber(accounts, 0), isNull);
    });
  });
}
