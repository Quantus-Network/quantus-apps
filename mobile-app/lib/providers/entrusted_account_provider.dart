import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

final entrustedAccountsProvider = FutureProvider.family<List<Account>, Account>((ref, account) async {
  final highSecurityService = HighSecurityService();
  final interceptedAccounts = await highSecurityService.getEntrustedAccounts(account);
  print('intercepted accounts: ${interceptedAccounts.map((account) => account.accountId).join(', ')}');
  return interceptedAccounts;
});
