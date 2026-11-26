import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/utils/accounts_grouping.dart';

/// A group the sidebar lists under a heading of its own: a wallet with its
/// accounts, or every multisig.
sealed class SidebarGroup {
  const SidebarGroup();

  /// What the group is kept as in the sidebar's order ([groupSidebar]).
  String get orderKey;
}

/// A wallet and its own accounts; no multisig is in one.
final class SidebarWallet extends SidebarGroup {
  const SidebarWallet(this.wallet);

  final WalletGroup wallet;

  @override
  String get orderKey => keyOf(wallet.walletIndex);

  /// The key of the wallet at [walletIndex] in the sidebar's order.
  static String keyOf(int walletIndex) => 'wallet:$walletIndex';
}

/// Every multisig, under a heading of their own whichever of this app's
/// accounts is their member, and whether or not one still is.
final class SidebarMultisigs extends SidebarGroup {
  const SidebarMultisigs(this.multisigs);

  /// By name ([compareMultisigs]).
  final List<MultisigAccount> multisigs;

  static const key = 'multisigs';

  @override
  String get orderKey => key;
}

/// [accounts] and [multisigs] in the sidebar's groups, top to bottom, in the
/// [order] kept, by [SidebarGroup.orderKey]. With none kept: the wallets in
/// [groupWallets]'s order (software, then cold wallets), then the multisigs.
/// A wallet not in [order] goes right after the last wallet in it (after
/// every group in it when it holds no wallet), and the multisigs, not in it,
/// go last; a key in it of a group not here is passed
/// over. The multisigs' group is there while there are multisigs, or where
/// [showsMultisigs] (one being created).
List<SidebarGroup> groupSidebar({
  required List<Account> accounts,
  required List<MultisigAccount> multisigs,
  required List<String> order,
  bool showsMultisigs = false,
}) {
  final wallets = [
    for (final wallet in groupWallets(accounts: accounts, multisigs: const []).wallets) SidebarWallet(wallet),
  ];
  final multisigsGroup = multisigs.isNotEmpty || showsMultisigs
      ? SidebarMultisigs([...multisigs]..sort(compareMultisigs))
      : null;
  final byKey = <String, SidebarGroup>{
    for (final wallet in wallets) wallet.orderKey: wallet,
    if (multisigsGroup != null) multisigsGroup.orderKey: multisigsGroup,
  };

  final placed = <SidebarGroup>[
    for (final key in order.toSet())
      if (byKey[key] case final group?) group,
  ];
  final unplacedWallets = [
    for (final wallet in wallets)
      if (!placed.contains(wallet)) wallet,
  ];
  final lastWallet = placed.lastIndexWhere((group) => group is SidebarWallet);
  placed.insertAll(lastWallet == -1 ? placed.length : lastWallet + 1, unplacedWallets);
  if (multisigsGroup != null && !placed.contains(multisigsGroup)) placed.add(multisigsGroup);
  return placed;
}

/// A wallet's accounts in the order the sidebar lists them under it: its own
/// accounts, then its encrypted account.
List<DisplayAccount> walletAccountsInOrder(WalletGroup wallet) => [
  for (final account in wallet.accounts) RegularAccount(account),
  if (wallet.encryptedAccount case final encrypted?) RegularAccount(encrypted),
];

/// The accounts of [group] in the order the sidebar lists them.
List<DisplayAccount> groupAccountsInOrder(SidebarGroup group) => switch (group) {
  SidebarWallet(:final wallet) => walletAccountsInOrder(wallet),
  SidebarMultisigs(:final multisigs) => [for (final multisig in multisigs) MultisigDisplayAccount(multisig)],
};

/// Every account in the order the sidebar lists them, top to bottom, group by
/// group. The menus number the accounts by it.
List<DisplayAccount> accountsInSidebarOrder(List<SidebarGroup> groups) => [
  for (final group in groups) ...groupAccountsInOrder(group),
];
