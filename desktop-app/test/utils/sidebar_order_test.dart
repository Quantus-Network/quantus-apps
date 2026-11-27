import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/utils/sidebar_order.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

import '../fakes.dart';

/// Wallet 0 (Main, Savings), the cold wallet at 1 (Vault), Wallet 2
/// (Trading).
const _accounts = [mainAccount, savingsAccount, vaultAccount, tradingAccount];

/// Each group as its key in the order: `wallet:<index>` or `multisigs`.
List<String> _keys(List<SidebarGroup> groups) => [for (final group in groups) group.orderKey];

List<SidebarGroup> _group({List<String> order = const [], List<MultisigAccount>? multisigs}) =>
    groupSidebar(accounts: _accounts, multisigs: multisigs ?? [teamMultisig], order: order);

void main() {
  test('with no order kept: the software wallets, then the cold wallets, then the multisigs', () {
    expect(_keys(_group()), ['wallet:0', 'wallet:2', 'wallet:1', 'multisigs']);
  });

  test('a kept order is followed, the multisigs anywhere in it', () {
    expect(_keys(_group(order: ['multisigs', 'wallet:1', 'wallet:2', 'wallet:0'])), [
      'multisigs',
      'wallet:1',
      'wallet:2',
      'wallet:0',
    ]);
    expect(_keys(_group(order: ['wallet:2', 'multisigs', 'wallet:0', 'wallet:1'])), [
      'wallet:2',
      'multisigs',
      'wallet:0',
      'wallet:1',
    ]);
  });

  test('a wallet missing from the order goes right after its last wallet; the multisigs, missing, go last', () {
    expect(_keys(_group(order: ['wallet:2', 'multisigs', 'wallet:0'])), [
      'wallet:2',
      'multisigs',
      'wallet:0',
      'wallet:1',
    ]);
    expect(_keys(_group(order: ['multisigs', 'wallet:2'])), ['multisigs', 'wallet:2', 'wallet:0', 'wallet:1']);
    expect(_keys(_group(order: ['multisigs'])), ['multisigs', 'wallet:0', 'wallet:2', 'wallet:1']);
    expect(_keys(_group(order: ['wallet:1', 'wallet:0'])), ['wallet:1', 'wallet:0', 'wallet:2', 'multisigs']);
  });

  test('a kept group that is no longer there is passed over', () {
    expect(_keys(_group(order: ['wallet:7', 'wallet:2', 'wallet:0', 'wallet:1', 'multisigs'], multisigs: [])), [
      'wallet:2',
      'wallet:0',
      'wallet:1',
    ]);
  });

  test('the multisigs\' group is there with no multisig only when asked for, as while one is being created', () {
    expect(_keys(_group(multisigs: [])), ['wallet:0', 'wallet:2', 'wallet:1']);
    expect(_keys(groupSidebar(accounts: _accounts, multisigs: [], order: const [], showsMultisigs: true)), [
      'wallet:0',
      'wallet:2',
      'wallet:1',
      'multisigs',
    ]);
  });

  test('the accounts in sidebar order follow the order kept', () {
    final groups = _group(order: ['multisigs', 'wallet:2', 'wallet:1', 'wallet:0']);
    expect(
      [for (final account in accountsInSidebarOrder(groups)) account.account.accountId],
      ['qzTeam', 'qzTrading', 'qzVault', 'qzMain', 'qzSavings'],
    );
  });
}
