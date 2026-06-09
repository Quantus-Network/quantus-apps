import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/pagination_state.dart';
import 'package:resonance_network_wallet/providers/account_id_list_cache.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/providers/connectivity_provider.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';

/// Unified pagination controller that handles both all-accounts and
/// filtered-accounts scenarios
class UnifiedPaginationController extends StateNotifier<PaginationState> {
  UnifiedPaginationController(
    this.ref, {
    this.accountIds,
    int pageLimit = 20,
    TransactionFilter filter = TransactionFilter.all,
  }) : _limit = pageLimit,
       _filter = filter,
       super(PaginationState.initial()) {
    if (accountIds == null) {
      _listenToAccounts();
    }
    _init();
  }

  final Ref ref;
  final List<String>? accountIds; // If null, load all accounts from provider
  final int _limit;
  final TransactionFilter _filter;

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
      quantusDebugPrint('Initialization failed: $e\n$st');
      state = state.copyWith(error: e, stackTrace: st, isLoading: false);
      return;
    }

    if (ids.isEmpty) {
      state = state.copyWith(hasMore: false, isFetching: false, isLoading: false);
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
      state = state.copyWith(isFetching: true, isLoading: true, clearError: true);
      final newTransactions = await ref
          .read(chainHistoryServiceProvider)
          .fetchAllTransactionTypes(
            accountIds: targetAccountIds,
            limit: _limit,
            otherOffset: state.otherOffset,
            scheduledOffset: state.scheduledOffset,
            filter: _filter,
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
        isLoading: false,
        clearError: true,
      );
    } catch (e, st) {
      quantusDebugPrint('Fetch page failed: $e\n$st');
      state = state.copyWith(error: e, stackTrace: st, isFetching: false, isLoading: false);
    }
  }

  Future<void> fetchMore() async {
    quantusDebugPrint('UnifiedPaginationController: Fetch more');

    if (state.isFetching || !state.hasMore) return;

    final targetAccountIds = _getAccountIds();
    if (targetAccountIds.isEmpty) return;

    await _fetchPage(targetAccountIds);
  }

  /// Refresh data silently without showing loading indicators.
  /// Used for automatic polling to update data in background.
  Future<void> silentRefresh() async {
    quantusDebugPrint('UnifiedPaginationController: Silent refresh called');
    if (state.isFetching) return;

    final targetAccountIds = _getAccountIds();
    if (targetAccountIds.isEmpty) return;

    state = state.copyWith(isFetching: true);

    try {
      await _silentFetchFirstPage(targetAccountIds);
    } finally {
      state = state.copyWith(isFetching: false);
    }
  }

  /// Refresh data with loading indicators.
  /// Used for user-initiated refreshes like pull-to-refresh.
  Future<void> loadingRefresh() async {
    quantusDebugPrint('UnifiedPaginationController: Loading Refresh');

    // Check connectivity before refreshing
    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) {
      quantusDebugPrint('Skipping refresh - offline');
      return;
    }

    final targetAccountIds = _getAccountIds();
    if (targetAccountIds.isEmpty) {
      state = PaginationState.initial().copyWith(hasMore: false, isLoading: false);
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
          .fetchAllTransactionTypes(accountIds: targetAccountIds, limit: _limit, filter: _filter);

      final newOtherTransfers = newTransactions.otherTransfers;
      final newScheduledReversibleTransfers = newTransactions.scheduledReversibleTransfers;

      state = state.copyWith(
        otherTransfers: newOtherTransfers,
        scheduledReversibleTransfers: newScheduledReversibleTransfers,
        otherOffset: newTransactions.nextOtherOffset,
        scheduledOffset: newTransactions.nextScheduledOffset,
        hasMore: newTransactions.hasMore,
        clearError: true,
      );
    } catch (e, st) {
      quantusDebugPrint('Silent refresh failed: $e, $st');
    }
  }

  /// Update a reversible transfer status to executed inline without full
  /// refresh.
  /// Moves the transfer from reversibleTransfers to the top of items list.
  void updateReversibleTransferToExecuted(String txId, ReversibleTransferStatus newStatus) {
    quantusDebugPrint('Updating reversible transfer to executed: $txId');

    // Find the reversible transfer with the matching hash
    final reversibleTransfer = state.scheduledReversibleTransfers
        .where((transfer) => transfer.txId == txId)
        .firstOrNull;

    if (reversibleTransfer == null) {
      quantusDebugPrint('Reversible transfer not found for txId: $txId');
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

    quantusDebugPrint('Successfully moved transfer from reversible to executed');
  }

  /// Adds a newly found transaction to the top of the history list.
  /// This is used when a broadcast transaction is found in blockchain history.
  void addTransactionToHistory(TransactionEvent transaction) {
    quantusDebugPrint('Adding transaction to history: ${transaction.id}');

    // Check if transaction already exists to avoid duplicates
    final multisigAddress = transaction is MultisigCreatedEvent ? transaction.multisigAddress : null;
    final existsInOtherTransfers = state.otherTransfers.any(
      (item) =>
          item.id == transaction.id ||
          (multisigAddress != null && item is MultisigCreatedEvent && item.multisigAddress == multisigAddress),
    );
    final existsInScheduledReversibleTransfers = state.scheduledReversibleTransfers.any(
      (item) => item.id == transaction.id,
    );

    if (existsInOtherTransfers || existsInScheduledReversibleTransfers) {
      quantusDebugPrint('Transaction ${transaction.id} already exists in history');
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

    quantusDebugPrint('Successfully added transaction ${transaction.id} to history');
  }
}
