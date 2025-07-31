import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/pending_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';

// Assuming CombinedTransactionsList is defined as before
class CombinedTransactionsList {
  final List<PendingTransactionEvent> pendingTransactions;
  final List<ReversibleTransferEvent> reversibleTransfers;
  final List<TransactionEvent> otherTransfers;

  CombinedTransactionsList({
    required this.pendingTransactions,
    required this.reversibleTransfers,
    required this.otherTransfers,
  });

  CombinedTransactionsList copyWith({
    List<PendingTransactionEvent>? pendingTransactions,
    List<ReversibleTransferEvent>? reversibleTransfers,
    List<TransactionEvent>? otherTransfers,
  }) {
    return CombinedTransactionsList(
      pendingTransactions: pendingTransactions ?? this.pendingTransactions,
      reversibleTransfers: reversibleTransfers ?? this.reversibleTransfers,
      otherTransfers: otherTransfers ?? this.otherTransfers,
    );
  }

  static CombinedTransactionsList get empty => CombinedTransactionsList(
    pendingTransactions: [],
    reversibleTransfers: [],
    otherTransfers: [],
  );
}

// Notifier for pagination control (fetchMore, offset, etc.)
class PaginationController extends StateNotifier<PaginationState> {
  PaginationController(this.ref) : super(PaginationState.initial()) {
    _init();
  }

  final Ref ref;
  static const int _limit = 20;

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

  Future<void> _fetchPage(List<String> accountIds) async {
    try {
      state = state.copyWith(isFetching: true);
      final newTransactions = await ref
          .read(chainHistoryServiceProvider)
          .fetchAllTransactionTypes(
            accountIds: accountIds,
            limit: _limit,
            offset: state.offset,
          );

      final newItems = newTransactions.otherTransfers;
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
    final accounts = ref.read(accountsProvider).value;
    if (accounts == null || accounts.isEmpty) return;
    await _fetchPage(accounts.map((e) => e.accountId).toList());
  }
}

// State for pagination
class PaginationState {
  final List<TransactionEvent> items;
  final List<ReversibleTransferEvent> reversibleTransfers;
  final int offset;
  final bool hasMore;
  final bool isFetching;
  final Object? error;
  final StackTrace? stackTrace;

  PaginationState({
    required this.items,
    required this.reversibleTransfers,
    required this.offset,
    required this.hasMore,
    required this.isFetching,
    this.error,
    this.stackTrace,
  });

  factory PaginationState.initial() => PaginationState(
    items: [],
    reversibleTransfers: [],
    offset: 0,
    hasMore: true,
    isFetching: false,
  );

  PaginationState copyWith({
    List<TransactionEvent>? items,
    List<ReversibleTransferEvent>? reversibleTransfers,
    int? offset,
    bool? hasMore,
    bool? isFetching,
    Object? error,
    StackTrace? stackTrace,
  }) {
    return PaginationState(
      items: items ?? this.items,
      reversibleTransfers: reversibleTransfers ?? this.reversibleTransfers,
      offset: offset ?? this.offset,
      hasMore: hasMore ?? this.hasMore,
      isFetching: isFetching ?? this.isFetching,
      error: error ?? this.error,
      stackTrace: stackTrace ?? this.stackTrace,
    );
  }
}

final paginationControllerProvider =
    StateNotifierProvider<PaginationController, PaginationState>(
      (ref) => PaginationController(ref),
    );

// Combined provider that reacts to both pending and paginated data
final combinedTransactionsProvider =
    Provider<AsyncValue<CombinedTransactionsList>>((ref) {
      final pending = ref.watch(pendingTransactionsProvider);
      final pagination = ref.watch(paginationControllerProvider);

      if (pagination.error != null) {
        return AsyncValue.error(pagination.error!, pagination.stackTrace!);
      }
      if (pagination.isFetching && pagination.items.isEmpty) {
        return const AsyncValue.loading();
      }

      return AsyncValue.data(
        CombinedTransactionsList(
          pendingTransactions: pending,
          reversibleTransfers: pagination.reversibleTransfers,
          otherTransfers: pagination.items,
        ),
      );
    });
