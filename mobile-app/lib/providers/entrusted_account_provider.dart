import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';

final entrustedAccountsProvider = FutureProvider.family<List<EntrustedAccount>, Account>((ref, account) async {
  final highSecurityService = HighSecurityService();
  final interceptedAccounts = await highSecurityService.getEntrustedAccounts(account);
  quantusDebugPrint('intercepted accounts: ${interceptedAccounts.map((account) => account.accountId).join(', ')}');
  return interceptedAccounts;
});
