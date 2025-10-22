import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/pagination_state.dart';
import 'package:resonance_network_wallet/providers/account_id_list_cache.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/services/connectivity_service.dart';

/// Unified pagination controller that handles both all-accounts and
/// filtered-accounts scenarios
class UnifiedPaginationController extends StateNotifier<PaginationState> {
  UnifiedPaginationController(this.ref, {this.accountIds, int pageLimit = 20})
    : _limit = pageLimit,
      super(PaginationState.initial()) {
    if (accountIds == null) {
      _listenToAccounts();
    }
    _init();
  }

  final Ref ref;
  final List<String>? accountIds; // If null, load all accounts from provider
  final int _limit;

  void _listenToAccounts() {
    ref.listen(accountsProvider, (previous, next) {
      if (next != previous && !next.isLoading) {
        loadingRefresh();
      }
    });
  }

  Future<void> _init() async {
    List<String> ids;
    try {
      ids = await _getAccountIdsAsync();
    } catch (e, st) {
      print('Initialization failed: $e\n$st');
      state = state.copyWith(error: e, stackTrace: st);
      return;
    }

    if (ids.isEmpty) {
      state = state.copyWith(hasMore: false, isFetching: false);
      return;
    }

    await _fetchPage(ids);
  }

  Future<List<String>> _getAccountIdsAsync() async {
    if (accountIds != null) {
      return accountIds!;
    }

    final accountsState = await ref
        .read(accountsProvider.notifier)
        .stream
        .firstWhere((state) => !state.isLoading);

    return accountsState.maybeWhen(
      data: (accounts) =>
          AccountIdListCache.get(accounts.map((e) => e.accountId).toList()),
      orElse: () => throw Exception('Failed to load accounts'),
    );
  }

  List<String> _getAccountIds() {
    if (accountIds != null) return accountIds!;
    final accounts = ref.read(accountsProvider).value;
    final List<String> filteredAccountIds =
        accounts?.map((e) => e.accountId).toList() ?? [];
    return AccountIdListCache.get(filteredAccountIds);
  }

  Future<void> _fetchPage(List<String> targetAccountIds) async {
    try {
      print(
        'UnifiedPaginationController: Fetching page for accounts:'
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
        'UnifiedPaginationController: Fetched ${newItems.length} '
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
        error: null,
        stackTrace: null,
      );
    } catch (e, st) {
      print('Fetch page failed: $e\n$st');
      state = state.copyWith(error: e, stackTrace: st, isFetching: false);
    }
  }

  Future<void> fetchMore() async {
    print('UnifiedPaginationController: Fetch more');

    if (state.isFetching || !state.hasMore) return;

    final targetAccountIds = _getAccountIds();
    if (targetAccountIds.isEmpty) return;

    await _fetchPage(targetAccountIds);
  }

  /// Refresh data silently without showing loading indicators.
  /// Used for automatic polling to update data in background.
  Future<void> silentRefresh() async {
    print('UnifiedPaginationController: Silent refresh called');
    if (state.isFetching) return;

    final targetAccountIds = _getAccountIds();
    if (targetAccountIds.isEmpty) return;

    await _silentFetchFirstPage(targetAccountIds);
  }

  /// Refresh data with loading indicators.
  /// Used for user-initiated refreshes like pull-to-refresh.
  Future<void> loadingRefresh() async {
    print('UnifiedPaginationController: Loading Refresh');

    // Check connectivity before refreshing
    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) {
      print('Skipping refresh - offline');
      return;
    }

    final targetAccountIds = _getAccountIds();
    if (targetAccountIds.isEmpty) {
      state = PaginationState.initial().copyWith(hasMore: false);
      return;
    }

    // Reset to initial state to show loading
    state = PaginationState.initial();
    await _fetchPage(targetAccountIds);
  }

  Future<void> _silentFetchFirstPage(List<String> targetAccountIds) async {
    try {
      // Fetch without setting isFetching to avoid loading indicators
      final newTransactions = await ref
          .read(chainHistoryServiceProvider)
          .fetchAllTransactionTypes(
            accountIds: targetAccountIds,
            limit: _limit,
            offset: 0,
          );

      final newItems = newTransactions.otherTransfers;

      // Replace existing items with fresh data
      state = state.copyWith(
        items: newItems,
        reversibleTransfers: newTransactions.reversibleTransfers,
        offset: newItems.length,
        hasMore: newItems.length == _limit,
        error: null,
        stackTrace: null,
      );
    } catch (e, st) {
      // Silently handle errors - don't update UI state for automatic polling
      // failures
      print('Silent refresh failed: $e, $st');
    }
  }

  /// Update a reversible transfer status to executed inline without full
  /// refresh.
  /// Moves the transfer from reversibleTransfers to the top of items list.
  void updateReversibleTransferToExecuted(
    String extrinsicHash,
    ReversibleTransferStatus newStatus,
  ) {
    print('Updating reversible transfer to executed: $extrinsicHash');

    // Find the reversible transfer with the matching hash
    final reversibleTransfer = state.reversibleTransfers
        .where((transfer) => transfer.extrinsicHash == extrinsicHash)
        .firstOrNull;

    if (reversibleTransfer == null) {
      print('Reversible transfer not found for hash: $extrinsicHash');
      return;
    }

    // Create executed version by copying with EXECUTED status
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

    // Remove from reversible transfers
    final updatedReversibleTransfers = state.reversibleTransfers
        .where((transfer) => transfer.extrinsicHash != extrinsicHash)
        .toList();

    // Add executed transfer to the top of items list
    final updatedItems = [executedTransfer, ...state.items];

    // Update state
    state = state.copyWith(
      items: updatedItems,
      reversibleTransfers: updatedReversibleTransfers,
    );

    print('Successfully moved transfer from reversible to executed');
  }

  /// Adds a newly found transaction to the top of the history list.
  /// This is used when a broadcast transaction is found in blockchain history.
  void addTransactionToHistory(TransactionEvent transaction) {
    print('Adding transaction to history: ${transaction.id}');

    // Check if transaction already exists to avoid duplicates
    final existsInItems = state.items.any((item) => item.id == transaction.id);
    final existsInReversible = state.reversibleTransfers.any(
      (item) => item.id == transaction.id,
    );

    if (existsInItems || existsInReversible) {
      print('Transaction ${transaction.id} already exists in history');
      return;
    }

    if (transaction is ReversibleTransferEvent) {
      // Add to reversible transfers list
      final updatedReversibleTransfers = [
        transaction,
        ...state.reversibleTransfers,
      ];
      state = state.copyWith(reversibleTransfers: updatedReversibleTransfers);
    } else {
      // Add to regular transactions list at the top
      final updatedItems = [transaction, ...state.items];
      state = state.copyWith(items: updatedItems);
    }

    print('Successfully added transaction ${transaction.id} to history');
  }
}
