import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

final entrustedAccountsProvider = FutureProvider.family<List<Account>, Account>((ref, account) async {
  // TODO: Implement actual fetching of entrusted accounts from SDK/API
  // For now we simulate the delay and return empty list or dummy data

  await Future.delayed(const Duration(milliseconds: 500));

  // Dummy data logic for demonstration/development
  // If you want to see the UI, you can uncomment this or use a specific account ID
  if (account.name.startsWith('G')) {
    //  arbitrary condition for testing
    return [
      const Account(
        walletIndex: 0,
        index: 0,
        name: 'Entrusted Account 1',
        accountId: '5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY',
      ),
      const Account(
        walletIndex: 0,
        index: 0,
        name: 'Zander Sky',
        accountId: '5FHneW46xGXgs5mUiveU4sbTyGBzmstUspZC92UhjJM694ty',
      ),
    ];
  }

  return [];
});
