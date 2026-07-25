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

String getAccountBadgeInitials(String text, {required String separator}) {
  if (text.isEmpty) return '?';

  final parts = text.split(separator).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  if (parts.length >= 2) {
    final a = parts[0];
    final b = parts[1];
    return '${a[0]}${b[0]}'.toUpperCase();
  }

  return text.length >= 2 ? text.substring(0, 2).toUpperCase() : text[0].toUpperCase();
}
