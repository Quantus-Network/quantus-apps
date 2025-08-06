import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/models/combined_transactions_list.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/filtered_all_transactions_provider.dart';

/// Provides a list of transactions for the currently active account.
///
/// This provider handles the logic of watching the active account and fetching
/// the appropriate transaction list. It returns an [AsyncValue] that can be
/// in a loading, data, or error state.

final activeAccountTransactionsProvider =
    Provider<AsyncValue<CombinedTransactionsList>>((ref) {
      var globalAccountIds = <String>[];
      final activeAccountValue = ref.watch(activeAccountProvider);

      return activeAccountValue.when(
        data: (activeAccount) {
          if (activeAccount == null) {
            return AsyncValue.data(
              CombinedTransactionsList(
                pendingTransactions: [],
                reversibleTransfers: [],
                otherTransfers: [],
              ),
            );
          }

          // Create a stable list reference
          final active = activeAccount.accountId;
          if (globalAccountIds.length != 1 || globalAccountIds[0] != active) {
            globalAccountIds = [activeAccount.accountId];
          }

          // Watch the pagination state first
          // final paginationState = ref.watch(
          //   filteredPaginationControllerProviderFamily(globalAccountIds),
          // );

          // If we have no data and not fetching, trigger initial load
          // if (paginationState.items.isEmpty &&
          //     !paginationState.isFetching &&
          //     paginationState.error == null) {
          //   WidgetsBinding.instance.addPostFrameCallback((_) {
          //     ref
          //         .read(
          //           filteredPaginationControllerProviderFamily(
          //             globalAccountIds,
          //           ).notifier,
          //         )
          //         .loadingRefresh();
          //   });
          // }

          return ref.watch(
            filteredTransactionsProviderFamily(globalAccountIds),
          );
        },
        loading: () => const AsyncValue.loading(),
        error: (err, stack) => AsyncValue.error(err, stack),
      );
    });
