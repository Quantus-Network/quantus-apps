import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/all_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/pending_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';

/// Provider for filtered transactions that can handle
/// account-specific filtering
/// with pagination support similar to allTransactionsProvider
class FilteredPaginationController extends StateNotifier<PaginationState> {
  FilteredPaginationController(this.ref, this.accountIds)
    : super(PaginationState.initial());

  final Ref ref;
  final List<String>
  accountIds; // List of account IDs to fetch transactions for
  static const int _limit = 20;

  Future<void> _fetchPage(List<String> targetAccountIds) async {
    try {
      print(
        'FilteredPaginationController: Fetching page for accounts:'
        ' $targetAccountIds, offset: ${state.offset}',
      );
      state = state.copyWith(isFetching: true);
      final newTransactions = await ref
          .read(chainHistoryServiceProvider)
          .fetchAllTransactionTypes(
            accountIds: targetAccountIds,
            limit: _limit,
            offset: state.offset,
          );

      final newItems = newTransactions.otherTransfers;
      print(
        'FilteredPaginationController: Fetched ${newItems.length} '
        'transactions, ${newTransactions.reversibleTransfers.length} '
        'reversible',
      );
      state = state.copyWith(
        items: [...state.items, ...newItems],
        reversibleTransfers: state.offset == 0
            ? newTransactions.reversibleTransfers
            : state.reversibleTransfers,
        offset: state.offset + newItems.length,
        hasMore: newItems.length == _limit,
        isFetching: false,
      );
    } catch (e, st) {
      state = state.copyWith(error: e, stackTrace: st, isFetching: false);
    }
  }

  Future<void> fetchMore() async {
    if (state.isFetching || !state.hasMore) return;

    await _fetchPage(accountIds);
  }

  /// Refresh data with loading indicators
  Future<void> loadingRefresh() async {
    // Reset to initial state to show loading
    state = PaginationState.initial();
    if (accountIds.isEmpty) {
      state = state.copyWith(hasMore: false, isFetching: false);
      return;
    }
    await _fetchPage(accountIds);
  }

  /// Update a reversible transfer status to executed inline without full
  /// refresh
  void updateReversibleTransferToExecuted(
    String extrinsicHash,
    ReversibleTransferStatus newStatus,
  ) {
    final reversibleTransfer = state.reversibleTransfers
        .where((transfer) => transfer.extrinsicHash == extrinsicHash)
        .firstOrNull;

    if (reversibleTransfer == null) {
      return;
    }

    final executedTransfer = ReversibleTransferEvent(
      id: reversibleTransfer.id,
      amount: reversibleTransfer.amount,
      timestamp: reversibleTransfer.timestamp,
      from: reversibleTransfer.from,
      to: reversibleTransfer.to,
      txId: reversibleTransfer.txId,
      scheduledAt: reversibleTransfer.scheduledAt,
      status: newStatus,
      blockNumber: reversibleTransfer.blockNumber,
      blockHash: reversibleTransfer.blockHash,
      extrinsicHash: reversibleTransfer.extrinsicHash,
    );

    final updatedReversibleTransfers = state.reversibleTransfers
        .where((transfer) => transfer.extrinsicHash != extrinsicHash)
        .toList();

    final updatedItems = [executedTransfer, ...state.items];

    state = state.copyWith(
      items: updatedItems,
      reversibleTransfers: updatedReversibleTransfers,
    );
  }
}

/// Family provider for filtered pagination controllers
final filteredPaginationControllerProviderFamily =
    StateNotifierProvider.family<
      FilteredPaginationController,
      PaginationState,
      List<String>
    >((ref, accountIds) => FilteredPaginationController(ref, accountIds));

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
