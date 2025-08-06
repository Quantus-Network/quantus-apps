import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/pagination_state.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';

/// Unified pagination controller that handles both all-accounts and
/// filtered-accounts scenarios
class UnifiedPaginationController extends StateNotifier<PaginationState> {
  UnifiedPaginationController(this.ref, {this.accountIds})
    : super(PaginationState.initial()) {
    if (accountIds == null) {
      // Auto-initialize for all accounts scenario
      _init();
    } else {
      // Auto-initialize for filtered accounts scenario
      _initFiltered();
    }
  }

  /// Initialize for filtered accounts scenario
  Future<void> _initFiltered() async {
    if (accountIds == null || accountIds!.isEmpty) {
      state = state.copyWith(hasMore: false, isFetching: false);
      return;
    }
    await _fetchPage(accountIds!);
  }

  final Ref ref;
  final List<String>? accountIds; // If null, load all accounts from provider
  static const int _limit = 20;

  /// Initialize by loading accounts from provider (when accountIds is null)
  Future<void> _init() async {
    try {
      final accountsState = await ref
          .read(accountsProvider.notifier)
          .stream
          .firstWhere((state) => !state.isLoading);

      accountsState.when(
        data: (accounts) async {
          if (accounts.isEmpty) {
            state = state.copyWith(hasMore: false);
            return;
          }
          await _fetchPage(accounts.map((e) => e.accountId).toList());
        },
        error: (e, st) => state = state.copyWith(error: e, stackTrace: st),
        loading: () {},
      );
    } catch (e, st) {
      state = state.copyWith(error: e, stackTrace: st);
    }
  }

  /// Get the account IDs to use for fetching
  List<String> _getAccountIds() {
    if (accountIds != null) return accountIds!;

    final accounts = ref.read(accountsProvider).value;
    return accounts?.map((e) => e.accountId).toList() ?? [];
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
      );
    } catch (e, st) {
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
}
