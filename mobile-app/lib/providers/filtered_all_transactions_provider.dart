import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/models/combined_transactions_list.dart';
import 'package:resonance_network_wallet/models/pagination_state.dart';
import 'package:resonance_network_wallet/providers/controllers/unified_pagination_controller.dart';
import 'package:resonance_network_wallet/providers/pending_transactions_provider.dart';

/// Family provider for filtered pagination controllers
final filteredPaginationControllerProviderFamily =
    StateNotifierProvider.family<
      UnifiedPaginationController,
      PaginationState,
      List<String>
    >(
      (ref, accountIds) =>
          UnifiedPaginationController(ref, accountIds: accountIds),
    );

/// Combined provider for filtered transactions (similar to
/// allTransactionsProvider)
final filteredTransactionsProviderFamily =
    Provider.family<AsyncValue<CombinedTransactionsList>, List<String>>((
      ref,
      accountIds,
    ) {
      final pending = ref.watch(pendingTransactionsProvider);
      final pagination = ref.watch(
        filteredPaginationControllerProviderFamily(accountIds),
      );

      if (pagination.error != null) {
        print('FilteredTransactionsProvider: Error: ${pagination.error}');
        return AsyncValue.error(pagination.error!, pagination.stackTrace!);
      }
      if (pagination.isFetching && pagination.items.isEmpty) {
        return const AsyncValue.loading();
      }

      // Filter pending transactions based on account selection
      final filteredPending = pending
          .where(
            (tx) => accountIds.contains(tx.from) || accountIds.contains(tx.to),
          )
          .toList();

      return AsyncValue.data(
        CombinedTransactionsList(
          pendingTransactions: filteredPending,
          reversibleTransfers: pagination.reversibleTransfers,
          otherTransfers: pagination.items,
        ),
      );
    });
