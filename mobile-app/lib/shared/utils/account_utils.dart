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
