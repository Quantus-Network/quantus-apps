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
  group('groupAccounts', () {
    test('empty input is flat and empty', () {
      final r = groupAccounts(accounts: [], multisigs: []);
      expect(r.segmented, isFalse);
      expect(r.items, isEmpty);
    });

    test('single software wallet of only transparent accounts renders flat', () {
      final r = groupAccounts(accounts: [_acc(0, 0), _acc(0, 1)], multisigs: []);
      expect(r.segmented, isFalse);
      expect(r.items.length, 2);
      expect(r.items.every((e) => e is AccountRowItem), isTrue);
    });

    test('encrypted account forces segmented layout with sub-segments', () {
      final r = groupAccounts(
        accounts: [
          _acc(0, 0),
          _acc(0, 1, type: AccountType.encrypted, id: 'enc'),
        ],
        multisigs: [],
      );
      expect(r.segmented, isTrue);
      expect(r.items[0], isA<WalletHeaderItem>());
      final header = r.items[0] as WalletHeaderItem;
      expect(header.kind, WalletKind.software);
      expect(header.number, 1);
      expect((r.items[1] as SegmentHeaderItem).segment, AccountSegment.transparent);
      expect(r.items[2], isA<AccountRowItem>());
      expect((r.items[3] as SegmentHeaderItem).segment, AccountSegment.encrypted);
      expect(((r.items[4] as AccountRowItem).account as Account).accountType, AccountType.encrypted);
    });

    test('multiple software wallets are numbered by display order', () {
      final r = groupAccounts(accounts: [_acc(1, 0), _acc(0, 0)], multisigs: []);
      final headers = r.items.whereType<WalletHeaderItem>().toList();
      expect(headers.length, 2);
      expect(headers.map((h) => h.number), [1, 2]);
      expect(headers.every((h) => h.kind == WalletKind.software), isTrue);
    });

    test('keystone wallets come after software wallets with own numbering', () {
      final r = groupAccounts(
        accounts: [
          _acc(0, 0),
          _acc(1, 0, type: AccountType.keystone, id: 'k'),
        ],
        multisigs: [],
      );
      final headers = r.items.whereType<WalletHeaderItem>().toList();
      expect(headers.length, 2);
      expect(headers[0].kind, WalletKind.software);
      expect(headers[0].number, 1);
      expect(headers[1].kind, WalletKind.keystone);
      expect(headers[1].number, 1);
      expect(r.items.whereType<SegmentHeaderItem>().any((s) => s.segment == AccountSegment.keystone), isTrue);
    });

    test('multisig is grouped under its owner wallet', () {
      final accounts = [_acc(0, 0, id: 'mine0'), _acc(1, 0, id: 'mine1')];
      final r = groupAccounts(accounts: accounts, multisigs: [_msig('msigaddr', 'mine1')]);
      final idx = r.items.indexWhere((e) => e is AccountRowItem && e.account.accountId == 'msigaddr');
      expect(idx, greaterThan(0));
      final header = r.items.sublist(0, idx).whereType<WalletHeaderItem>().last;
      expect(header.kind, WalletKind.software);
      expect(header.number, 2);
      expect((r.items[idx - 1] as SegmentHeaderItem).segment, AccountSegment.multisig);
    });

    test('unresolved multisig trails as a standalone multisig segment', () {
      final r = groupAccounts(
        accounts: [_acc(0, 0, id: 'mine')],
        multisigs: [_msig('msigaddr', 'stranger')],
      );
      expect(r.segmented, isTrue);
      final last = r.items.last as AccountRowItem;
      expect(last.account.accountId, 'msigaddr');
      expect((r.items[r.items.length - 2] as SegmentHeaderItem).segment, AccountSegment.multisig);
    });
  });
}
