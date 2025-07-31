import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';

final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService();
});

final chainHistoryServiceProvider = Provider<ChainHistoryService>((ref) {
  return ChainHistoryService();
});

final substrateServiceProvider = Provider<SubstrateService>((ref) {
  return SubstrateService();
});

final balanceProvider = FutureProvider<BigInt>((ref) async {
  final substrateService = ref.watch(substrateServiceProvider);
  final activeAccountAsyncValue = ref.watch(activeAccountProvider);

  return activeAccountAsyncValue.when(
    data: (activeAccount) async {
      if (activeAccount == null) {
        return BigInt.zero;
      }
      return await substrateService.queryBalance(activeAccount.accountId);
    },
    loading: () => BigInt.zero, // Or a suitable loading state
    error: (err, stack) => BigInt.zero, // Or handle the error appropriately
  );
});

final historyProvider = FutureProvider<SortedTransactionsList>((ref) async {
  final chainHistoryService = ref.watch(chainHistoryServiceProvider);
  final accountsValue = ref.watch(accountsProvider);

  return accountsValue.when(
    data: (accounts) async {
      if (accounts.isEmpty) {
        return SortedTransactionsList.empty;
      }
      return await chainHistoryService.fetchAllTransactionTypes(
        accountIds: accounts.map((e) => e.accountId).toList(),
      );
    },
    loading: () => SortedTransactionsList.empty,
    error: (err, stack) => SortedTransactionsList.empty,
  );
});
