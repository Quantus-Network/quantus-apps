import 'package:quantus_sdk/quantus_sdk.dart';

enum WalletKind { software, keystone }

enum AccountSegment { transparent, encrypted, keystone, multisig }

sealed class AccountListItem {
  const AccountListItem();
}

/// A wallet group header, e.g. "Wallet 1" or "Keystone Hardware Wallet 1".
/// [number] is the 1-based position within its [kind].
class WalletHeaderItem extends AccountListItem {
  final WalletKind kind;
  final int number;
  const WalletHeaderItem({required this.kind, required this.number});
}

class SegmentHeaderItem extends AccountListItem {
  final AccountSegment segment;
  const SegmentHeaderItem(this.segment);
}

class AccountRowItem extends AccountListItem {
  final BaseAccount account;
  const AccountRowItem(this.account);
}

/// Result of grouping accounts for the Accounts popup. When [segmented] is
/// false, [items] is a flat list of [AccountRowItem] with no headers.
class AccountsGrouping {
  final bool segmented;
  final List<AccountListItem> items;
  const AccountsGrouping({required this.segmented, required this.items});
}

/// Pure mapping of accounts + multisigs to an ordered, segmented list.
///
/// Order: software wallets (by walletIndex) then keystone wallets (by
/// walletIndex). Within each wallet, sub-segments appear in order and are
/// skipped when empty: transparent, encrypted (software) / keystone (hardware),
/// then multisig. Multisigs are owned by the wallet of the account matching
/// [MultisigAccount.myMemberAccountId]; unresolved ones trail in a standalone
/// multisig segment. A single software wallet of only transparent accounts with
/// no multisigs renders flat (no headers).
AccountsGrouping groupAccounts({required List<Account> accounts, required List<MultisigAccount> multisigs}) {
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

  final atMostOneSoftwareWallet = softwareIndices.length <= 1 && keystoneIndices.isEmpty;
  final hasEncrypted = accounts.any((a) => a.accountType == AccountType.encrypted);
  final segmented = !(atMostOneSoftwareWallet && !hasEncrypted && multisigs.isEmpty);

  if (!segmented) {
    final flat = [...accounts]..sort(_compareAccounts);
    return AccountsGrouping(segmented: false, items: [for (final a in flat) AccountRowItem(a)]);
  }

  final items = <AccountListItem>[];

  void addSegment(AccountSegment segment, List<BaseAccount> rows) {
    if (rows.isEmpty) return;
    items.add(SegmentHeaderItem(segment));
    items.addAll(rows.map(AccountRowItem.new));
  }

  void addWallet(WalletKind kind, int number, int walletIndex) {
    final group = byWallet[walletIndex] ?? [];
    final msigs = [...?multisigsByWallet[walletIndex]]..sort(_compareMultisigs);
    items.add(WalletHeaderItem(kind: kind, number: number));

    if (kind == WalletKind.software) {
      final transparent = group.where((a) => a.accountType != AccountType.encrypted).toList()..sort(_compareAccounts);
      final encrypted = group.where((a) => a.accountType == AccountType.encrypted).toList()..sort(_compareAccounts);
      addSegment(AccountSegment.transparent, transparent);
      addSegment(AccountSegment.encrypted, encrypted);
    } else {
      final keystone = [...group]..sort(_compareAccounts);
      addSegment(AccountSegment.keystone, keystone);
    }
    addSegment(AccountSegment.multisig, msigs);
  }

  for (var i = 0; i < softwareIndices.length; i++) {
    addWallet(WalletKind.software, i + 1, softwareIndices[i]);
  }
  for (var i = 0; i < keystoneIndices.length; i++) {
    addWallet(WalletKind.keystone, i + 1, keystoneIndices[i]);
  }

  final standalone = [...standaloneMultisigs]..sort(_compareMultisigs);
  addSegment(AccountSegment.multisig, standalone);

  return AccountsGrouping(segmented: true, items: items);
}

bool _isKeystoneWallet(List<Account> group) =>
    group.isNotEmpty && group.every((a) => a.accountType == AccountType.keystone);

/// 1-based display number of the software wallet at [walletIndex], matching the
/// numbering used by [groupAccounts]. Returns null when [walletIndex] is not a
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
