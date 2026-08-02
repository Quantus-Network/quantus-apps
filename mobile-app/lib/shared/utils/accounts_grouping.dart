import 'package:quantus_sdk/quantus_sdk.dart';

enum WalletKind { software, keystone }

/// One wallet as displayed on the Accounts screen: its transparent (or
/// keystone) accounts, the single encrypted account (software wallets only),
/// and any multisigs owned by one of its accounts. [number] is the 1-based
/// position within its [kind], used for "Wallet {n}" fallback naming.
class WalletGroup {
  final int walletIndex;
  final WalletKind kind;
  final int number;
  final List<Account> accounts;
  final Account? encryptedAccount;
  final List<MultisigAccount> multisigs;

  const WalletGroup({
    required this.walletIndex,
    required this.kind,
    required this.number,
    required this.accounts,
    required this.encryptedAccount,
    required this.multisigs,
  });

  int get accountCount => accounts.length + (encryptedAccount == null ? 0 : 1) + multisigs.length;
}

/// Result of grouping accounts for the Accounts screen. The first wallet is
/// the main wallet (lowest software walletIndex); multisigs whose member
/// account is unknown trail in [standaloneMultisigs].
class WalletsGrouping {
  final List<WalletGroup> wallets;
  final List<MultisigAccount> standaloneMultisigs;
  const WalletsGrouping({required this.wallets, required this.standaloneMultisigs});
}

/// Pure mapping of accounts + multisigs to wallet groups, ordered software
/// wallets (by walletIndex) then keystone wallets (by walletIndex). Multisigs
/// are owned by the wallet of the account matching
/// [MultisigAccount.myMemberAccountId].
WalletsGrouping groupWallets({required List<Account> accounts, required List<MultisigAccount> multisigs}) {
  final byWallet = <int, List<Account>>{};
  for (final a in accounts) {
    byWallet.putIfAbsent(a.walletIndex, () => []).add(a);
  }

  final walletIndexByAccountId = <String, int>{};
  for (final a in accounts) {
    walletIndexByAccountId[a.accountId] = a.walletIndex;
  }
  final multisigsByWallet = <int, List<MultisigAccount>>{};
  final standaloneMultisigs = <MultisigAccount>[];
  for (final m in multisigs) {
    final ownerIndex = walletIndexByAccountId[m.myMemberAccountId];
    if (ownerIndex == null) {
      standaloneMultisigs.add(m);
    } else {
      multisigsByWallet.putIfAbsent(ownerIndex, () => []).add(m);
    }
  }

  final softwareIndices = <int>[];
  final keystoneIndices = <int>[];
  for (final entry in byWallet.entries) {
    (_isKeystoneWallet(entry.value) ? keystoneIndices : softwareIndices).add(entry.key);
  }
  softwareIndices.sort();
  keystoneIndices.sort();

  WalletGroup buildGroup(WalletKind kind, int number, int walletIndex) {
    final group = byWallet[walletIndex] ?? [];
    final regular = group.where((a) => a.accountType != AccountType.encrypted).toList()..sort(_compareAccounts);
    final encrypted = group.where((a) => a.accountType == AccountType.encrypted).toList()..sort(_compareAccounts);
    final msigs = [...?multisigsByWallet[walletIndex]]..sort(_compareMultisigs);
    return WalletGroup(
      walletIndex: walletIndex,
      kind: kind,
      number: number,
      accounts: regular,
      encryptedAccount: encrypted.isEmpty ? null : encrypted.first,
      multisigs: msigs,
    );
  }

  final wallets = <WalletGroup>[
    for (var i = 0; i < softwareIndices.length; i++) buildGroup(WalletKind.software, i + 1, softwareIndices[i]),
    for (var i = 0; i < keystoneIndices.length; i++) buildGroup(WalletKind.keystone, i + 1, keystoneIndices[i]),
  ];

  return WalletsGrouping(wallets: wallets, standaloneMultisigs: [...standaloneMultisigs]..sort(_compareMultisigs));
}

bool _isKeystoneWallet(List<Account> group) =>
    group.isNotEmpty && group.every((a) => a.accountType == AccountType.keystone);

/// 1-based display number of the software wallet at [walletIndex], matching the
/// numbering used by [groupWallets]. Returns null when [walletIndex] is not a
/// software wallet.
int? softwareWalletNumber(List<Account> accounts, int walletIndex) {
  final byWallet = <int, List<Account>>{};
  for (final a in accounts) {
    byWallet.putIfAbsent(a.walletIndex, () => []).add(a);
  }
  final softwareIndices = [
    for (final entry in byWallet.entries)
      if (!_isKeystoneWallet(entry.value)) entry.key,
  ]..sort();
  final pos = softwareIndices.indexOf(walletIndex);
  return pos == -1 ? null : pos + 1;
}

int _compareAccounts(Account a, Account b) {
  final w = a.walletIndex.compareTo(b.walletIndex);
  return w != 0 ? w : a.index.compareTo(b.index);
}

int _compareMultisigs(MultisigAccount a, MultisigAccount b) {
  final n = a.name.toLowerCase().compareTo(b.name.toLowerCase());
  return n != 0 ? n : a.accountId.compareTo(b.accountId);
}
