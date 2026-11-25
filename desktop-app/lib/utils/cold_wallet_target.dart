import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/utils/account_utils.dart';

/// What a cold wallet's first account is called, as on the phone. Its
/// further accounts are "Cold Wallet 2" and on; neither is translated.
const coldWalletName = 'Cold Wallet';

/// Where an account scanned from a cold wallet goes, and what it is called.
typedef ColdWalletTarget = ({int walletIndex, String name, bool isNewWallet});

/// The cold wallet an account connected now is added to, of [accounts]: the
/// active account's ([activeAccountId]) when it is in one, else the one with
/// the lowest index. With none, a new one at [nextWalletIndex], called
/// [coldWalletName]. In a cold wallet there already, it is the lowest
/// "Cold Wallet N" from 2 that none of its accounts is called.
ColdWalletTarget coldWalletTarget(List<Account> accounts, {required String? activeAccountId}) {
  final coldAccounts = accounts.where((account) => account.accountType == AccountType.keystone);
  if (coldAccounts.isEmpty) {
    return (walletIndex: nextWalletIndex(accounts), name: coldWalletName, isNewWallet: true);
  }
  final walletIndex =
      coldAccounts.where((account) => account.accountId == activeAccountId).firstOrNull?.walletIndex ??
      coldAccounts.map((account) => account.walletIndex).reduce((a, b) => a < b ? a : b);
  final names = {
    for (final account in accounts)
      if (account.walletIndex == walletIndex) account.name,
  };
  var number = 2;
  while (names.contains('$coldWalletName $number')) {
    number++;
  }
  return (walletIndex: walletIndex, name: '$coldWalletName $number', isNewWallet: false);
}
