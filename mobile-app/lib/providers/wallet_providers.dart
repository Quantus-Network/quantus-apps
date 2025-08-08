import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/account_id_list_cache.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/pending_transactions_provider.dart';

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
  print('query balance for $accountId');
  return await substrateService.queryBalance(accountId);
});

// Raw blockchain balance (without pending transaction adjustments)
final balanceProviderRaw = Provider<AsyncValue<BigInt>>((ref) {
  final activeAccountAsyncValue = ref.watch(activeAccountProvider);

  return activeAccountAsyncValue.when(
    data: (activeAccount) {
      if (activeAccount == null) {
        return AsyncValue.data(BigInt.zero);
      }
      return ref.watch(balanceProviderFamily(activeAccount.accountId));
    },
    loading: () => const AsyncValue.loading(),
    error: (err, stack) => AsyncValue.error(err, stack),
  );
});

// Effective balance (blockchain balance minus pending outgoing transactions)
final balanceProvider = Provider<AsyncValue<BigInt>>((ref) {
  final balanceAsync = ref.watch(balanceProviderRaw);
  final pendingTransactions = ref.watch(pendingTransactionsProvider);
  final activeAccountAsync = ref.watch(activeAccountProvider);

  return balanceAsync.when(
    data: (blockchainBalance) {
      final activeAccount = activeAccountAsync.value;
      if (activeAccount == null) {
        return AsyncValue.data(BigInt.zero);
      }

      // Calculate pending outgoing amount for this account
      final pendingOutgoing = _calculatePendingOutgoing(
        pendingTransactions,
        activeAccount.accountId,
      );
      final effectiveBalance = blockchainBalance - pendingOutgoing;

      // Ensure balance doesn't go negative
      return AsyncValue.data(
        effectiveBalance >= BigInt.zero ? effectiveBalance : BigInt.zero,
      );
    },
    loading: () => const AsyncValue.loading(),
    error: (err, stack) => AsyncValue.error(err, stack),
  );
});

/// Calculates the total amount of pending outgoing transactions for a
/// specific account
BigInt _calculatePendingOutgoing(
  List<PendingTransactionEvent> pendingTransactions,
  String accountId,
) {
  BigInt totalOutgoing = BigInt.zero;

  for (final transaction in pendingTransactions) {
    // Only count outgoing transactions (where this account is the sender)
    if (transaction.from == accountId) {
      totalOutgoing += transaction.amount;

      // Add fee if available (for more accurate available balance)
      if (transaction.fee != null) {
        totalOutgoing += transaction.fee!;
      }
    }
  }

  return totalOutgoing;
}

final historyProviderFamily =
    FutureProvider.family<SortedTransactionsList, List<String>>((
      ref,
      accountIds,
    ) async {
      final chainHistoryService = ref.watch(chainHistoryServiceProvider);

      return await chainHistoryService.fetchAllTransactionTypes(
        accountIds: accountIds,
        printName: 'historyProviderFamily',
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
      return ref.watch(
        historyProviderFamily(
          AccountIdListCache.get([activeAccount.accountId]),
        ).future,
      );
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
      return ref.watch(
        historyProviderFamily(AccountIdListCache.get(accountIds)).future,
      );
    },
    loading: () => SortedTransactionsList.empty,
    error: (err, stack) => SortedTransactionsList.empty,
  );
});
