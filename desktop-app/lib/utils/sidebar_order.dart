import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/utils/accounts_grouping.dart';

/// What the sidebar lists, in its groups: the wallets, each with its own
/// accounts, then every multisig, under a heading of their own whichever of
/// this app's accounts is their member, and whether or not one still is.
typedef SidebarGroups = ({List<WalletGroup> wallets, List<MultisigAccount> multisigs});

/// [accounts] and [multisigs] in the sidebar's groups: the wallets in
/// [groupWallets]'s order, with no multisig in any, and the multisigs by name.
SidebarGroups groupSidebar({required List<Account> accounts, required List<MultisigAccount> multisigs}) => (
  wallets: groupWallets(accounts: accounts, multisigs: const []).wallets,
  multisigs: [...multisigs]..sort(compareMultisigs),
);

/// A wallet's accounts in the order the sidebar lists them under it: its own
/// accounts, then its encrypted account.
List<DisplayAccount> walletAccountsInOrder(WalletGroup wallet) => [
  for (final account in wallet.accounts) RegularAccount(account),
  if (wallet.encryptedAccount case final encrypted?) RegularAccount(encrypted),
];

/// Every account in the order the sidebar lists them, top to bottom: wallet
/// by wallet, then the multisigs. The menus number the accounts by it.
List<DisplayAccount> accountsInSidebarOrder(SidebarGroups groups) => [
  for (final wallet in groups.wallets) ...walletAccountsInOrder(wallet),
  for (final multisig in groups.multisigs) MultisigDisplayAccount(multisig),
];
