import 'package:collection/collection.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Wallet index the active account belongs to, used when adding a sibling
/// account (transparent/encrypted) to the currently selected wallet.
int walletIndexForActiveAccount(List<Account> accounts, DisplayAccount? activeDisplayAccount) {
  if (activeDisplayAccount is RegularAccount) {
    return activeDisplayAccount.account.walletIndex;
  }
  if (activeDisplayAccount is EntrustedDisplayAccount) {
    final parent = accounts.firstWhereOrNull((a) => a.accountId == activeDisplayAccount.account.parentAccountId);
    if (parent != null) return parent.walletIndex;
  }
  return accounts.isNotEmpty ? accounts.first.walletIndex : 0;
}

/// Keystone accounts sign off-device via the QR flow. The debug flag forces
/// that path for testing.
extension AccountSigning on Account {
  bool get signsWithHardware => accountType == AccountType.keystone || AppConstants.debugHardwareWallet;

  /// A transparent account whose key signs in this app.
  bool get signsLocally => accountType == AccountType.local && !signsWithHardware;
}

List<int> getNonHardwareWalletIndices(List<Account> accounts) {
  final nonHardwareWalletIndices = <int>{};
  for (final account in accounts) {
    if (account.accountType != AccountType.keystone) {
      nonHardwareWalletIndices.add(account.walletIndex);
    }
  }
  return nonHardwareWalletIndices.toList()..sort();
}

/// Smallest non-negative index not used as [Account.walletIndex] by any account.
/// Wallet index is a shared namespace across software and hardware wallets, so a
/// new wallet (software import or hardware) must take a globally unused index.
int nextWalletIndex(List<Account> accounts) {
  final used = accounts.map((a) => a.walletIndex).toSet();
  var i = 0;
  while (used.contains(i)) {
    i++;
  }
  return i;
}
