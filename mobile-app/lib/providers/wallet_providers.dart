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

final balanceProviderFamily = FutureProvider.family<BigInt, String>((
  ref,
  accountId,
) async {
  final substrateService = ref.watch(substrateServiceProvider);
  return await substrateService.queryBalance(accountId);
});

final balanceProvider = FutureProvider<BigInt>((ref) async {
  final activeAccountAsyncValue = ref.watch(activeAccountProvider);

  return activeAccountAsyncValue.when(
    data: (activeAccount) {
      if (activeAccount == null) {
        return BigInt.zero;
      }
      return ref.watch(balanceProviderFamily(activeAccount.accountId).future);
    },
    loading: () => BigInt.zero, // Or a suitable loading state
    error: (err, stack) => BigInt.zero, // Or handle the error appropriately
  );
});

final historyProviderFamily =
    FutureProvider.family<SortedTransactionsList, List<String>>((
      ref,
      accountIds,
    ) async {
      final chainHistoryService = ref.watch(chainHistoryServiceProvider);
      return await chainHistoryService.fetchAllTransactionTypes(
        accountIds: accountIds,
      );
    });

final activeAccountHistoryProvider = FutureProvider<SortedTransactionsList>((
  ref,
) async {
  final activeAccountAsyncValue = ref.watch(activeAccountProvider);

  return activeAccountAsyncValue.when(
    data: (activeAccount) {
      if (activeAccount == null) {
        return SortedTransactionsList.empty;
      }
      return ref.watch(historyProviderFamily([activeAccount.accountId]).future);
    },
    loading: () => SortedTransactionsList.empty,
    error: (err, stack) => SortedTransactionsList.empty,
  );
});

final allAccountsHistoryProvider = FutureProvider<SortedTransactionsList>((
  ref,
) async {
  final accountsValue = ref.watch(accountsProvider);

  return accountsValue.when(
    data: (accounts) {
      if (accounts.isEmpty) {
        return SortedTransactionsList.empty;
      }
      final accountIds = accounts.map((e) => e.accountId).toList();
      return ref.watch(historyProviderFamily(accountIds).future);
    },
    loading: () => SortedTransactionsList.empty,
    error: (err, stack) => SortedTransactionsList.empty,
  );
});
