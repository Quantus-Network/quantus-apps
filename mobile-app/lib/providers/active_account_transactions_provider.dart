import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/models/combined_transactions_list.dart';
import 'package:resonance_network_wallet/providers/account_id_list_cache.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/filtered_all_transactions_provider.dart';

/// Provides a list of transactions for the currently active account.
///
/// This provider handles the logic of watching the active account and fetching
/// the appropriate transaction list. It returns an [AsyncValue] that can be
/// in a loading, data, or error state.
final activeAccountTransactionsProvider = Provider<AsyncValue<CombinedTransactionsList>>((ref) {
  final activeAccountValue = ref.watch(activeAccountProvider);

  return activeAccountValue.when(
    data: (activeAccount) {
      if (activeAccount == null) {
        return AsyncValue.data(
          CombinedTransactionsList(
            pendingCancellationIds: <String>{},
            pendingTransactions: [],
            reversibleTransfers: [],
            otherTransfers: [],
          ),
        );
      }
      return ref.watch(filteredTransactionsProviderFamily(AccountIdListCache.get([activeAccount.account.accountId])));
    },
    loading: () => const AsyncValue.loading(),
    error: (err, stack) => AsyncValue.error(err, stack),
  );
});
