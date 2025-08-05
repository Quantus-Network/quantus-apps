import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';

class PaginatedTransactionsNotifier
    extends StateNotifier<AsyncValue<SortedTransactionsList>> {
  PaginatedTransactionsNotifier(this.ref) : super(const AsyncValue.loading()) {
    _init();
  }

  final Ref ref;
  final List<TransactionEvent> _items = [];
  bool hasMore = true;
  int _offset = 0;
  static const int _limit = 20;
  bool _isFetchingMore = false;

  Future<void> _init() async {
    try {
      // Wait for the accountsProvider to finish its initial loading.
      final accountsState = await ref
          .read(accountsProvider.notifier)
          .stream
          .firstWhere((state) => !state.isLoading);

      // Once loaded, handle the data or error state.
      await accountsState.when(
        data: (accounts) async {
          if (accounts.isEmpty) {
            state = const AsyncValue.data(SortedTransactionsList.empty);
            return;
          }
          await _fetchPage(accounts.map((e) => e.accountId).toList());
        },
        error: (e, st) {
          state = AsyncValue.error(e, st);
        },
        // This case is not reachable due to the `firstWhere` condition.
        loading: () {},
      );
    } catch (e, st) {
      // Catch any potential errors from the stream or other async operations.
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> _fetchPage(List<String> accountIds) async {
    try {
      final newTransactions = await ref
          .read(chainHistoryServiceProvider)
          .fetchAllTransactionTypes(
            accountIds: accountIds,
            limit: _limit,
            offset: _offset,
            printName: 'historyTx - fetchPage',
          );

      final newItems = newTransactions.otherTransfers;
      _items.addAll(newItems);
      hasMore = newItems.length == _limit;
      _offset += newItems.length;

      final reversible = _offset == newItems.length
          ? newTransactions.reversibleTransfers
          : state.value?.reversibleTransfers ?? [];

      state = AsyncValue.data(
        SortedTransactionsList(
          reversibleTransfers: reversible,
          otherTransfers: List.from(_items),
        ),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> fetchMore() async {
    // Prevent multiple simultaneous fetches and fetching if there are no more
    // items.
    if (_isFetchingMore || !hasMore) return;

    _isFetchingMore = true;

    try {
      // When fetching more, we can safely assume the accounts are already
      // loaded.
      final accounts = ref.read(accountsProvider).value;
      if (accounts == null || accounts.isEmpty) {
        return;
      }

      await _fetchPage(accounts.map((e) => e.accountId).toList());
    } catch (e, st) {
      // In case of an error, you might want to handle it, e.g., by logging
      // or showing a snackbar, but we avoid setting the whole state to error
      // to keep the existing list visible.
      print('Error fetching more transactions: $e $st');
    } finally {
      _isFetchingMore = false;
    }
  }
}

final historyTransactionsProvider =
    StateNotifierProvider<
      PaginatedTransactionsNotifier,
      AsyncValue<SortedTransactionsList>
    >((ref) {
      return PaginatedTransactionsNotifier(ref);
    });
