import 'package:quantus_sdk/quantus_sdk.dart';

List<int> getNonHardwareWalletIndices(List<Account> accounts) {
  final nonHardwareWalletIndices = <int>{};
  for (final account in accounts) {
    if (account.accountType != AccountType.keystone) {
      nonHardwareWalletIndices.add(account.walletIndex);
    }
  }
  return nonHardwareWalletIndices.toList()..sort();
}

/// Smallest non-negative index not used as [Account.walletIndex] by any non-hardware account.
/// Use when importing a new recovery phrase or otherwise adding a distinct software HD wallet.
int nextNonHardwareWalletIndex(List<Account> accounts) {
  final used = getNonHardwareWalletIndices(accounts).toSet();
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
