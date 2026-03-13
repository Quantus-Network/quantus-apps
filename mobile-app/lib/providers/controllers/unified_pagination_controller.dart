import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/pagination_state.dart';
import 'package:resonance_network_wallet/providers/account_id_list_cache.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/providers/connectivity_provider.dart';

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

    final accountsState = await ref.read(accountsProvider.notifier).stream.firstWhere((state) => !state.isLoading);

    return accountsState.maybeWhen(
      data: (accounts) => AccountIdListCache.get(accounts.map((e) => e.accountId).toList()),
      orElse: () => throw Exception('Failed to load accounts'),
    );
  }

  List<String> _getAccountIds() {
    if (accountIds != null) return accountIds!;
    final accounts = ref.read(accountsProvider).value;
    final List<String> filteredAccountIds = accounts?.map((e) => e.accountId).toList() ?? [];
    return AccountIdListCache.get(filteredAccountIds);
  }

  Future<void> _fetchPage(List<String> targetAccountIds) async {
    try {
      state = state.copyWith(isFetching: true);
      final newTransactions = await ref
          .read(chainHistoryServiceProvider)
          .fetchAllTransactionTypes(
            accountIds: targetAccountIds,
            limit: _limit,
            otherOffset: state.otherOffset,
            scheduledOffset: state.scheduledOffset,
          );

      final newOtherTransfers = newTransactions.otherTransfers;
      final newScheduledReversibleTransfers = newTransactions.scheduledReversibleTransfers;

      state = state.copyWith(
        otherTransfers: [...state.otherTransfers, ...newOtherTransfers],
        scheduledReversibleTransfers: [...state.scheduledReversibleTransfers, ...newScheduledReversibleTransfers],
        otherOffset: newTransactions.nextOtherOffset,
        scheduledOffset: newTransactions.nextScheduledOffset,
        hasMore: newTransactions.hasMore,
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
      final newTransactions = await ref
          .read(chainHistoryServiceProvider)
          .fetchAllTransactionTypes(accountIds: targetAccountIds, limit: _limit);

      final newOtherTransfers = newTransactions.otherTransfers;
      final newScheduledReversibleTransfers = newTransactions.scheduledReversibleTransfers;

      state = state.copyWith(
        otherTransfers: newOtherTransfers,
        scheduledReversibleTransfers: newScheduledReversibleTransfers,
        otherOffset: newTransactions.nextOtherOffset,
        scheduledOffset: newTransactions.nextScheduledOffset,
        hasMore: newTransactions.hasMore,
        error: null,
        stackTrace: null,
      );
    } catch (e, st) {
      print('Silent refresh failed: $e, $st');
    }
  }

  /// Update a reversible transfer status to executed inline without full
  /// refresh.
  /// Moves the transfer from reversibleTransfers to the top of items list.
  void updateReversibleTransferToExecuted(String txId, ReversibleTransferStatus newStatus) {
    print('Updating reversible transfer to executed: $txId');

    // Find the reversible transfer with the matching hash
    final reversibleTransfer = state.scheduledReversibleTransfers
        .where((transfer) => transfer.txId == txId)
        .firstOrNull;

    if (reversibleTransfer == null) {
      print('Reversible transfer not found for txId: $txId');
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
    final updatedScheduledReversibleTransfers = state.scheduledReversibleTransfers
        .where((transfer) => transfer.txId != txId)
        .toList();

    // Add executed transfer to the top of items list
    final updatedOtherTransfers = [executedTransfer, ...state.otherTransfers];

    // Update state
    state = state.copyWith(
      otherTransfers: updatedOtherTransfers,
      scheduledReversibleTransfers: updatedScheduledReversibleTransfers,
    );

    print('Successfully moved transfer from reversible to executed');
  }

  /// Adds a newly found transaction to the top of the history list.
  /// This is used when a broadcast transaction is found in blockchain history.
  void addTransactionToHistory(TransactionEvent transaction) {
    print('Adding transaction to history: ${transaction.id}');

    // Check if transaction already exists to avoid duplicates
    final existsInOtherTransfers = state.otherTransfers.any((item) => item.id == transaction.id);
    final existsInScheduledReversibleTransfers = state.scheduledReversibleTransfers.any(
      (item) => item.id == transaction.id,
    );

    if (existsInOtherTransfers || existsInScheduledReversibleTransfers) {
      print('Transaction ${transaction.id} already exists in history');
      return;
    }

    if (transaction is ReversibleTransferEvent) {
      // Add to reversible transfers list
      final updatedScheduledReversibleTransfers = [transaction, ...state.scheduledReversibleTransfers];
      state = state.copyWith(scheduledReversibleTransfers: updatedScheduledReversibleTransfers);
    } else {
      // Add to regular transactions list at the top
      final updatedOtherTransfers = [transaction, ...state.otherTransfers];
      state = state.copyWith(otherTransfers: updatedOtherTransfers);
    }

    print('Successfully added transaction ${transaction.id} to history');
  }
}
