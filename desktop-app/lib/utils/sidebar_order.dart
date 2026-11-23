import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/utils/accounts_grouping.dart';

/// A wallet's accounts in the order the sidebar lists them under it: its own
/// accounts, its encrypted account, then the multisigs it is a member of.
List<DisplayAccount> walletAccountsInOrder(WalletGroup wallet) => [
  for (final account in wallet.accounts) RegularAccount(account),
  if (wallet.encryptedAccount case final encrypted?) RegularAccount(encrypted),
  for (final multisig in wallet.multisigs) MultisigDisplayAccount(multisig),
];

/// Every account in the order the sidebar lists them, top to bottom: wallet
/// by wallet, then the multisigs no wallet here is a member of. The menus
/// number the accounts by it.
List<DisplayAccount> accountsInSidebarOrder(WalletsGrouping grouping) => [
  for (final wallet in grouping.wallets) ...walletAccountsInOrder(wallet),
  for (final multisig in grouping.standaloneMultisigs) MultisigDisplayAccount(multisig),
];
