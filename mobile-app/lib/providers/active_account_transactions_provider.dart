import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/combined_transactions_list.dart';
import 'package:resonance_network_wallet/models/filtered_transactions_params.dart';
import 'package:resonance_network_wallet/models/pagination_state.dart';
import 'package:resonance_network_wallet/providers/account_id_list_cache.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/controllers/unified_pagination_controller.dart';
import 'package:resonance_network_wallet/providers/filtered_all_transactions_provider.dart';

FilteredTransactionsParams? activeAccountFilteredParams(DisplayAccount? activeAccount, TransactionFilter filter) {
  if (activeAccount == null) return null;
  return FilteredTransactionsParams(
    accountIds: AccountIdListCache.get([activeAccount.account.accountId]),
    filter: filter,
  );
}

UnifiedPaginationController? readActiveAccountPaginationNotifier(WidgetRef ref, TransactionFilter filter) {
  final params = activeAccountFilteredParams(ref.read(activeAccountProvider).value, filter);
  if (params == null) return null;
  return ref.read(filteredPaginationControllerProviderFamily(params).notifier);
}

/// Pagination state for the active account and [TransactionFilter].
final activeAccountPaginationProvider = Provider.family<PaginationState?, TransactionFilter>((ref, filter) {
  final activeAccountValue = ref.watch(activeAccountProvider);

  return activeAccountValue.when(
    data: (activeAccount) {
      final params = activeAccountFilteredParams(activeAccount, filter);
      if (params == null) return null;
      return ref.watch(filteredPaginationControllerProviderFamily(params));
    },
    loading: () => null,
    error: (_, _) => null,
  );
});

/// Provides a filtered list of transactions for the currently active account.
///
/// Parameterised by [TransactionFilter] so callers can independently watch
/// the send-only, receive-only, or combined history.
final activeAccountTransactionsProvider = Provider.family<AsyncValue<CombinedTransactionsList>, TransactionFilter>((
  ref,
  filter,
) {
  final activeAccountValue = ref.watch(activeAccountProvider);

  return activeAccountValue.when(
    data: (activeAccount) {
      if (activeAccount == null) {
        return AsyncValue.data(CombinedTransactionsList.empty);
      }
      final params = activeAccountFilteredParams(activeAccount, filter)!;
      return ref.watch(filteredTransactionsProviderFamily(params));
    },
    loading: () => const AsyncValue.loading(),
    error: (err, stack) => AsyncValue.error(err, stack),
  );
});
